import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_record.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:enterprise_crm/features/inventory/domain/exceptions/inventory_exception.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/record_opening_stock_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockInventoryRepository.getStockMovements', () {
    late DateTime fixedNow;
    DateTime nowProvider() => fixedNow;

    setUp(() {
      fixedNow = DateTime.utc(2026, 9, 28, 10, 0);
    });

    test(
      'Case 1: Opening Stock creates single record with initial running balance',
      () async {
        final repository = MockInventoryRepository(
          items: [
            InventoryItem(id: 'item_001', name: 'Widget A', sku: 'SKU-001'),
          ],
          movements: [],
          nowProvider: nowProvider,
        );

        await repository.recordOpeningStock(
          RecordOpeningStockInput(
            itemId: 'item_001',
            quantity: 50.0,
            performedByUserId: 'usr_admin',
          ),
        );

        final records = await repository.getStockMovements('item_001');

        expect(records, hasLength(1));
        expect(records.first.movement.quantityDelta, 50.0);
        expect(records.first.movement.type, StockMovementType.openingStock);
        expect(records.first.runningBalance, 50.0);
      },
    );

    test(
      'Case 2: Multiple adjustments calculate forward balances and return newest first',
      () async {
        final repository = MockInventoryRepository(
          items: [
            InventoryItem(id: 'item_001', name: 'Widget A', sku: 'SKU-001'),
          ],
          movements: [
            StockMovement(
              id: 'mov_1',
              inventoryItemId: 'item_001',
              type: StockMovementType.openingStock,
              quantityDelta: 50.0,
              createdAt: DateTime.utc(2026, 1, 1, 9, 0),
              performedByUserId: 'usr_admin',
            ),
            StockMovement(
              id: 'mov_2',
              inventoryItemId: 'item_001',
              type: StockMovementType.adjustment,
              quantityDelta: 20.0,
              createdAt: DateTime.utc(2026, 1, 2, 9, 0),
              performedByUserId: 'usr_admin',
              reason: 'Supplier shipment',
            ),
            StockMovement(
              id: 'mov_3',
              inventoryItemId: 'item_001',
              type: StockMovementType.adjustment,
              quantityDelta: -10.0,
              createdAt: DateTime.utc(2026, 1, 3, 9, 0),
              performedByUserId: 'usr_admin',
              reason: 'Damaged item write-off',
            ),
          ],
          nowProvider: nowProvider,
        );

        final records = await repository.getStockMovements('item_001');

        expect(records, hasLength(3));

        // Returned newest first: mov_3, mov_2, mov_1
        expect(records[0].movement.id, 'mov_3');
        expect(records[0].movement.quantityDelta, -10.0);
        expect(records[0].runningBalance, 60.0); // 50 + 20 - 10 = 60

        expect(records[1].movement.id, 'mov_2');
        expect(records[1].movement.quantityDelta, 20.0);
        expect(records[1].runningBalance, 70.0); // 50 + 20 = 70

        expect(records[2].movement.id, 'mov_1');
        expect(records[2].movement.quantityDelta, 50.0);
        expect(records[2].runningBalance, 50.0); // 50
      },
    );

    test('Case 3: Supports positive decimal quantities accurately', () async {
      final repository = MockInventoryRepository(
        items: [
          InventoryItem(id: 'item_001', name: 'Bulk Grain', sku: 'SKU-BULK'),
        ],
        movements: [
          StockMovement(
            id: 'mov_1',
            inventoryItemId: 'item_001',
            type: StockMovementType.openingStock,
            quantityDelta: 12.75,
            createdAt: DateTime.utc(2026, 1, 1, 9, 0),
          ),
          StockMovement(
            id: 'mov_2',
            inventoryItemId: 'item_001',
            type: StockMovementType.adjustment,
            quantityDelta: 5.5,
            createdAt: DateTime.utc(2026, 1, 2, 9, 0),
            reason: 'Partial bag intake',
          ),
        ],
        nowProvider: nowProvider,
      );

      final records = await repository.getStockMovements('item_001');

      expect(records, hasLength(2));
      expect(records[0].runningBalance, 18.25);
      expect(records[1].runningBalance, 12.75);
    });

    test('Case 4: Preserves negative adjustments exactly', () async {
      final repository = MockInventoryRepository(
        items: [
          InventoryItem(id: 'item_001', name: 'Widget A', sku: 'SKU-001'),
        ],
        movements: [
          StockMovement(
            id: 'mov_1',
            inventoryItemId: 'item_001',
            type: StockMovementType.openingStock,
            quantityDelta: 100.0,
            createdAt: DateTime.utc(2026, 1, 1, 9, 0),
          ),
          StockMovement(
            id: 'mov_2',
            inventoryItemId: 'item_001',
            type: StockMovementType.adjustment,
            quantityDelta: -33.0,
            createdAt: DateTime.utc(2026, 1, 2, 9, 0),
            reason: 'Defective batch returned',
          ),
        ],
        nowProvider: nowProvider,
      );

      final records = await repository.getStockMovements('item_001');

      expect(records[0].movement.quantityDelta, -33.0);
      expect(records[0].runningBalance, 67.0);
      expect(records[0].movement.reason, 'Defective batch returned');
    });

    test(
      'Case 5: Retains full history when initialized item balance returns to zero',
      () async {
        final repository = MockInventoryRepository(
          items: [
            InventoryItem(id: 'item_001', name: 'Widget A', sku: 'SKU-001'),
          ],
          movements: [
            StockMovement(
              id: 'mov_1',
              inventoryItemId: 'item_001',
              type: StockMovementType.openingStock,
              quantityDelta: 50.0,
              createdAt: DateTime.utc(2026, 1, 1, 9, 0),
            ),
            StockMovement(
              id: 'mov_2',
              inventoryItemId: 'item_001',
              type: StockMovementType.adjustment,
              quantityDelta: -50.0,
              createdAt: DateTime.utc(2026, 1, 2, 9, 0),
              reason: 'All sold out',
            ),
          ],
          nowProvider: nowProvider,
        );

        final records = await repository.getStockMovements('item_001');

        expect(records, hasLength(2));
        expect(records[0].runningBalance, 0.0);
        expect(records[1].runningBalance, 50.0);

        final summary = await repository.getItemById('item_001');
        expect(summary!.quantityOnHand, 0.0);
      },
    );

    test(
      'Case 6: Returns empty list for existing item with no movements',
      () async {
        final repository = MockInventoryRepository(
          items: [
            InventoryItem(
              id: 'item_empty',
              name: 'Uninitialized Item',
              sku: 'SKU-EMPTY',
            ),
          ],
          movements: [],
          nowProvider: nowProvider,
        );

        final records = await repository.getStockMovements('item_empty');

        expect(records, isEmpty);
      },
    );

    test(
      'Case 7: Throws InventoryItemNotFoundException for unknown item ID',
      () async {
        final repository = MockInventoryRepository(
          items: [],
          movements: [],
          nowProvider: nowProvider,
        );

        expect(
          () => repository.getStockMovements('nonexistent_id'),
          throwsA(isA<InventoryItemNotFoundException>()),
        );
      },
    );

    test('Case 8: Movements do not leak across different item IDs', () async {
      final repository = MockInventoryRepository(
        items: [
          InventoryItem(id: 'item_A', name: 'Item A', sku: 'SKU-A'),
          InventoryItem(id: 'item_B', name: 'Item B', sku: 'SKU-B'),
        ],
        movements: [
          StockMovement(
            id: 'mov_A1',
            inventoryItemId: 'item_A',
            type: StockMovementType.openingStock,
            quantityDelta: 50.0,
            createdAt: DateTime.utc(2026, 1, 1, 9, 0),
          ),
          StockMovement(
            id: 'mov_B1',
            inventoryItemId: 'item_B',
            type: StockMovementType.openingStock,
            quantityDelta: 100.0,
            createdAt: DateTime.utc(2026, 1, 1, 9, 0),
          ),
          StockMovement(
            id: 'mov_A2',
            inventoryItemId: 'item_A',
            type: StockMovementType.adjustment,
            quantityDelta: -10.0,
            createdAt: DateTime.utc(2026, 1, 2, 9, 0),
            reason: 'Loss',
          ),
        ],
        nowProvider: nowProvider,
      );

      final recordsA = await repository.getStockMovements('item_A');
      final recordsB = await repository.getStockMovements('item_B');

      expect(recordsA, hasLength(2));
      expect(
        recordsA.every((r) => r.movement.inventoryItemId == 'item_A'),
        isTrue,
      );
      expect(recordsA[0].runningBalance, 40.0);
      expect(recordsA[1].runningBalance, 50.0);

      expect(recordsB, hasLength(1));
      expect(
        recordsB.every((r) => r.movement.inventoryItemId == 'item_B'),
        isTrue,
      );
      expect(recordsB[0].runningBalance, 100.0);
    });

    test(
      'Case 9: Guarantees deterministic sequencing when timestamps are identical',
      () async {
        final sharedTimestamp = DateTime.utc(2026, 1, 1, 9, 0);

        final repository = MockInventoryRepository(
          items: [
            InventoryItem(id: 'item_001', name: 'Widget A', sku: 'SKU-001'),
          ],
          movements: [
            StockMovement(
              id: 'mov_A',
              inventoryItemId: 'item_001',
              type: StockMovementType.openingStock,
              quantityDelta: 50.0,
              createdAt: sharedTimestamp,
            ),
            StockMovement(
              id: 'mov_B',
              inventoryItemId: 'item_001',
              type: StockMovementType.adjustment,
              quantityDelta: 10.0,
              createdAt: sharedTimestamp,
              reason: 'Batch intake 1',
            ),
            StockMovement(
              id: 'mov_C',
              inventoryItemId: 'item_001',
              type: StockMovementType.adjustment,
              quantityDelta: -5.0,
              createdAt: sharedTimestamp,
              reason: 'Batch sample test',
            ),
          ],
          nowProvider: nowProvider,
        );

        final records = await repository.getStockMovements('item_001');

        expect(records, hasLength(3));

        // Insertion sequence: A (+50) -> B (+10) -> C (-5)
        // Balances: A -> 50, B -> 60, C -> 55
        // Returned newest-first: C, B, A
        expect(records[0].movement.id, 'mov_C');
        expect(records[0].runningBalance, 55.0);

        expect(records[1].movement.id, 'mov_B');
        expect(records[1].runningBalance, 60.0);

        expect(records[2].movement.id, 'mov_A');
        expect(records[2].runningBalance, 50.0);
      },
    );

    test(
      'Case 10: Repeated reads return identical results and do not mutate repository state',
      () async {
        final repository = MockInventoryRepository(
          items: [
            InventoryItem(id: 'item_001', name: 'Widget A', sku: 'SKU-001'),
          ],
          movements: [
            StockMovement(
              id: 'mov_1',
              inventoryItemId: 'item_001',
              type: StockMovementType.openingStock,
              quantityDelta: 50.0,
              createdAt: DateTime.utc(2026, 1, 1, 9, 0),
            ),
          ],
          nowProvider: nowProvider,
        );

        final read1 = await repository.getStockMovements('item_001');
        final read2 = await repository.getStockMovements('item_001');

        expect(read1, equals(read2));
        expect(read1.first.runningBalance, read2.first.runningBalance);
      },
    );

    test(
      'Case 11: Preserves legacy nullable fields without fabrication',
      () async {
        final repository = MockInventoryRepository(
          items: [
            InventoryItem(
              id: 'item_legacy',
              name: 'Legacy Widget',
              sku: 'SKU-LEGACY',
            ),
          ],
          movements: [
            StockMovement(
              id: 'mov_legacy',
              inventoryItemId: 'item_legacy',
              type: StockMovementType.openingStock,
              quantityDelta: 25.0,
              createdAt: DateTime.utc(2026, 1, 1, 9, 0),
              performedByUserId: null,
              reason: null,
            ),
          ],
          nowProvider: nowProvider,
        );

        final records = await repository.getStockMovements('item_legacy');

        expect(records, hasLength(1));
        expect(records.first.movement.performedByUserId, isNull);
        expect(records.first.movement.reason, isNull);
        expect(records.first.runningBalance, 25.0);
      },
    );

    test('Case 12: Returned collection is unmodifiable', () async {
      final repository = MockInventoryRepository(
        items: [
          InventoryItem(id: 'item_001', name: 'Widget A', sku: 'SKU-001'),
        ],
        movements: [
          StockMovement(
            id: 'mov_1',
            inventoryItemId: 'item_001',
            type: StockMovementType.openingStock,
            quantityDelta: 50.0,
            createdAt: DateTime.utc(2026, 1, 1, 9, 0),
          ),
        ],
        nowProvider: nowProvider,
      );

      final records = await repository.getStockMovements('item_001');

      expect(
        () => records.add(
          StockMovementRecord(
            movement: records.first.movement,
            runningBalance: 999.0,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    group('Deletion Integration & Invariants', () {
      test('Active item movement history is accessible', () async {
        final repository = MockInventoryRepository(
          items: [
            InventoryItem(id: 'item_001', name: 'Widget A', sku: 'SKU-001'),
          ],
          movements: [
            StockMovement(
              id: 'mov_1',
              inventoryItemId: 'item_001',
              type: StockMovementType.openingStock,
              quantityDelta: 50.0,
              createdAt: DateTime.utc(2026, 1, 1, 9, 0),
            ),
          ],
          nowProvider: nowProvider,
        );

        final records = await repository.getStockMovements('item_001');
        expect(records, hasLength(1));
      });

      test(
        'Pending deletion item movement history remains fully accessible in read-only mode',
        () async {
          final repository = MockInventoryRepository(
            items: [
              InventoryItem(id: 'item_001', name: 'Widget A', sku: 'SKU-001'),
            ],
            movements: [
              StockMovement(
                id: 'mov_1',
                inventoryItemId: 'item_001',
                type: StockMovementType.openingStock,
                quantityDelta: 50.0,
                createdAt: DateTime.utc(2026, 1, 1, 9, 0),
              ),
            ],
            nowProvider: nowProvider,
          );

          // Initiate deletion
          final pending = await repository.requestItemDeletion(
            itemId: 'item_001',
            performedByUserId: 'usr_admin',
          );

          expect(pending.status.name, 'pending');

          // Reading history during pending deletion window must succeed
          final records = await repository.getStockMovements('item_001');
          expect(records, hasLength(1));
          expect(records.first.runningBalance, 50.0);

          // Deletion state is completely unaffected by reading history
          final activePending = await repository.getPendingDeletions();
          expect(activePending, hasLength(1));
          expect(activePending.first.itemId, 'item_001');
        },
      );

      test(
        'Successful Undo retains complete original movement ledger intact',
        () async {
          final repository = MockInventoryRepository(
            items: [
              InventoryItem(id: 'item_001', name: 'Widget A', sku: 'SKU-001'),
            ],
            movements: [
              StockMovement(
                id: 'mov_1',
                inventoryItemId: 'item_001',
                type: StockMovementType.openingStock,
                quantityDelta: 50.0,
                createdAt: DateTime.utc(2026, 1, 1, 9, 0),
                performedByUserId: 'usr_admin',
              ),
              StockMovement(
                id: 'mov_2',
                inventoryItemId: 'item_001',
                type: StockMovementType.adjustment,
                quantityDelta: 15.0,
                createdAt: DateTime.utc(2026, 1, 2, 9, 0),
                performedByUserId: 'usr_admin',
                reason: 'Restock',
              ),
            ],
            nowProvider: nowProvider,
          );

          // Request deletion
          await repository.requestItemDeletion(
            itemId: 'item_001',
            performedByUserId: 'usr_admin',
          );

          // Undo deletion within 60s
          fixedNow = fixedNow.add(const Duration(seconds: 10));
          await repository.undoItemDeletion(
            itemId: 'item_001',
            performedByUserId: 'usr_admin',
          );

          // History retrieval returns original movements intact
          final records = await repository.getStockMovements('item_001');
          expect(records, hasLength(2));
          expect(records[0].movement.id, 'mov_2');
          expect(records[0].runningBalance, 65.0);
          expect(records[1].movement.id, 'mov_1');
          expect(records[1].runningBalance, 50.0);
        },
      );

      test('Finalized deletion permanently removes history access', () async {
        final repository = MockInventoryRepository(
          items: [
            InventoryItem(id: 'item_001', name: 'Widget A', sku: 'SKU-001'),
          ],
          movements: [
            StockMovement(
              id: 'mov_1',
              inventoryItemId: 'item_001',
              type: StockMovementType.openingStock,
              quantityDelta: 50.0,
              createdAt: DateTime.utc(2026, 1, 1, 9, 0),
            ),
          ],
          nowProvider: nowProvider,
        );

        // Request deletion at T=0
        await repository.requestItemDeletion(
          itemId: 'item_001',
          performedByUserId: 'usr_admin',
        );

        // Advance time past 60s deadline
        fixedNow = fixedNow.add(const Duration(seconds: 61));

        // Finalize expired deletions
        await repository.finalizeExpiredDeletions();

        // Querying stock history for permanently deleted item throws InventoryItemNotFoundException
        expect(
          () => repository.getStockMovements('item_001'),
          throwsA(isA<InventoryItemNotFoundException>()),
        );
      });

      test(
        'Terminal historical balance always equals current repository-derived quantity',
        () async {
          final repository = MockInventoryRepository(
            items: [
              InventoryItem(id: 'item_001', name: 'Widget A', sku: 'SKU-001'),
            ],
            movements: [
              StockMovement(
                id: 'mov_1',
                inventoryItemId: 'item_001',
                type: StockMovementType.openingStock,
                quantityDelta: 100.0,
                createdAt: DateTime.utc(2026, 1, 1, 9, 0),
              ),
              StockMovement(
                id: 'mov_2',
                inventoryItemId: 'item_001',
                type: StockMovementType.adjustment,
                quantityDelta: -25.0,
                createdAt: DateTime.utc(2026, 1, 2, 9, 0),
                reason: 'Sold 25',
              ),
              StockMovement(
                id: 'mov_3',
                inventoryItemId: 'item_001',
                type: StockMovementType.adjustment,
                quantityDelta: 10.0,
                createdAt: DateTime.utc(2026, 1, 3, 9, 0),
                reason: 'Restock 10',
              ),
            ],
            nowProvider: nowProvider,
          );

          final records = await repository.getStockMovements('item_001');
          final summary = await repository.getItemById('item_001');

          // Terminal balance in newest-first list is the first item
          final terminalHistoryBalance = records.first.runningBalance;
          final currentDerivedQuantity = summary!.quantityOnHand;

          expect(terminalHistoryBalance, 85.0);
          expect(currentDerivedQuantity, 85.0);
          expect(terminalHistoryBalance, equals(currentDerivedQuantity));
        },
      );
    });
  });
}
