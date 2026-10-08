import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_parser.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_file_picker.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_preview_builder.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';

void main() {
  const targetWorkbookPath =
      r'C:\Users\vacha\Desktop\inventory_mock_test_data.xlsx';

  group('INVENTORY-7.9 Exact Workbook Zero Opening Stock Regression', () {
    late Uint8List bytes;
    late InventoryImportParsedSheet sheet;

    setUpAll(() async {
      final file = File(targetWorkbookPath);
      expect(file.existsSync(), isTrue, reason: 'Target workbook must exist');
      bytes = await file.readAsBytes();

      final parser = const DefaultInventoryImportParser();
      final parsed = await parser.parse(
        InventoryImportSelectedFile(
          name: 'inventory_mock_test_data.xlsx',
          extension: 'xlsx',
          sizeBytes: bytes.length,
          bytes: bytes,
        ),
      );

      sheet = parsed.sheets.firstWhere((s) => s.name == 'Inventory_Data');
      expect(sheet.rows.length, 73); // 1 header + 72 data rows
    });

    test(
      'stock_quantity mapped to Opening Stock accepts all 72 rows including 8 zero-stock SKUs',
      () async {
        final repo = MockInventoryRepository();
        final initialSkus = await repo.getExistingSkus();
        expect(initialSkus.length, 25); // Clean repository initial state (INV-001..INV-025)

        final headerRow = sheet.rows[0];
        final standardMappings = <int, InventoryImportField>{};
        for (var i = 0; i < headerRow.length; i++) {
          final norm = headerRow[i]
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[\s\-_]+'), '_');
          if (norm == 'sku') standardMappings[i] = InventoryImportField.sku;
          if (norm == 'product_name') {
            standardMappings[i] = InventoryImportField.name;
          }
          if (norm == 'stock_quantity') {
            standardMappings[i] = InventoryImportField.openingStock;
          }
        }

        final mapping = InventoryImportColumnMapping(
          sheetIndex: 0,
          headerRowIndex: 0,
          nameColumnIndex: 1, // product_name
          skuColumnIndex: 0, // sku
          openingStockColumnIndex: 11, // stock_quantity
          standardFieldMappings: standardMappings,
          importMode: InventoryImportMode.createOnly,
        );

        const builder = InventoryImportPreviewBuilder();
        final preview = builder.build(
          sheet: sheet,
          mapping: mapping,
          existingSkus: initialSkus,
          catalogs: repo.catalogs,
        );

        // Verification of preview counts
        expect(preview.totalRows, 72);
        expect(preview.validCount, 72);
        expect(preview.invalidCount, 0);

        const zeroStockSkus = [
          'ELE-0001',
          'ITA-0002',
          'STA-0003',
          'FUR-0004',
          'CLN-0005',
          'PAN-0006',
          'PKG-0007',
          'SFT-0008',
        ];

        // All 8 zero-stock SKUs must be valid with openingStock = 0.0 and selected
        for (final sku in zeroStockSkus) {
          final row = preview.rows.firstWhere((r) => r.sku == sku);
          expect(row.status, InventoryImportRowStatus.valid);
          expect(row.openingStock, 0.0);
          expect(row.isSelected, isTrue);
          expect(row.errorMessage, isNull);
        }

        // Execute repository import
        final importInputs = preview.selectedRows.map((r) {
          return InventoryImportRowInput(
            sourceRowNumber: r.sourceRowNumber,
            name: r.name,
            sku: r.sku,
            openingStock: r.openingStock,
            isUpdate: false,
          );
        }).toList();

        final result = await repo.importItems(
          InventoryImportRequest(
            performedByUserId: 'admin_test',
            rows: importInputs,
            mode: InventoryImportMode.createOnly,
          ),
        );

        expect(result.requestedCount, 72);
        expect(result.successCount, 72);
        expect(result.effectiveCreatedCount, 72);
        expect(result.failureCount, 0);

        final postSkus = await repo.getExistingSkus();
        expect(postSkus.length, 97); // 25 seed records + 72 created

        // Verify each of the 8 zero-stock items in the repository
        final itemsBySku = await repo.getExistingItemsBySku();
        for (final sku in zeroStockSkus) {
          final item = itemsBySku[sku.toLowerCase()];
          expect(item, isNotNull, reason: 'Item $sku must exist in repository');
          final summary = await repo.getItemById(item!.id);
          expect(summary, isNotNull);
          expect(summary!.quantityOnHand, 0.0);

          final movements = await repo.getStockMovements(item.id);
          expect(
            movements.isEmpty,
            isTrue,
            reason: 'Zero opening stock must create NO ledger movements',
          );
        }
      },
    );
  });
}
