import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/record_opening_stock_input.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_data_loader.dart';

void main() {
  late MockInventoryRepository repository;
  late InventoryExportDataLoader loader;

  setUp(() {
    repository = MockInventoryRepository();
    loader = InventoryExportDataLoader(repository);
  });

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
}
