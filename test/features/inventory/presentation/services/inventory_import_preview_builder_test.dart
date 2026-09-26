import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_parser.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_preview_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryImportPreviewBuilder', () {
    const builder = InventoryImportPreviewBuilder();
    const mapping = InventoryImportColumnMapping(
      sheetIndex: 0,
      headerRowIndex: 0,
      nameColumnIndex: 0,
      skuColumnIndex: 1,
      openingStockColumnIndex: 2,
    );

    test('ignores completely blank rows', () {
      const sheet = InventoryImportParsedSheet(
        name: 'Sheet1',
        rows: [
          ['Name', 'SKU', 'Stock'],
          ['Widget A', 'SKU-001', '10'],
          ['', '  ', ''], // Completely blank
          ['Widget B', 'SKU-002', ''],
          ['  ', '', '   '], // Completely blank
        ],
      );

      final preview = builder.build(
        sheet: sheet,
        mapping: mapping,
        existingSkus: {},
      );

      expect(preview.totalRows, 2);
      expect(preview.validCount, 2);
      expect(preview.rows[0].name, 'Widget A');
      expect(preview.rows[1].name, 'Widget B');
    });

    test('validates required name and sku', () {
      const sheet = InventoryImportParsedSheet(
        name: 'Sheet1',
        rows: [
          ['Name', 'SKU', 'Stock'],
          ['', 'SKU-001', '10'], // Blank name
          ['Widget B', '   ', '10'], // Blank sku
        ],
      );

      final preview = builder.build(
        sheet: sheet,
        mapping: mapping,
        existingSkus: {},
      );

      expect(preview.totalRows, 2);
      expect(preview.validCount, 0);
      expect(preview.invalidCount, 2);
      expect(preview.rows[0].errorMessage, 'Name is required.');
      expect(preview.rows[0].isSelected, isFalse);
      expect(preview.rows[1].errorMessage, 'SKU is required.');
      expect(preview.rows[1].isSelected, isFalse);
    });

    test(
      'handles optional opening stock: blank, valid, non-numeric, zero, negative',
      () {
        const sheet = InventoryImportParsedSheet(
          name: 'Sheet1',
          rows: [
            ['Name', 'SKU', 'Stock'],
            ['A', 'S1', ''], // blank -> valid, null
            ['B', 'S2', '25.5'], // valid number
            ['C', 'S3', 'abc'], // non-numeric
            ['D', 'S4', '0'], // zero
            ['E', 'S5', '-10'], // negative
          ],
        );

        final preview = builder.build(
          sheet: sheet,
          mapping: mapping,
          existingSkus: {},
        );

        expect(preview.totalRows, 5);
        expect(preview.validCount, 2);

        // Row A
        expect(preview.rows[0].status, InventoryImportRowStatus.valid);
        expect(preview.rows[0].openingStock, isNull);
        expect(preview.rows[0].isSelected, isTrue);

        // Row B
        expect(preview.rows[1].status, InventoryImportRowStatus.valid);
        expect(preview.rows[1].openingStock, 25.5);
        expect(preview.rows[1].isSelected, isTrue);

        // Row C
        expect(preview.rows[2].status, InventoryImportRowStatus.invalid);
        expect(
          preview.rows[2].errorMessage,
          'Opening stock must be a valid number.',
        );
        expect(preview.rows[2].isSelected, isFalse);

        // Row D
        expect(preview.rows[3].status, InventoryImportRowStatus.invalid);
        expect(
          preview.rows[3].errorMessage,
          'Opening stock must be greater than zero.',
        );
        expect(preview.rows[3].isSelected, isFalse);

        // Row E
        expect(preview.rows[4].status, InventoryImportRowStatus.invalid);
        expect(
          preview.rows[4].errorMessage,
          'Opening stock must be greater than zero.',
        );
        expect(preview.rows[4].isSelected, isFalse);
      },
    );

    test('marks row invalid if SKU already exists in repository', () {
      const sheet = InventoryImportParsedSheet(
        name: 'Sheet1',
        rows: [
          ['Name', 'SKU', 'Stock'],
          ['Widget', 'INV-001', '10'],
        ],
      );

      final preview = builder.build(
        sheet: sheet,
        mapping: mapping,
        existingSkus: {'inv-001'},
      );

      expect(preview.totalRows, 1);
      expect(preview.validCount, 0);
      expect(preview.invalidCount, 1);
      expect(preview.rows[0].status, InventoryImportRowStatus.invalid);
      expect(
        preview.rows[0].errorMessage,
        'An inventory item with this SKU already exists.',
      );
      expect(preview.rows[0].isSelected, isFalse);
    });

    test(
      'same-file duplicate SKU rule: ALL occurrences marked duplicate and non-selectable',
      () {
        const sheet = InventoryImportParsedSheet(
          name: 'Sheet1',
          rows: [
            ['Name', 'SKU', 'Stock'],
            ['Item 1', 'DUP-001', '10'], // row 2
            ['Item 2', 'dup-001', '20'], // row 3 - case insensitive match
            ['Item 3', 'UNIQUE-001', '30'], // row 4 - unique
          ],
        );

        final preview = builder.build(
          sheet: sheet,
          mapping: mapping,
          existingSkus: {},
        );

        expect(preview.totalRows, 3);
        expect(preview.validCount, 1);
        expect(preview.duplicateCount, 2);

        // BOTH duplicates rejected
        expect(preview.rows[0].status, InventoryImportRowStatus.duplicate);
        expect(preview.rows[0].errorMessage, 'Duplicate SKU in file.');
        expect(preview.rows[0].isSelected, isFalse);

        expect(preview.rows[1].status, InventoryImportRowStatus.duplicate);
        expect(preview.rows[1].errorMessage, 'Duplicate SKU in file.');
        expect(preview.rows[1].isSelected, isFalse);

        // Unique row is valid
        expect(preview.rows[2].status, InventoryImportRowStatus.valid);
        expect(preview.rows[2].isSelected, isTrue);
      },
    );
  });
}
