import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
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

    test('rejects rows with zero or negative opening stock', () async {
      final result = await repository.importItems(
        const InventoryImportRequest(
          performedByUserId: 'admin_1',
          rows: [
            InventoryImportRowInput(
              sourceRowNumber: 2,
              name: 'Zero Stock',
              sku: 'SKU-ZERO',
              openingStock: 0.0,
            ),
            InventoryImportRowInput(
              sourceRowNumber: 3,
              name: 'Negative Stock',
              sku: 'SKU-NEG',
              openingStock: -5.0,
            ),
          ],
        ),
      );

      expect(result.failureCount, 2);
      expect(
        result.failures[0].reason,
        'Opening stock must be greater than zero.',
      );
      expect(
        result.failures[1].reason,
        'Opening stock must be greater than zero.',
      );
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
