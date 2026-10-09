import 'dart:convert';
import 'dart:typed_data';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_import_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_import_state.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_error_report_service.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_file_picker.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_parser.dart';
import 'package:flutter_test/flutter_test.dart';

class _DirectFilePicker implements InventoryImportFilePicker {
  final InventoryImportSelectedFile file;
  const _DirectFilePicker(this.file);

  @override
  Future<InventoryImportSelectedFile?> pickFile({List<String>? allowedExtensions}) async {
    return file;
  }
}

class _FakeParser implements InventoryImportParser {
  final InventoryImportParsedFile parsedFile;
  const _FakeParser(this.parsedFile);

  @override
  Future<InventoryImportParsedFile> parse(InventoryImportSelectedFile file) async {
    return parsedFile;
  }
}

void main() {
  const adminUser = CurrentUser(
    id: 'admin_1',
    displayName: 'Admin User',
    accountType: AccountType.admin,
    modules: {CrmModule.inventory},
    permissions: {
      CrmPermissions.inventoryView,
      'inventory.create',
      'inventory.edit',
      'inventory.import.csv',
      'inventory.import.xlsx',
      'inventory.import.stock',
      'inventory.custom_fields.manage',
    },
  );

  group('Phase 2: CSV & Excel Import Wizard Acceptance Tests', () {
    test('1. 71x21 file extraction and complete detection', () async {
      final headers = List<String>.generate(21, (i) => i == 0 ? 'Product Name' : i == 1 ? 'SKU' : 'Field_$i');
      final dataRows = List<List<String>>.generate(71, (r) {
        return List<String>.generate(21, (c) => c == 0 ? 'Item $r' : c == 1 ? 'SKU-71-$r' : 'Val_${r}_$c');
      });

      final parsedFile = InventoryImportParsedFile(
        fileName: 'dataset_71_21.csv',
        fileType: InventoryImportFileType.csv,
        sheets: [
          InventoryImportParsedSheet(
            name: 'CSV',
            rows: [headers, ...dataRows],
          ),
        ],
      );

      final selectedFile = InventoryImportSelectedFile(
        name: 'dataset_71_21.csv',
        extension: 'csv',
        sizeBytes: 1024,
        bytes: Uint8List(0),
      );

      final repo = MockInventoryRepository();
      final cubit = InventoryImportCubit(
        user: adminUser,
        repository: repo,
        filePicker: _DirectFilePicker(selectedFile),
        parser: _FakeParser(parsedFile),
      );

      await cubit.selectFileAndParse();
      expect(cubit.state, isA<InventoryImportHeaderSelect>());

      cubit.confirmHeaderRow();
      expect(cubit.state, isA<InventoryImportMappingState>());
      final mapState = cubit.state as InventoryImportMappingState;
      expect(mapState.availableColumns.length, 21);

      await cubit.confirmMapping();
      expect(cubit.state, isA<InventoryImportPreviewState>());
      final previewState = cubit.state as InventoryImportPreviewState;

      expect(previewState.preview.totalRows, 71);
      expect(previewState.preview.validCount, 71);
      expect(previewState.preview.selectedCount, 71);
    });

    test('2. 100% blank rows are pruned automatically without inflating totals or failures', () async {
      final headers = ['Product Name', 'SKU', 'Unit Cost'];
      final rowsWithBlanks = [
        headers,
        ['Item 1', 'SKU-B1', '100.00'],
        ['', '', ''],
        ['   ', '\t', '  '],
        ['Item 2', 'SKU-B2', '200.00'],
        ['', '', ''],
      ];

      final parsedFile = InventoryImportParsedFile(
        fileName: 'blanks.csv',
        fileType: InventoryImportFileType.csv,
        sheets: [
          InventoryImportParsedSheet(name: 'CSV', rows: rowsWithBlanks),
        ],
      );

      final selectedFile = InventoryImportSelectedFile(
        name: 'blanks.csv',
        extension: 'csv',
        sizeBytes: 100,
        bytes: Uint8List(0),
      );

      final repo = MockInventoryRepository();
      final cubit = InventoryImportCubit(
        user: adminUser,
        repository: repo,
        filePicker: _DirectFilePicker(selectedFile),
        parser: _FakeParser(parsedFile),
      );

      await cubit.selectFileAndParse();
      cubit.confirmHeaderRow();
      await cubit.confirmMapping();

      final previewState = cubit.state as InventoryImportPreviewState;
      expect(previewState.preview.totalRows, 2);
      expect(previewState.preview.validCount, 2);
      expect(previewState.preview.invalidCount, 0);
    });

    test('3. Unrecognized headers auto-registered as custom fields and persisted to repo', () async {
      final headers = ['Product Name', 'SKU', 'Warranty Period', 'Hex Color'];
      final dataRows = [
        ['Monitor 4K', 'MON-4K', '3 Years', '#0000FF'],
        ['Mechanical Keyboard', 'KEY-RGB', '1 Year', '#FF0000'],
      ];

      final parsedFile = InventoryImportParsedFile(
        fileName: 'custom_cols.csv',
        fileType: InventoryImportFileType.csv,
        sheets: [
          InventoryImportParsedSheet(name: 'CSV', rows: [headers, ...dataRows]),
        ],
      );

      final selectedFile = InventoryImportSelectedFile(
        name: 'custom_cols.csv',
        extension: 'csv',
        sizeBytes: 200,
        bytes: Uint8List(0),
      );

      final repo = MockInventoryRepository();
      final cubit = InventoryImportCubit(
        user: adminUser,
        repository: repo,
        filePicker: _DirectFilePicker(selectedFile),
        parser: _FakeParser(parsedFile),
      );

      await cubit.selectFileAndParse();
      cubit.confirmHeaderRow();

      final mapState = cubit.state as InventoryImportMappingState;
      final staged = mapState.mapping.stagedCustomFieldDefinitions;
      expect(staged.any((d) => d.key == 'warranty_period' && d.label == 'Warranty Period'), isTrue);
      expect(staged.any((d) => d.key == 'hex_color' && d.label == 'Hex Color'), isTrue);

      await cubit.confirmMapping();
      expect(cubit.state, isA<InventoryImportPreviewState>());

      await cubit.executeImport();
      expect(cubit.state, isA<InventoryImportSuccessState>());

      final repoDefs = await repo.getCustomFieldDefinitions();
      expect(repoDefs.any((d) => d.key == 'warranty_period'), isTrue);
      expect(repoDefs.any((d) => d.key == 'hex_color'), isTrue);

      final itemsMap = await repo.getExistingItemsBySku();
      final monitor = itemsMap['mon-4k'];
      expect(monitor?.customFields['warranty_period'], '3 Years');
      expect(monitor?.customFields['hex_color'], '#0000FF');
    });

    test('4. Gallery-Style Selection: nonconsecutive row picks and live counters', () async {
      final headers = ['Product Name', 'SKU'];
      final dataRows = [
        ['Item 1', 'SKU-01'],
        ['Item 2', 'SKU-02'],
        ['Item 3', 'SKU-03'],
        ['Item 4', 'SKU-04'],
      ];

      final parsedFile = InventoryImportParsedFile(
        fileName: 'gallery.csv',
        fileType: InventoryImportFileType.csv,
        sheets: [
          InventoryImportParsedSheet(name: 'CSV', rows: [headers, ...dataRows]),
        ],
      );

      final selectedFile = InventoryImportSelectedFile(
        name: 'gallery.csv',
        extension: 'csv',
        sizeBytes: 150,
        bytes: Uint8List(0),
      );

      final repo = MockInventoryRepository();
      final cubit = InventoryImportCubit(
        user: adminUser,
        repository: repo,
        filePicker: _DirectFilePicker(selectedFile),
        parser: _FakeParser(parsedFile),
      );

      await cubit.selectFileAndParse();
      cubit.confirmHeaderRow();
      await cubit.confirmMapping();

      var previewState = cubit.state as InventoryImportPreviewState;
      expect(previewState.preview.selectedCount, 4);

      cubit.deselectAll();
      previewState = cubit.state as InventoryImportPreviewState;
      expect(previewState.preview.selectedCount, 0);

      cubit.toggleRowSelection(2);
      cubit.toggleRowSelection(4);
      previewState = cubit.state as InventoryImportPreviewState;
      expect(previewState.preview.selectedCount, 2);

      await cubit.executeImport();
      final successState = cubit.state as InventoryImportSuccessState;
      expect(successState.result.createdCount, 2);

      final itemsMap = await repo.getExistingItemsBySku();
      expect(itemsMap.containsKey('sku-01'), isTrue);
      expect(itemsMap.containsKey('sku-02'), isFalse);
      expect(itemsMap.containsKey('sku-03'), isTrue);
      expect(itemsMap.containsKey('sku-04'), isFalse);
    });

    test('5. Stock Ledger Safety: opening stock ledger integrity with zero silent overwrite', () async {
      final headers = ['Product Name', 'SKU', 'Opening Stock'];
      final dataRows = [
        ['New Stock Item', 'STOCK-NEW', '25'],
      ];

      final parsedFile = InventoryImportParsedFile(
        fileName: 'stock.csv',
        fileType: InventoryImportFileType.csv,
        sheets: [
          InventoryImportParsedSheet(name: 'CSV', rows: [headers, ...dataRows]),
        ],
      );

      final selectedFile = InventoryImportSelectedFile(
        name: 'stock.csv',
        extension: 'csv',
        sizeBytes: 120,
        bytes: Uint8List(0),
      );

      final repo = MockInventoryRepository();
      final cubit = InventoryImportCubit(
        user: adminUser,
        repository: repo,
        filePicker: _DirectFilePicker(selectedFile),
        parser: _FakeParser(parsedFile),
      );

      await cubit.selectFileAndParse();
      cubit.confirmHeaderRow();
      await cubit.confirmMapping();
      await cubit.executeImport();

      final page = await repo.getItems(const InventoryQuery());
      final summary = page.items.firstWhere((s) => s.item.sku == 'STOCK-NEW');
      expect(summary.quantityOnHand, 25.0);

      final movements = await repo.getStockMovements(summary.item.id);
      expect(movements.length, 1);
      expect(movements.first.movement.quantityDelta, 25.0);
    });

    test('6. Error Reporting: downloadable row-level CSV error report service', () {
      final failures = [
        const InventoryImportRowFailure(
          sourceRowNumber: 5,
          sku: 'INVALID-SKU',
          reason: 'Item SKU cannot exceed 64 characters.',
        ),
      ];

      const service = InventoryImportErrorReportService();
      final bytes = service.toBytes(failures);
      final errorCsv = utf8.decode(bytes);

      expect(errorCsv, contains('Source Row'));
      expect(errorCsv, contains('SKU'));
      expect(errorCsv, contains('Error'));
      expect(errorCsv, contains('5'));
      expect(errorCsv, contains('INVALID-SKU'));
      expect(errorCsv, contains('Item SKU cannot exceed 64 characters.'));
    });
  });
}
