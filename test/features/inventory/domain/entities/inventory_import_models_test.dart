import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryImportField', () {
    test('label returns correct user-facing labels', () {
      expect(InventoryImportField.name.label, 'Name');
      expect(InventoryImportField.sku.label, 'SKU');
      expect(InventoryImportField.openingStock.label, 'Opening Stock');
    });

    test(
      'isRequired correctly marks name and sku as required, opening stock as optional',
      () {
        expect(InventoryImportField.name.isRequired, isTrue);
        expect(InventoryImportField.sku.isRequired, isTrue);
        expect(InventoryImportField.openingStock.isRequired, isFalse);
      },
    );
  });

  group('InventoryImportColumnMapping', () {
    test('isValid is true only when name and sku are mapped', () {
      const empty = InventoryImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
      );
      expect(empty.isValid, isFalse);

      final withName = empty.copyWith(nameColumnIndex: 0);
      expect(withName.isValid, isFalse);

      final withBoth = withName.copyWith(skuColumnIndex: 1);
      expect(withBoth.isValid, isTrue);

      final withAll = withBoth.copyWith(openingStockColumnIndex: 2);
      expect(withAll.isValid, isTrue);
    });

    test('mappedColumnIndices contains all mapped column indices', () {
      const mapping = InventoryImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 1,
        skuColumnIndex: 3,
        openingStockColumnIndex: 5,
      );

      expect(mapping.mappedColumnIndices, {1, 3, 5});
    });

    test('getColumnFor returns correct column for destination field', () {
      const mapping = InventoryImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 1,
        skuColumnIndex: 3,
        openingStockColumnIndex: 5,
      );

      expect(mapping.getColumnFor(InventoryImportField.name), 1);
      expect(mapping.getColumnFor(InventoryImportField.sku), 3);
      expect(mapping.getColumnFor(InventoryImportField.openingStock), 5);
    });

    test('copyWith allows clearing fields', () {
      const mapping = InventoryImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 1,
        skuColumnIndex: 2,
        openingStockColumnIndex: 3,
      );

      final cleared = mapping.copyWith(clearOpeningStock: true);
      expect(cleared.nameColumnIndex, 1);
      expect(cleared.skuColumnIndex, 2);
      expect(cleared.openingStockColumnIndex, isNull);
    });
  });

  group('InventoryImportPreviewRow', () {
    test('isSelectable is true only when status is valid', () {
      const validRow = InventoryImportPreviewRow(
        sourceRowNumber: 2,
        rawValues: ['Item A', 'SKU-001', '10'],
        name: 'Item A',
        sku: 'SKU-001',
        openingStock: 10.0,
        status: InventoryImportRowStatus.valid,
        isSelected: true,
      );
      expect(validRow.isSelectable, isTrue);

      const invalidRow = InventoryImportPreviewRow(
        sourceRowNumber: 3,
        rawValues: ['', 'SKU-002', '10'],
        name: '',
        sku: 'SKU-002',
        openingStock: 10.0,
        status: InventoryImportRowStatus.invalid,
        errorMessage: 'Name is required.',
        isSelected: false,
      );
      expect(invalidRow.isSelectable, isFalse);

      const dupRow = InventoryImportPreviewRow(
        sourceRowNumber: 4,
        rawValues: ['Item C', 'SKU-001', '5'],
        name: 'Item C',
        sku: 'SKU-001',
        openingStock: 5.0,
        status: InventoryImportRowStatus.duplicate,
        errorMessage: 'Duplicate SKU in file.',
        isSelected: false,
      );
      expect(dupRow.isSelectable, isFalse);
    });
  });

  group('InventoryImportPreview', () {
    test('calculates counts correctly', () {
      const preview = InventoryImportPreview(
        rows: [
          InventoryImportPreviewRow(
            sourceRowNumber: 2,
            rawValues: ['A', 'S1'],
            name: 'A',
            sku: 'S1',
            status: InventoryImportRowStatus.valid,
            isSelected: true,
          ),
          InventoryImportPreviewRow(
            sourceRowNumber: 3,
            rawValues: ['B', 'S2'],
            name: 'B',
            sku: 'S2',
            status: InventoryImportRowStatus.valid,
            isSelected: false,
          ),
          InventoryImportPreviewRow(
            sourceRowNumber: 4,
            rawValues: ['', 'S3'],
            name: '',
            sku: 'S3',
            status: InventoryImportRowStatus.invalid,
            errorMessage: 'Name is required.',
            isSelected: false,
          ),
          InventoryImportPreviewRow(
            sourceRowNumber: 5,
            rawValues: ['D', 'S4'],
            name: 'D',
            sku: 'S4',
            status: InventoryImportRowStatus.duplicate,
            errorMessage: 'Duplicate SKU.',
            isSelected: false,
          ),
        ],
      );

      expect(preview.totalRows, 4);
      expect(preview.validCount, 2);
      expect(preview.invalidCount, 1);
      expect(preview.duplicateCount, 1);
      expect(preview.selectedCount, 1);
      expect(preview.selectedRows.length, 1);
      expect(preview.selectedRows.first.sku, 'S1');
    });
  });

  group('InventoryImportResult', () {
    test('stores counts and collections', () {
      const result = InventoryImportResult(
        requestedCount: 4,
        successCount: 3,
        failureCount: 1,
        importedSummaries: [],
        failures: [
          InventoryImportRowFailure(
            sourceRowNumber: 4,
            sku: 'S4',
            reason: 'Failed to persist',
          ),
        ],
      );

      expect(result.requestedCount, 4);
      expect(result.successCount, 3);
      expect(result.failureCount, 1);
      expect(result.failures.length, 1);
    });
  });
}
