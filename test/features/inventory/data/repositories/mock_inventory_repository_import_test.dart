import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:enterprise_crm/features/inventory/domain/exceptions/inventory_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockInventoryRepository Import', () {
    late MockInventoryRepository repository;

    setUp(() {
      repository = MockInventoryRepository(
        nowProvider: () => DateTime(2026, 9, 26, 10, 0),
      );
    });

    test(
      'getExistingSkus returns all existing SKUs normalized to lowercase',
      () async {
        final skus = await repository.getExistingSkus();
        expect(skus, contains('inv-001'));
        expect(skus, contains('inv-002'));
      },
    );

    test(
      'throws InventoryValidationException if performedByUserId is blank',
      () async {
        expect(
          () => repository.importItems(
            const InventoryImportRequest(
              performedByUserId: '   ',
              rows: [
                InventoryImportRowInput(
                  sourceRowNumber: 1,
                  name: 'Test',
                  sku: 'SKU-NEW',
                ),
              ],
            ),
          ),
          throwsA(isA<InventoryValidationException>()),
        );
      },
    );

    test('empty rows list returns zero counts immediately', () async {
      final result = await repository.importItems(
        const InventoryImportRequest(performedByUserId: 'admin_1', rows: []),
      );

      expect(result.requestedCount, 0);
      expect(result.successCount, 0);
      expect(result.failureCount, 0);
      expect(result.importedSummaries, isEmpty);
      expect(result.failures, isEmpty);
    });

    test(
      'imports item without opening stock: 0 movements created, derived qty is 0.0',
      () async {
        final result = await repository.importItems(
          const InventoryImportRequest(
            performedByUserId: 'admin_1',
            rows: [
              InventoryImportRowInput(
                sourceRowNumber: 2,
                name: 'Brand New Item',
                sku: 'SKU-BRAND-NEW',
              ),
            ],
          ),
        );

        expect(result.requestedCount, 1);
        expect(result.successCount, 1);
        expect(result.failureCount, 0);
        expect(result.importedSummaries.length, 1);

        final summary = result.importedSummaries.first;
        expect(summary.item.name, 'Brand New Item');
        expect(summary.item.sku, 'SKU-BRAND-NEW');
        expect(summary.quantityOnHand, 0.0);

        // Verify movements in repository
        final hasMovements = await repository.hasStockMovements(
          summary.item.id,
        );
        expect(hasMovements, isFalse);
      },
    );

    test(
      'imports item with opening stock: creates StockMovementType.openingStock, derived quantity strictly derived',
      () async {
        final result = await repository.importItems(
          const InventoryImportRequest(
            performedByUserId: 'admin_1',
            rows: [
              InventoryImportRowInput(
                sourceRowNumber: 2,
                name: 'Item With Stock',
                sku: 'SKU-WITH-STOCK',
                openingStock: 25.5,
              ),
            ],
          ),
        );

        expect(result.successCount, 1);
        final summary = result.importedSummaries.first;
        expect(summary.quantityOnHand, 25.5);

        final hasMovements = await repository.hasStockMovements(
          summary.item.id,
        );
        expect(hasMovements, isTrue);

        final fetched = await repository.getItemById(summary.item.id);
        expect(fetched?.quantityOnHand, 25.5);
      },
    );

    test('rejects rows with invalid name or sku', () async {
      final result = await repository.importItems(
        const InventoryImportRequest(
          performedByUserId: 'admin_1',
          rows: [
            InventoryImportRowInput(
              sourceRowNumber: 2,
              name: '   ',
              sku: 'SKU-VAL-1',
            ),
            InventoryImportRowInput(
              sourceRowNumber: 3,
              name: 'Valid Name',
              sku: '',
            ),
          ],
        ),
      );

      expect(result.requestedCount, 2);
      expect(result.successCount, 0);
      expect(result.failureCount, 2);
      expect(result.failures[0].reason, 'Name is required.');
      expect(result.failures[1].reason, 'SKU is required.');
    });

    test('rejects all occurrences of intra-request duplicate SKUs', () async {
      final result = await repository.importItems(
        const InventoryImportRequest(
          performedByUserId: 'admin_1',
          rows: [
            InventoryImportRowInput(
              sourceRowNumber: 2,
              name: 'Item 1',
              sku: 'DUP-SKU-1',
            ),
            InventoryImportRowInput(
              sourceRowNumber: 3,
              name: 'Item 2',
              sku: 'dup-sku-1',
            ),
            InventoryImportRowInput(
              sourceRowNumber: 4,
              name: 'Item 3',
              sku: 'UNIQUE-SKU',
            ),
          ],
        ),
      );

      expect(result.requestedCount, 3);
      expect(result.successCount, 1);
      expect(result.failureCount, 2);
      expect(result.failures[0].reason, 'Duplicate SKU in import file.');
      expect(result.failures[1].reason, 'Duplicate SKU in import file.');
      expect(result.importedSummaries.first.item.sku, 'UNIQUE-SKU');
    });

    test('rejects rows where SKU already exists in repository', () async {
      final result = await repository.importItems(
        const InventoryImportRequest(
          performedByUserId: 'admin_1',
          rows: [
            InventoryImportRowInput(
              sourceRowNumber: 2,
              name: 'Duplicate Repo Item',
              sku: 'inv-001',
            ),
          ],
        ),
      );

      expect(result.requestedCount, 1);
      expect(result.successCount, 0);
      expect(result.failureCount, 1);
      expect(
        result.failures.first.reason,
        'An inventory item with this SKU already exists.',
      );
    });

    test('rejects rows with negative opening stock with clear message', () async {
      final result = await repository.importItems(
        const InventoryImportRequest(
          performedByUserId: 'admin_1',
          rows: [
            InventoryImportRowInput(
              sourceRowNumber: 2,
              name: 'Negative Stock A',
              sku: 'SKU-NEG-A',
              openingStock: -1.0,
            ),
            InventoryImportRowInput(
              sourceRowNumber: 3,
              name: 'Negative Stock B',
              sku: 'SKU-NEG-B',
              openingStock: -50.5,
            ),
          ],
        ),
      );

      expect(result.failureCount, 2);
      expect(result.successCount, 0);
      expect(
        result.failures[0].reason,
        'Opening stock cannot be negative.',
      );
      expect(
        result.failures[1].reason,
        'Opening stock cannot be negative.',
      );
    });

    test('positive opening stock: creates item and exactly one ledger movement', () async {
      final result = await repository.importItems(
        const InventoryImportRequest(
          performedByUserId: 'admin_1',
          rows: [
            InventoryImportRowInput(
              sourceRowNumber: 2,
              name: 'Positive Item',
              sku: 'SKU-POS',
              openingStock: 42.5,
            ),
          ],
        ),
      );

      expect(result.successCount, 1);
      final created = result.importedSummaries.first;
      expect(created.item.sku, 'SKU-POS');
      expect(created.quantityOnHand, 42.5);

      final movements = await repository.getStockMovements(created.item.id);
      expect(movements.length, 1);
      expect(movements.first.movement.type, StockMovementType.openingStock);
      expect(movements.first.movement.quantityDelta, 42.5);
    });

    test('zero opening stock: creates item with zero ledger movements and 0 quantity', () async {
      final result = await repository.importItems(
        const InventoryImportRequest(
          performedByUserId: 'admin_1',
          rows: [
            InventoryImportRowInput(
              sourceRowNumber: 2,
              name: 'Zero Stock Item',
              sku: 'SKU-ZERO-OK',
              openingStock: 0.0,
            ),
          ],
        ),
      );

      expect(result.successCount, 1);
      expect(result.failureCount, 0);
      final created = result.importedSummaries.first;
      expect(created.item.sku, 'SKU-ZERO-OK');
      expect(created.quantityOnHand, 0.0);

      final movements = await repository.getStockMovements(created.item.id);
      expect(movements.isEmpty, isTrue);
    });

    test('blank/omitted opening stock: creates item with zero movements and 0 quantity', () async {
      final result = await repository.importItems(
        const InventoryImportRequest(
          performedByUserId: 'admin_1',
          rows: [
            InventoryImportRowInput(
              sourceRowNumber: 2,
              name: 'Blank Stock Item',
              sku: 'SKU-BLANK-OK',
              openingStock: null,
            ),
          ],
        ),
      );

      expect(result.successCount, 1);
      expect(result.failureCount, 0);
      final created = result.importedSummaries.first;
      expect(created.item.sku, 'SKU-BLANK-OK');
      expect(created.quantityOnHand, 0.0);

      final movements = await repository.getStockMovements(created.item.id);
      expect(movements.isEmpty, isTrue);
    });

    test('existing item: imported quantity cannot replace ledger quantity or duplicate movements', () async {
      // Setup existing item with positive stock
      final setupResult = await repository.importItems(
        const InventoryImportRequest(
          performedByUserId: 'admin_1',
          rows: [
            InventoryImportRowInput(
              sourceRowNumber: 2,
              name: 'Existing Product',
              sku: 'SKU-EXISTING',
              openingStock: 100.0,
            ),
          ],
        ),
      );
      final itemId = setupResult.importedSummaries.first.item.id;
      expect(setupResult.importedSummaries.first.quantityOnHand, 100.0);

      // Attempt update with a different opening stock (e.g. 500 or 0)
      final updateResult = await repository.importItems(
        InventoryImportRequest(
          performedByUserId: 'admin_1',
          mode: InventoryImportMode.createAndUpdate,
          rows: [
            InventoryImportRowInput(
              sourceRowNumber: 3,
              name: 'Existing Product Updated Name',
              sku: 'SKU-EXISTING',
              openingStock: 500.0,
              isUpdate: true,
              existingItemId: itemId,
            ),
          ],
        ),
      );

      expect(updateResult.successCount, 1);
      expect(updateResult.effectiveUpdatedCount, 1);
      // Ledger balance strictly remains 100.0
      expect(updateResult.importedSummaries.first.quantityOnHand, 100.0);

      // Movements count strictly remains 1 (no duplicate openingStock movement created)
      final movements = await repository.getStockMovements(itemId);
      expect(movements.length, 1);
      expect(movements.first.movement.quantityDelta, 100.0);
    });

    test(
      'row-level atomicity: if movement persistence fails, item is not retained in repository',
      () async {
        final repoWithFailure = MockInventoryRepository(
          simulateMovementFailure: (sku) => sku == 'SKU-FAIL-MOVEMENT',
        );

        final result = await repoWithFailure.importItems(
          const InventoryImportRequest(
            performedByUserId: 'admin_1',
            rows: [
              InventoryImportRowInput(
                sourceRowNumber: 2,
                name: 'Failing Item',
                sku: 'SKU-FAIL-MOVEMENT',
                openingStock: 10.0,
              ),
              InventoryImportRowInput(
                sourceRowNumber: 3,
                name: 'Succeeding Item',
                sku: 'SKU-SUCCEED',
                openingStock: 15.0,
              ),
            ],
          ),
        );

        expect(result.requestedCount, 2);
        expect(result.successCount, 1);
        expect(result.failureCount, 1);
        expect(result.failures.first.sku, 'SKU-FAIL-MOVEMENT');
        expect(result.importedSummaries.first.item.sku, 'SKU-SUCCEED');

        // Verify failing item does NOT exist in repository
        final existingSkus = await repoWithFailure.getExistingSkus();
        expect(existingSkus.contains('sku-fail-movement'), isFalse);
        expect(existingSkus.contains('sku-succeed'), isTrue);
      },
    );
  });
}
