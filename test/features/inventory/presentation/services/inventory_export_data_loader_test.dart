import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_page.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/record_opening_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_data_loader.dart';

class _CustomTestInventoryRepo implements InventoryRepository {
  _CustomTestInventoryRepo(this._pageHandler);

  final Future<InventoryPage> Function(InventoryQuery query) _pageHandler;

  @override
  Future<InventoryPage> getItems(InventoryQuery query) => _pageHandler(query);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockInventoryRepository repository;
  late InventoryExportDataLoader loader;

  setUp(() {
    repository = MockInventoryRepository();
    loader = InventoryExportDataLoader(repository);
  });

  InventoryItemSummary createItem({
    required String id,
    required String name,
    required String sku,
    double quantityOnHand = 10.0,
  }) {
    return InventoryItemSummary(
      item: InventoryItem(id: id, name: name, sku: sku),
      quantityOnHand: quantityOnHand,
    );
  }

  group('InventoryExportDataLoader Unit & Integration Tests', () {
    test('loads all seeded inventory items (25 default seed items)', () async {
      final items = await loader.loadAllItems();
      expect(items.length, equals(25));
    });

    test('retrieves all items across multiple pages and applies global deterministic sorting', () async {
      final initialCount = (await loader.loadAllItems()).length;

      await repository.createItem(
        const CreateInventoryItemInput(name: '000 AAA First Item', sku: 'SKU-AAA'),
      );
      await repository.createItem(
        const CreateInventoryItemInput(name: 'ZZZ Last Item', sku: 'SKU-ZZZ'),
      );

      final items = await loader.loadAllItems(batchSize: 10);
      expect(items.length, equals(initialCount + 2));

      expect(items.first.item.name, equals('000 AAA First Item'));
      expect(items.last.item.name, equals('ZZZ Last Item'));
    });

    test('sorts by Name ascending, then SKU ascending as tie-breaker', () async {
      final initialCount = (await loader.loadAllItems()).length;

      await repository.createItem(
        const CreateInventoryItemInput(name: '000 Alpha', sku: 'SKU-Z'),
      );
      await repository.createItem(
        const CreateInventoryItemInput(name: '000 Alpha', sku: 'SKU-A'),
      );

      final items = await loader.loadAllItems();
      expect(items.length, equals(initialCount + 2));
      expect(items[0].item.name, equals('000 Alpha'));
      expect(items[0].item.sku, equals('SKU-A'));
      expect(items[1].item.name, equals('000 Alpha'));
      expect(items[1].item.sku, equals('SKU-Z'));
    });

    test('preserves derived quantities from stock movements', () async {
      final item = await repository.createItem(
        const CreateInventoryItemInput(name: '000 Custom Mouse', sku: 'MS-01'),
      );
      await repository.recordOpeningStock(
        RecordOpeningStockInput(
          itemId: item.item.id,
          quantity: 50.0,
          performedByUserId: 'usr_admin',
        ),
      );
      await repository.adjustStock(
        AdjustInventoryStockInput(
          itemId: item.item.id,
          quantityDelta: 25.5,
          reason: 'Correction',
          performedByUserId: 'usr_admin',
        ),
      );

      final items = await loader.loadAllItems();
      final customItem = items.firstWhere((i) => i.item.id == item.item.id);
      expect(customItem.quantityOnHand, equals(75.5));
    });

    test('excludes items in pending deletion state', () async {
      final initialItems = await loader.loadAllItems();
      final initialCount = initialItems.length;
      final targetItem = initialItems.first;

      await repository.requestItemDeletion(
        itemId: targetItem.item.id,
        performedByUserId: 'usr_admin',
      );

      final items = await loader.loadAllItems();
      expect(items.length, equals(initialCount - 1));
      expect(items.any((i) => i.item.id == targetItem.item.id), isFalse);
    });

    test('re-includes items restored via undo deletion', () async {
      final initialItems = await loader.loadAllItems();
      final initialCount = initialItems.length;
      final targetItem = initialItems.first;

      await repository.requestItemDeletion(
        itemId: targetItem.item.id,
        performedByUserId: 'usr_admin',
      );

      var items = await loader.loadAllItems();
      expect(items.length, equals(initialCount - 1));

      await repository.undoItemDeletion(
        itemId: targetItem.item.id,
        performedByUserId: 'usr_admin',
      );

      items = await loader.loadAllItems();
      expect(items.length, equals(initialCount));
      expect(items.any((i) => i.item.id == targetItem.item.id), isTrue);
    });

    test('rejects batchSize <= 0 with InventoryExportDataLoaderException', () async {
      expect(
        () => loader.loadAllItems(batchSize: 0),
        throwsA(isA<InventoryExportDataLoaderException>()),
      );
      expect(
        () => loader.loadAllItems(batchSize: -5),
        throwsA(isA<InventoryExportDataLoaderException>()),
      );
    });
  });

  group('InventoryExportDataLoader Pagination Integrity & Fail-Closed Tests', () {
    test('1. throws InventoryExportDataLoaderException on duplicate ID across pages', () async {
      final itemA = createItem(id: 'item-1', name: 'Item A', sku: 'SKU-A');
      final itemB = createItem(id: 'item-2', name: 'Item B', sku: 'SKU-B');
      final itemC = createItem(id: 'item-3', name: 'Item C', sku: 'SKU-C');

      final customRepo = _CustomTestInventoryRepo((q) async {
        if (q.page == 1) {
          return InventoryPage(
            items: [itemA, itemB],
            currentPage: 1,
            pageSize: 2,
            totalItems: 3,
            hasNext: true,
          );
        } else {
          // Page 2 repeats itemB
          return InventoryPage(
            items: [itemB, itemC],
            currentPage: 2,
            pageSize: 2,
            totalItems: 3,
            hasNext: false,
          );
        }
      });

      final customLoader = InventoryExportDataLoader(customRepo);
      expect(
        () => customLoader.loadAllItems(batchSize: 2),
        throwsA(isA<InventoryExportDataLoaderException>().having(
          (e) => e.message,
          'message',
          contains('Duplicate inventory item encountered during export'),
        )),
      );
    });

    test('2. throws InventoryExportDataLoaderException on duplicate ID within single page', () async {
      final itemA = createItem(id: 'item-1', name: 'Item A', sku: 'SKU-A');
      final itemADup = createItem(id: 'item-1', name: 'Item A Duplicate', sku: 'SKU-A2');

      final customRepo = _CustomTestInventoryRepo((_) async => InventoryPage(
        items: [itemA, itemADup],
        currentPage: 1,
        pageSize: 10,
        totalItems: 2,
        hasNext: false,
      ));

      final customLoader = InventoryExportDataLoader(customRepo);
      expect(
        () => customLoader.loadAllItems(batchSize: 10),
        throwsA(isA<InventoryExportDataLoaderException>().having(
          (e) => e.message,
          'message',
          contains('Duplicate inventory item encountered during export'),
        )),
      );
    });

    test('3. throws on mismatched totalItems (fewer items retrieved than reported totalItems)', () async {
      final itemA = createItem(id: 'item-1', name: 'Item A', sku: 'SKU-A');

      final customRepo = _CustomTestInventoryRepo((_) async => InventoryPage(
        items: [itemA],
        currentPage: 1,
        pageSize: 10,
        totalItems: 5,
        hasNext: false,
      ));

      final customLoader = InventoryExportDataLoader(customRepo);
      expect(
        () => customLoader.loadAllItems(batchSize: 10),
        throwsA(isA<InventoryExportDataLoaderException>().having(
          (e) => e.message,
          'message',
          contains('Inconsistent dataset completeness'),
        )),
      );
    });

    test('4. throws when hasNext is true but page returns empty items', () async {
      final customRepo = _CustomTestInventoryRepo((_) async => const InventoryPage(
        items: [],
        currentPage: 1,
        pageSize: 10,
        totalItems: 5,
        hasNext: true,
      ));

      final customLoader = InventoryExportDataLoader(customRepo);
      expect(
        () => customLoader.loadAllItems(batchSize: 10),
        throwsA(isA<InventoryExportDataLoaderException>().having(
          (e) => e.message,
          'message',
          contains('Page returned empty list while claiming next page exists'),
        )),
      );
    });

    test('5. throws when totalItems changes mid-pagination', () async {
      final itemA = createItem(id: 'item-1', name: 'Item A', sku: 'SKU-A');
      final itemB = createItem(id: 'item-2', name: 'Item B', sku: 'SKU-B');

      final customRepo = _CustomTestInventoryRepo((q) async {
        if (q.page == 1) {
          return InventoryPage(
            items: [itemA],
            currentPage: 1,
            pageSize: 1,
            totalItems: 2,
            hasNext: true,
          );
        } else {
          return InventoryPage(
            items: [itemB],
            currentPage: 2,
            pageSize: 1,
            totalItems: 3,
            hasNext: false,
          );
        }
      });

      final customLoader = InventoryExportDataLoader(customRepo);
      expect(
        () => customLoader.loadAllItems(batchSize: 1),
        throwsA(isA<InventoryExportDataLoaderException>().having(
          (e) => e.message,
          'message',
          contains('totalItems changed from 2 to 3 during pagination'),
        )),
      );
    });

    test('6. loads valid multi-page dataset correctly', () async {
      final itemA = createItem(id: 'item-1', name: 'Item A', sku: 'SKU-A');
      final itemB = createItem(id: 'item-2', name: 'Item B', sku: 'SKU-B');
      final itemC = createItem(id: 'item-3', name: 'Item C', sku: 'SKU-C');

      final customRepo = _CustomTestInventoryRepo((q) async {
        if (q.page == 1) {
          return InventoryPage(
            items: [itemA, itemB],
            currentPage: 1,
            pageSize: 2,
            totalItems: 3,
            hasNext: true,
          );
        } else {
          return InventoryPage(
            items: [itemC],
            currentPage: 2,
            pageSize: 2,
            totalItems: 3,
            hasNext: false,
          );
        }
      });

      final customLoader = InventoryExportDataLoader(customRepo);
      final items = await customLoader.loadAllItems(batchSize: 2);
      expect(items.length, equals(3));
      expect(items.map((i) => i.item.id).toList(), equals(['item-1', 'item-2', 'item-3']));
    });

    test('7. handles zero items dataset gracefully (empty export)', () async {
      final customRepo = _CustomTestInventoryRepo((_) async => const InventoryPage(
        items: [],
        currentPage: 1,
        pageSize: 10,
        totalItems: 0,
        hasNext: false,
      ));

      final customLoader = InventoryExportDataLoader(customRepo);
      final items = await customLoader.loadAllItems(batchSize: 10);
      expect(items, isEmpty);
    });

    test('8. handles dataset exactly divisible by page size', () async {
      final itemA = createItem(id: 'item-1', name: 'Item A', sku: 'SKU-A');
      final itemB = createItem(id: 'item-2', name: 'Item B', sku: 'SKU-B');

      final customRepo = _CustomTestInventoryRepo((q) async {
        if (q.page == 1) {
          return InventoryPage(
            items: [itemA],
            currentPage: 1,
            pageSize: 1,
            totalItems: 2,
            hasNext: true,
          );
        } else {
          return InventoryPage(
            items: [itemB],
            currentPage: 2,
            pageSize: 1,
            totalItems: 2,
            hasNext: false,
          );
        }
      });

      final customLoader = InventoryExportDataLoader(customRepo);
      final items = await customLoader.loadAllItems(batchSize: 1);
      expect(items.length, equals(2));
      expect(items[0].item.id, equals('item-1'));
      expect(items[1].item.id, equals('item-2'));
    });

    test('9. throws if returned page number does not match requested page', () async {
      final customRepo = _CustomTestInventoryRepo((_) async => const InventoryPage(
        items: [],
        currentPage: 99,
        pageSize: 10,
        totalItems: 0,
        hasNext: false,
      ));

      final customLoader = InventoryExportDataLoader(customRepo);
      expect(
        () => customLoader.loadAllItems(batchSize: 10),
        throwsA(isA<InventoryExportDataLoaderException>().having(
          (e) => e.message,
          'message',
          contains('Expected page 1 but received 99'),
        )),
      );
    });
  });
}
