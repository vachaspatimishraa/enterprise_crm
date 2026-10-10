import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Inventory Quantity Integrity Invariant Tests', () {
    test(
      'list projection and details projection derive identical quantity for every item',
      () async {
        final repo = MockInventoryRepository();

        // Retrieve all items via paginated list
        final page1 = await repo.getItems(
          const InventoryQuery(page: 1, pageSize: 20),
        );
        final page2 = await repo.getItems(
          const InventoryQuery(page: 2, pageSize: 20),
        );
        final allListItems = [...page1.items, ...page2.items];

        expect(allListItems.length, 25);

        // Verify each item's quantity in the list exactly equals its quantity in getItemById
        for (final summary in allListItems) {
          final details = await repo.getItemById(summary.item.id);
          expect(details, isNotNull);
          expect(
            summary.quantityOnHand,
            equals(details!.quantityOnHand),
            reason:
                'Item ${summary.item.id} quantity mismatch between list and details',
          );
        }
      },
    );

    test(
      'multiple movements for a single item aggregate consistently across list and details',
      () async {
        final testItem = InventoryItem(
          id: 'item_test',
          name: 'Test Product',
          sku: 'SKU-TEST',
        );
        final movements = [
          StockMovement(
            id: 'm1',
            inventoryItemId: 'item_test',
            type: StockMovementType.openingStock,
            quantityDelta: 100.0,
            createdAt: DateTime.utc(2026, 1, 1),
          ),
          StockMovement(
            id: 'm2',
            inventoryItemId: 'item_test',
            type: StockMovementType.openingStock,
            quantityDelta: 50.5,
            createdAt: DateTime.utc(2026, 1, 2),
          ),
        ];

        final repo = MockInventoryRepository(
          items: [testItem],
          movements: movements,
        );

        final listResult = await repo.getItems(const InventoryQuery());
        final detailsResult = await repo.getItemById('item_test');

        expect(listResult.items.first.quantityOnHand, 150.5);
        expect(detailsResult?.quantityOnHand, 150.5);
        expect(
          listResult.items.first.quantityOnHand,
          equals(detailsResult!.quantityOnHand),
        );
      },
    );
  });
}
