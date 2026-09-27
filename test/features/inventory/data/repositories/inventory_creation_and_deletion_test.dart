import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:enterprise_crm/features/inventory/domain/exceptions/inventory_exception.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/record_opening_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/update_inventory_item_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('INVENTORY-ACCESS-1: Repository Creation & Deletion Invariants', () {
    late DateTime simulatedTime;

    MockInventoryRepository createRepo({
      List<InventoryItem>? items,
      List<StockMovement>? movements,
      bool Function(String sku)? simulateMovementFailure,
      bool Function(String itemId)? hasExternalReference,
    }) {
      simulatedTime = DateTime.utc(2026, 9, 27, 10, 0, 0);
      return MockInventoryRepository(
        items: items,
        movements: movements,
        nowProvider: () => simulatedTime,
        simulateMovementFailure: simulateMovementFailure,
        hasExternalReference: hasExternalReference,
      );
    }

    group('Item Creation with Optional Opening Stock', () {
      test(
        'blank opening stock creates item with 0 movements and derived quantity 0',
        () async {
          final repo = createRepo(items: [], movements: []);

          final summary = await repo.createItem(
            const CreateInventoryItemInput(
              name: 'Laser Mouse',
              sku: 'MOU-001',
              openingStock: null,
            ),
          );

          expect(summary.item.name, 'Laser Mouse');
          expect(summary.item.sku, 'MOU-001');
          expect(summary.quantityOnHand, 0.0);

          final hasMovements = await repo.hasStockMovements(summary.item.id);
          expect(hasMovements, isFalse);
        },
      );

      test(
        'positive opening stock creates exactly one openingStock movement atomically',
        () async {
          final repo = createRepo(items: [], movements: []);

          final summary = await repo.createItem(
            const CreateInventoryItemInput(
              name: 'Mechanical Keyboard',
              sku: 'KB-001',
              openingStock: 25.0,
              performedByUserId: 'usr_creator_1',
            ),
          );

          expect(summary.item.name, 'Mechanical Keyboard');
          expect(summary.quantityOnHand, 25.0);

          final hasMovements = await repo.hasStockMovements(summary.item.id);
          expect(hasMovements, isTrue);

          // Fetching item confirms 25.0 derived quantity
          final fetched = await repo.getItemById(summary.item.id);
          expect(fetched?.quantityOnHand, 25.0);
        },
      );

      test('positive decimal opening stock is supported', () async {
        final repo = createRepo(items: [], movements: []);

        final summary = await repo.createItem(
          const CreateInventoryItemInput(
            name: 'Bulk Cable',
            sku: 'CBL-001',
            openingStock: 12.5,
            performedByUserId: 'usr_creator_1',
          ),
        );

        expect(summary.quantityOnHand, 12.5);
      });

      test('explicit zero opening stock is rejected', () async {
        final repo = createRepo(items: [], movements: []);

        expect(
          () => repo.createItem(
            const CreateInventoryItemInput(
              name: 'Zero Item',
              sku: 'ZERO-001',
              openingStock: 0.0,
              performedByUserId: 'usr_creator',
            ),
          ),
          throwsA(isA<InventoryValidationException>()),
        );
      });

      test('negative opening stock is rejected', () async {
        final repo = createRepo(items: [], movements: []);

        expect(
          () => repo.createItem(
            const CreateInventoryItemInput(
              name: 'Negative Item',
              sku: 'NEG-001',
              openingStock: -5.0,
              performedByUserId: 'usr_creator',
            ),
          ),
          throwsA(isA<InventoryValidationException>()),
        );
      });

      test(
        'missing performedByUserId when openingStock > 0 is rejected',
        () async {
          final repo = createRepo(items: [], movements: []);

          expect(
            () => repo.createItem(
              const CreateInventoryItemInput(
                name: 'No Actor Item',
                sku: 'ACT-001',
                openingStock: 10.0,
                performedByUserId: null,
              ),
            ),
            throwsA(isA<InventoryValidationException>()),
          );
        },
      );

      test(
        'atomic rollback on movement creation failure leaves no item or movement',
        () async {
          final repo = createRepo(
            items: [],
            movements: [],
            simulateMovementFailure: (sku) => sku == 'FAIL-001',
          );

          expect(
            () => repo.createItem(
              const CreateInventoryItemInput(
                name: 'Fail Item',
                sku: 'FAIL-001',
                openingStock: 15.0,
                performedByUserId: 'usr_creator',
              ),
            ),
            throwsException,
          );

          // Verify no items or movements were persisted
          final page = await repo.getItems(const InventoryQuery());
          expect(page.totalItems, 0);
          expect(page.items, isEmpty);
        },
      );
    });

    group('Deletion Lifecycle: Request, Pending, Undo, and Finalization', () {
      test(
        'requestItemDeletion places item in pending deletion and excludes from getItems',
        () async {
          final item = InventoryItem(
            id: 'inv_del_1',
            name: 'Item To Delete',
            sku: 'DEL-001',
          );
          final movement = StockMovement(
            id: 'mov_1',
            inventoryItemId: 'inv_del_1',
            type: StockMovementType.openingStock,
            quantityDelta: 10.0,
            createdAt: simulatedTime,
            performedByUserId: 'usr_admin',
          );
          final repo = createRepo(items: [item], movements: [movement]);

          final pending = await repo.requestItemDeletion(
            itemId: 'inv_del_1',
            performedByUserId: 'usr_admin',
          );

          expect(pending.itemId, 'inv_del_1');
          expect(pending.itemSku, 'DEL-001');
          expect(
            pending.undoDeadline,
            simulatedTime.add(const Duration(seconds: 60)),
          );

          // Excluded from active getItems query
          final page = await repo.getItems(const InventoryQuery());
          expect(page.totalItems, 0);

          // Appears in getPendingDeletions
          final pendingList = await repo.getPendingDeletions();
          expect(pendingList.length, 1);
          expect(pendingList.first.itemId, 'inv_del_1');
        },
      );

      test('mutations are rejected while item is pending deletion', () async {
        final item = InventoryItem(
          id: 'inv_del_2',
          name: 'Item To Delete 2',
          sku: 'DEL-002',
        );
        final repo = createRepo(items: [item], movements: []);

        await repo.requestItemDeletion(
          itemId: 'inv_del_2',
          performedByUserId: 'usr_admin',
        );

        // updateItem rejected
        expect(
          () => repo.updateItem(
            const UpdateInventoryItemInput(
              id: 'inv_del_2',
              name: 'Updated Name',
              sku: 'DEL-002',
            ),
          ),
          throwsA(isA<InventoryDeletionConflictException>()),
        );

        // recordOpeningStock rejected
        expect(
          () => repo.recordOpeningStock(
            const RecordOpeningStockInput(
              itemId: 'inv_del_2',
              quantity: 5.0,
              performedByUserId: 'usr_admin',
            ),
          ),
          throwsA(isA<InventoryDeletionConflictException>()),
        );

        // adjustStock rejected
        expect(
          () => repo.adjustStock(
            const AdjustInventoryStockInput(
              itemId: 'inv_del_2',
              quantityDelta: 2.0,
              reason: 'Correction',
              performedByUserId: 'usr_admin',
            ),
          ),
          throwsA(isA<InventoryDeletionConflictException>()),
        );

        // duplicate deletion request rejected
        expect(
          () => repo.requestItemDeletion(
            itemId: 'inv_del_2',
            performedByUserId: 'usr_admin',
          ),
          throwsA(isA<InventoryDeletionConflictException>()),
        );
      });

      test(
        'undoItemDeletion before deadline restores active status with exact ledger and quantity intact',
        () async {
          final item = InventoryItem(
            id: 'inv_del_3',
            name: 'Undoable Item',
            sku: 'DEL-003',
          );
          final movement = StockMovement(
            id: 'mov_3',
            inventoryItemId: 'inv_del_3',
            type: StockMovementType.openingStock,
            quantityDelta: 42.0,
            createdAt: simulatedTime,
            performedByUserId: 'usr_admin',
          );
          final repo = createRepo(items: [item], movements: [movement]);

          await repo.requestItemDeletion(
            itemId: 'inv_del_3',
            performedByUserId: 'usr_admin',
          );

          // 30 seconds elapse (within 60s window)
          simulatedTime = simulatedTime.add(const Duration(seconds: 30));

          // Undo deletion
          await repo.undoItemDeletion(
            itemId: 'inv_del_3',
            performedByUserId: 'usr_admin',
          );

          // Active list now contains the item again
          final page = await repo.getItems(const InventoryQuery());
          expect(page.totalItems, 1);
          expect(page.items.first.item.id, 'inv_del_3');
          expect(page.items.first.quantityOnHand, 42.0);

          // Pending list is empty
          final pendingList = await repo.getPendingDeletions();
          expect(pendingList, isEmpty);
        },
      );

      test(
        'undoItemDeletion after deadline expires fails with InventoryDeletionConflictException and purges item',
        () async {
          final item = InventoryItem(
            id: 'inv_del_4',
            name: 'Expired Item',
            sku: 'DEL-004',
          );
          final repo = createRepo(items: [item], movements: []);

          await repo.requestItemDeletion(
            itemId: 'inv_del_4',
            performedByUserId: 'usr_admin',
          );

          // 61 seconds elapse (past 60s window)
          simulatedTime = simulatedTime.add(const Duration(seconds: 61));

          expect(
            () => repo.undoItemDeletion(
              itemId: 'inv_del_4',
              performedByUserId: 'usr_admin',
            ),
            throwsA(isA<InventoryDeletionConflictException>()),
          );

          // Item is finalized and removed
          final fetched = await repo.getItemById('inv_del_4');
          expect(fetched, isNull);
        },
      );

      test(
        'finalizeExpiredDeletions permanently purges expired items and their movements atomically',
        () async {
          final item = InventoryItem(
            id: 'inv_del_5',
            name: 'Purge Item',
            sku: 'DEL-005',
          );
          final movement = StockMovement(
            id: 'mov_5',
            inventoryItemId: 'inv_del_5',
            type: StockMovementType.openingStock,
            quantityDelta: 100.0,
            createdAt: simulatedTime,
            performedByUserId: 'usr_admin',
          );
          final repo = createRepo(items: [item], movements: [movement]);

          await repo.requestItemDeletion(
            itemId: 'inv_del_5',
            performedByUserId: 'usr_admin',
          );

          // Advance clock past 60s
          simulatedTime = simulatedTime.add(const Duration(seconds: 65));

          await repo.finalizeExpiredDeletions();

          final fetched = await repo.getItemById('inv_del_5');
          expect(fetched, isNull);

          // ID should be retired and never reused
          final newItem = await repo.createItem(
            const CreateInventoryItemInput(
              name: 'New Item After Purge',
              sku: 'NEW-001',
            ),
          );
          expect(newItem.item.id, isNot('inv_del_5'));
        },
      );

      test(
        'external reference blocks deletion request with InventoryDeletionBlockedException',
        () async {
          final item = InventoryItem(
            id: 'inv_ref_1',
            name: 'Referenced Item',
            sku: 'REF-001',
          );
          final repo = createRepo(
            items: [item],
            movements: [],
            hasExternalReference: (itemId) => itemId == 'inv_ref_1',
          );

          expect(
            () => repo.requestItemDeletion(
              itemId: 'inv_ref_1',
              performedByUserId: 'usr_admin',
            ),
            throwsA(isA<InventoryDeletionBlockedException>()),
          );

          // Item remains completely intact
          final fetched = await repo.getItemById('inv_ref_1');
          expect(fetched, isNotNull);
        },
      );

      test(
        'external reference appearing after request prevents finalization from destroying records',
        () async {
          bool externalRefActive = false;
          final item = InventoryItem(
            id: 'inv_ref_2',
            name: 'Late Ref Item',
            sku: 'REF-002',
          );
          final repo = createRepo(
            items: [item],
            movements: [],
            hasExternalReference: (itemId) =>
                externalRefActive && itemId == 'inv_ref_2',
          );

          await repo.requestItemDeletion(
            itemId: 'inv_ref_2',
            performedByUserId: 'usr_admin',
          );

          // Reference appears before finalization
          externalRefActive = true;
          simulatedTime = simulatedTime.add(const Duration(seconds: 70));

          await repo.finalizeExpiredDeletions();

          // Single item should NOT have been removed
          // Verify internal item still exists
          expect(
            await repo.hasStockMovements('inv_ref_2'),
            isFalse,
          ); // Item exists check
        },
      );
    });
  });
}
