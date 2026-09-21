import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_sort.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockInventoryRepository Tests', () {
    final testDate = DateTime.utc(2026, 1, 1, 9, 0);

    test('default instantiation loads seed data with valid SKU uniqueness', () {
      final repo = MockInventoryRepository();
      expect(repo, isNotNull);
    });

    group('SKU Uniqueness Invariant Enforcement', () {
      test('rejects exact duplicate SKU at repository boundary', () {
        final items = [
          InventoryItem(id: 'item_1', name: 'Product A', sku: 'SKU-001'),
          InventoryItem(id: 'item_2', name: 'Product B', sku: 'SKU-001'),
        ];

        expect(
          () => MockInventoryRepository(items: items),
          throwsArgumentError,
        );
      });

      test('rejects case-insensitive duplicate SKU at repository boundary', () {
        final items = [
          InventoryItem(id: 'item_1', name: 'Product A', sku: 'sku-001'),
          InventoryItem(id: 'item_2', name: 'Product B', sku: 'SKU-001'),
        ];

        expect(
          () => MockInventoryRepository(items: items),
          throwsArgumentError,
        );
      });

      test(
        'rejects whitespace-padded duplicate SKU at repository boundary',
        () {
          final items = [
            InventoryItem(id: 'item_1', name: 'Product A', sku: 'SKU-001'),
            InventoryItem(id: 'item_2', name: 'Product B', sku: '  sku-001  '),
          ];

          expect(
            () => MockInventoryRepository(items: items),
            throwsArgumentError,
          );
        },
      );
    });

    group('Dynamic Stock Derivation', () {
      test(
        'correctly calculates quantity on hand from sum of movement deltas',
        () async {
          final items = [
            InventoryItem(id: 'item_1', name: 'Product 1', sku: 'SKU-1'),
            InventoryItem(id: 'item_2', name: 'Product 2', sku: 'SKU-2'),
          ];
          final movements = [
            StockMovement(
              id: 'm1',
              inventoryItemId: 'item_1',
              type: StockMovementType.openingStock,
              quantityDelta: 15.0,
              createdAt: testDate,
            ),
            StockMovement(
              id: 'm2',
              inventoryItemId: 'item_1',
              type: StockMovementType.openingStock,
              quantityDelta: 10.0,
              createdAt: testDate,
            ),
            StockMovement(
              id: 'm3',
              inventoryItemId: 'item_2',
              type: StockMovementType.openingStock,
              quantityDelta: 5.0,
              createdAt: testDate,
            ),
          ];

          final repo = MockInventoryRepository(
            items: items,
            movements: movements,
          );
          final item1 = await repo.getItemById('item_1');
          final item2 = await repo.getItemById('item_2');

          expect(item1?.quantityOnHand, 25.0);
          expect(item2?.quantityOnHand, 5.0);
        },
      );

      test(
        'zero-stock item returns 0.0 without movement or with zero delta',
        () async {
          final items = [
            InventoryItem(id: 'item_zero', name: 'Zero Stock', sku: 'SKU-ZERO'),
          ];
          final repo = MockInventoryRepository(items: items, movements: []);
          final item = await repo.getItemById('item_zero');

          expect(item?.quantityOnHand, 0.0);
        },
      );
    });

    group('Search Filtering', () {
      test('searches by name substring case-insensitively', () async {
        final repo = MockInventoryRepository();
        final page = await repo.getItems(
          const InventoryQuery(searchText: 'laptop'),
        );

        expect(page.items.any((s) => s.item.name == 'Laptop Stand'), isTrue);
      });

      test('searches by SKU substring case-insensitively', () async {
        final repo = MockInventoryRepository();
        final page = await repo.getItems(
          const InventoryQuery(searchText: 'inv-002'),
        );

        expect(page.items.length, 1);
        expect(page.items.first.item.sku, 'INV-002');
      });

      test('returns empty page when search matches nothing', () async {
        final repo = MockInventoryRepository();
        final page = await repo.getItems(
          const InventoryQuery(searchText: 'nonexistent-query-xyz'),
        );

        expect(page.items, isEmpty);
        expect(page.totalItems, 0);
        expect(page.hasNext, isFalse);
      });
    });

    group('Sorting with Deterministic Tie-Breaking', () {
      test('sorts by nameAsc with item.id tie-break', () async {
        final items = [
          InventoryItem(id: 'id_b', name: 'Alpha', sku: 'SKU-2'),
          InventoryItem(id: 'id_a', name: 'Alpha', sku: 'SKU-1'),
          InventoryItem(id: 'id_c', name: 'Beta', sku: 'SKU-3'),
        ];
        final repo = MockInventoryRepository(items: items, movements: []);
        final page = await repo.getItems(
          const InventoryQuery(sort: InventorySort.nameAsc),
        );

        expect(page.items[0].item.id, 'id_a');
        expect(page.items[1].item.id, 'id_b');
        expect(page.items[2].item.id, 'id_c');
      });

      test('sorts by nameDesc with item.id tie-break', () async {
        final items = [
          InventoryItem(id: 'id_1', name: 'Alpha', sku: 'SKU-1'),
          InventoryItem(id: 'id_2', name: 'Beta', sku: 'SKU-2'),
        ];
        final repo = MockInventoryRepository(items: items, movements: []);
        final page = await repo.getItems(
          const InventoryQuery(sort: InventorySort.nameDesc),
        );

        expect(page.items[0].item.name, 'Beta');
        expect(page.items[1].item.name, 'Alpha');
      });

      test('sorts by skuAsc and skuDesc', () async {
        final items = [
          InventoryItem(id: 'id_1', name: 'A', sku: 'B-SKU'),
          InventoryItem(id: 'id_2', name: 'B', sku: 'A-SKU'),
        ];
        final repo = MockInventoryRepository(items: items, movements: []);
        final ascPage = await repo.getItems(
          const InventoryQuery(sort: InventorySort.skuAsc),
        );
        expect(ascPage.items[0].item.sku, 'A-SKU');
        expect(ascPage.items[1].item.sku, 'B-SKU');

        final descPage = await repo.getItems(
          const InventoryQuery(sort: InventorySort.skuDesc),
        );
        expect(descPage.items[0].item.sku, 'B-SKU');
        expect(descPage.items[1].item.sku, 'A-SKU');
      });
    });

    group('Pagination Pipeline', () {
      test(
        'paginates 25 default items into page 1 (20 items) and page 2 (5 items)',
        () async {
          final repo = MockInventoryRepository();

          final page1 = await repo.getItems(
            const InventoryQuery(page: 1, pageSize: 20),
          );
          expect(page1.items.length, 20);
          expect(page1.currentPage, 1);
          expect(page1.pageSize, 20);
          expect(page1.totalItems, 25);
          expect(page1.hasNext, isTrue);

          final page2 = await repo.getItems(
            const InventoryQuery(page: 2, pageSize: 20),
          );
          expect(page2.items.length, 5);
          expect(page2.currentPage, 2);
          expect(page2.pageSize, 20);
          expect(page2.totalItems, 25);
          expect(page2.hasNext, isFalse);
        },
      );

      test(
        'page out of range returns empty page with hasNext = false',
        () async {
          final repo = MockInventoryRepository();
          final page = await repo.getItems(
            const InventoryQuery(page: 10, pageSize: 20),
          );

          expect(page.items, isEmpty);
          expect(page.currentPage, 10);
          expect(page.totalItems, 25);
          expect(page.hasNext, isFalse);
        },
      );

      test('returns unmodifiable items list', () async {
        final repo = MockInventoryRepository();
        final page = await repo.getItems(const InventoryQuery());

        expect(() => (page.items as dynamic).clear(), throwsUnsupportedError);
      });
    });

    group('getItemById', () {
      test('returns item summary when found', () async {
        final repo = MockInventoryRepository();
        final item = await repo.getItemById('item_001');

        expect(item, isNotNull);
        expect(item?.item.id, 'item_001');
        expect(item?.item.name, 'Laptop Stand');
        expect(item?.quantityOnHand, 25.0);
      });

      test('returns null when item not found', () async {
        final repo = MockInventoryRepository();
        final item = await repo.getItemById('non_existent_id');

        expect(item, isNull);
      });
    });
  });
}
