import 'dart:typed_data';

import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_artifact.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_fields.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_export_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_export_state.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_import_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_import_state.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_import_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_data_loader.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_service.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_file_picker.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFilePicker implements InventoryImportFilePicker {
  InventoryImportSelectedFile? fileToReturn;

  @override
  Future<InventoryImportSelectedFile?> pickFile({
    List<String>? allowedExtensions,
  }) async =>
      fileToReturn;
}

class _FakeParser implements InventoryImportParser {
  InventoryImportParsedFile? parsedToReturn;

  @override
  Future<InventoryImportParsedFile> parse(
    InventoryImportSelectedFile file,
  ) async =>
      parsedToReturn!;
}

void main() {
  group('INVENTORY-8.1: Gallery-Style Import and Export Selection', () {
    late CurrentUser adminUser;
    late MockInventoryRepository repository;
    late _FakeFilePicker fakePicker;
    late _FakeParser fakeParser;
    late InventoryImportCubit importCubit;

    setUp(() {
      adminUser = const CurrentUser(
        id: 'admin_1',
        displayName: 'Admin User',
        accountType: AccountType.admin,
        modules: {CrmModule.inventory},
        permissions: {CrmPermissions.inventoryView},
      );

      repository = MockInventoryRepository();
      fakePicker = _FakeFilePicker();
      fakeParser = _FakeParser();

      importCubit = InventoryImportCubit(
        repository: repository,
        user: adminUser,
        filePicker: fakePicker,
        parser: fakeParser,
      );
    });

    tearDown(() {
      importCubit.close();
    });

    test('auto-mapped Name and SKU can proceed to preview', () async {
      fakePicker.fileToReturn = InventoryImportSelectedFile(
        name: 'items.csv',
        extension: 'csv',
        sizeBytes: 1,
        bytes: Uint8List(1),
      );
      fakeParser.parsedToReturn = const InventoryImportParsedFile(
        fileName: 'items.csv',
        fileType: InventoryImportFileType.csv,
        sheets: [
          InventoryImportParsedSheet(
            name: 'Items',
            rows: [
              ['Product Name', 'SKU', 'Category'],
              ['Sample', 'SAMPLE-1', 'Electronics'],
            ],
          ),
        ],
      );

      await importCubit.pickAndParseFile();
      importCubit.confirmHeaderRow();
      final mapping = (importCubit.state as InventoryImportMappingState).mapping;
      expect(mapping.nameColumnIndex, 0);
      expect(mapping.skuColumnIndex, 1);
      await importCubit.confirmMapping();
      expect(importCubit.state, isA<InventoryImportPreviewState>());
    });

    test('1. Select All simultaneously selects all eligible rows and all authorized columns', () async {
      fakePicker.fileToReturn = InventoryImportSelectedFile(
        name: 'items.xlsx',
        extension: 'xlsx',
        sizeBytes: 100,
        bytes: Uint8List(10),
      );
      fakeParser.parsedToReturn = const InventoryImportParsedFile(
        fileName: 'items.xlsx',
        fileType: InventoryImportFileType.xlsx,
        sheets: [
          InventoryImportParsedSheet(
            name: 'Master',
            rows: [
              ['Item Name', 'SKU', 'Category', 'Brand'],
              ['Product A', 'SKU-A', 'Electronics', 'TestBrand 1'],
              ['Product B', 'SKU-B', 'Electronics', 'TestBrand 2'],
              ['Product C', 'SKU-C', 'Electronics', 'TestBrand 3'],
            ],
          ),
        ],
      );

      await importCubit.selectFileAndParse();
      importCubit.confirmSheet();
      importCubit.confirmHeaderRow();

      importCubit.setFieldMapping(InventoryImportField.name, 0);
      importCubit.setFieldMapping(InventoryImportField.sku, 1);
      importCubit.setFieldMapping(InventoryImportField.category, 2);
      importCubit.setFieldMapping(InventoryImportField.brand, 3);
      await importCubit.confirmMapping();

      expect(importCubit.state, isA<InventoryImportPreviewState>());

      // Select All action
      importCubit.selectAll();
      final afterSelectAll = importCubit.state as InventoryImportPreviewState;

      expect(afterSelectAll.preview.selectedRows.length, 3);
      expect(afterSelectAll.selectedColumnKeys.contains('name'), isTrue);
      expect(afterSelectAll.selectedColumnKeys.contains('sku'), isTrue);
      expect(afterSelectAll.selectedColumnKeys.contains('category'), isTrue);
      expect(afterSelectAll.selectedColumnKeys.contains('brand'), isTrue);
    });

    test('2 & 3. Import only selected single row or nonconsecutive rows', () async {
      fakePicker.fileToReturn = InventoryImportSelectedFile(
        name: 'items.xlsx',
        extension: 'xlsx',
        sizeBytes: 100,
        bytes: Uint8List(10),
      );
      fakeParser.parsedToReturn = const InventoryImportParsedFile(
        fileName: 'items.xlsx',
        fileType: InventoryImportFileType.xlsx,
        sheets: [
          InventoryImportParsedSheet(
            name: 'Master',
            rows: [
              ['Item Name', 'SKU', 'Category'],
              ['Product 1', 'SKU-1', 'Electronics'],
              ['Product 2', 'SKU-2', 'Electronics'],
              ['Product 3', 'SKU-3', 'Electronics'],
            ],
          ),
        ],
      );

      await importCubit.selectFileAndParse();
      importCubit.confirmSheet();
      importCubit.confirmHeaderRow();
      importCubit.setFieldMapping(InventoryImportField.name, 0);
      importCubit.setFieldMapping(InventoryImportField.sku, 1);
      importCubit.setFieldMapping(InventoryImportField.category, 2);
      await importCubit.confirmMapping();

      // Deselect all rows
      importCubit.deselectAllRows();
      var state = importCubit.state as InventoryImportPreviewState;
      expect(state.preview.selectedRows.length, 0);

      // Select nonconsecutive rows: row 1 and row 3 (sourceRowNumbers 2 and 4)
      importCubit.toggleRowSelection(2);
      importCubit.toggleRowSelection(4);

      state = importCubit.state as InventoryImportPreviewState;
      expect(state.preview.selectedRows.length, 2);
      expect(state.preview.selectedRows.map((r) => r.sourceRowNumber), [2, 4]);

      // Execute import
      await importCubit.executeImport();
      expect(importCubit.state, isA<InventoryImportSuccessState>());
      final success = importCubit.state as InventoryImportSuccessState;
      expect(success.result.successCount, 2);

      final itemsMap = await repository.getExistingItemsBySku();
      expect(itemsMap['sku-1'], isNotNull);
      expect(itemsMap['sku-2'], isNull); // Row 2 was not selected and was NOT imported
      expect(itemsMap['sku-3'], isNotNull);
    });

    test('4, 7 & 8. Deselecting optional column omits it; Name & SKU cannot be deselected', () async {
      fakePicker.fileToReturn = InventoryImportSelectedFile(
        name: 'items.xlsx',
        extension: 'xlsx',
        sizeBytes: 100,
        bytes: Uint8List(10),
      );
      fakeParser.parsedToReturn = const InventoryImportParsedFile(
        fileName: 'items.xlsx',
        fileType: InventoryImportFileType.xlsx,
        sheets: [
          InventoryImportParsedSheet(
            name: 'Master',
            rows: [
              ['Item Name', 'SKU', 'Category', 'Brand'],
              ['Product Alpha', 'SKU-ALPHA', 'Electronics', 'TopBrand'],
            ],
          ),
        ],
      );

      await importCubit.selectFileAndParse();
      importCubit.confirmSheet();
      importCubit.confirmHeaderRow();
      importCubit.setFieldMapping(InventoryImportField.name, 0);
      importCubit.setFieldMapping(InventoryImportField.sku, 1);
      importCubit.setFieldMapping(InventoryImportField.category, 2);
      importCubit.setFieldMapping(InventoryImportField.brand, 3);
      await importCubit.confirmMapping();

      // Mandatory protection: toggling name or sku does not remove them
      importCubit.toggleColumnSelection('name');
      importCubit.toggleColumnSelection('sku');
      var state = importCubit.state as InventoryImportPreviewState;
      expect(state.selectedColumnKeys.contains('name'), isTrue);
      expect(state.selectedColumnKeys.contains('sku'), isTrue);

      // Deselect brand column
      importCubit.toggleColumnSelection('brand');
      state = importCubit.state as InventoryImportPreviewState;
      expect(state.selectedColumnKeys.contains('brand'), isFalse);
      expect(state.selectedColumnKeys.contains('category'), isTrue);

      await importCubit.executeImport();
      final itemsMap = await repository.getExistingItemsBySku();
      final item = itemsMap['sku-alpha'];
      expect(item, isNotNull);
      expect(item!.category, 'Electronics');
      expect(item.brand, isEmpty); // Deselected column was NOT imported
    });

    test('9 & 10. Export selected scope: exports only selected items and selected columns', () async {
      final emptyRepo = MockInventoryRepository(items: []);
      // Seed 5 items into repository
      for (int i = 1; i <= 5; i++) {
        await emptyRepo.createItem(
          CreateInventoryItemInput(
            name: 'Item $i',
            sku: 'SKU-00$i',
            category: 'Electronics',
            unitCostInr: 100.0 * i,
            sellingPriceInr: 150.0 * i,
          ),
        );
      }

      final allItems = await emptyRepo.getItems(const InventoryQuery());
      expect(allItems.totalItems, 5);

      final selected3Ids = {
        allItems.items[0].item.id,
        allItems.items[1].item.id,
        allItems.items[3].item.id,
      };

      final dataLoader = InventoryExportDataLoader(emptyRepo);
      final exportService = InventoryExportService(dataLoader: dataLoader);
      final exportCubit = InventoryExportCubit(
        exportService: exportService,
        currentUser: adminUser,
      );

      // 9. Export only 3 selected items with 4 selected columns
      await exportCubit.export(
        InventoryExportFormat.csv,
        scope: InventoryExportScope.selected,
        preset: InventoryExportPreset.custom,
        columns: ['name', 'sku', 'category', 'selling_price_inr'],
        selectedItemIds: selected3Ids,
      );

      expect(exportCubit.state, isA<InventoryExportPrepared>());
      final preparedCsv = exportCubit.state as InventoryExportPrepared;
      final csvText = String.fromCharCodes(preparedCsv.artifact.bytes);
      final csvLines = csvText.trim().split('\n');

      // 1 header + 3 data rows
      expect(csvLines.length, 4);
      expect(csvLines[0], contains('Product Name'));
      expect(csvLines[0], contains('SKU'));
      expect(csvLines[0], contains('Category'));
      expect(csvLines[0], contains('Selling Price'));
      expect(csvLines[0], isNot(contains('Unit Cost')));

      // 10. Export all records to XLSX and PDF
      await exportCubit.export(
        InventoryExportFormat.xlsx,
        scope: InventoryExportScope.all,
        preset: InventoryExportPreset.custom,
        columns: ['name', 'sku', 'category'],
      );
      expect(exportCubit.state, isA<InventoryExportPrepared>());
      final preparedXlsx = exportCubit.state as InventoryExportPrepared;
      expect(preparedXlsx.artifact.format, InventoryExportFormat.xlsx);
      expect(preparedXlsx.artifact.bytes.length, greaterThan(100));

      await exportCubit.export(
        InventoryExportFormat.pdf,
        scope: InventoryExportScope.all,
        preset: InventoryExportPreset.legacyThreeColumn,
        columns: InventoryExportFields.legacyHeaders,
      );
      expect(exportCubit.state, isA<InventoryExportPrepared>());
      final preparedPdf = exportCubit.state as InventoryExportPrepared;
      expect(preparedPdf.artifact.format, InventoryExportFormat.pdf);
      expect(preparedPdf.artifact.bytes.length, greaterThan(100));

      exportCubit.close();
    });

    test('11. Selection remains stable independent of filter views', () async {
      fakePicker.fileToReturn = InventoryImportSelectedFile(
        name: 'items.xlsx',
        extension: 'xlsx',
        sizeBytes: 100,
        bytes: Uint8List(10),
      );
      fakeParser.parsedToReturn = const InventoryImportParsedFile(
        fileName: 'items.xlsx',
        fileType: InventoryImportFileType.xlsx,
        sheets: [
          InventoryImportParsedSheet(
            name: 'Master',
            rows: [
              ['Item Name', 'SKU', 'Category'],
              ['Product 1', 'SKU-1', 'Electronics'],
              ['Product 2', 'SKU-2', 'Electronics'],
            ],
          ),
        ],
      );

      await importCubit.selectFileAndParse();
      importCubit.confirmSheet();
      importCubit.confirmHeaderRow();
      importCubit.setFieldMapping(InventoryImportField.name, 0);
      importCubit.setFieldMapping(InventoryImportField.sku, 1);
      importCubit.setFieldMapping(InventoryImportField.category, 2);
      await importCubit.confirmMapping();

      // Filter changed to 'valid' and then 'errors'
      importCubit.setPreviewFilter('valid');
      var state = importCubit.state as InventoryImportPreviewState;
      expect(state.preview.selectedRows.length, 2);

      importCubit.setPreviewFilter('errors');
      state = importCubit.state as InventoryImportPreviewState;
      expect(state.preview.selectedRows.length, 2);

      importCubit.setPreviewFilter('all');
      state = importCubit.state as InventoryImportPreviewState;
      expect(state.preview.selectedRows.length, 2);
    });

    test('12. Unauthorized fields cannot be selected in import', () async {
      final nonCostUser = const CurrentUser(
        id: 'staff_1',
        displayName: 'Staff User',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryImportXlsx,
        },
      );

      final restrictedCubit = InventoryImportCubit(
        repository: repository,
        user: nonCostUser,
        filePicker: fakePicker,
        parser: fakeParser,
      );

      fakePicker.fileToReturn = InventoryImportSelectedFile(
        name: 'items.xlsx',
        extension: 'xlsx',
        sizeBytes: 100,
        bytes: Uint8List(10),
      );
      fakeParser.parsedToReturn = const InventoryImportParsedFile(
        fileName: 'items.xlsx',
        fileType: InventoryImportFileType.xlsx,
        sheets: [
          InventoryImportParsedSheet(
            name: 'Master',
            rows: [
              ['Item Name', 'SKU', 'Category', 'Unit Cost'],
              ['Product 1', 'SKU-1', 'Electronics', '50.0'],
            ],
          ),
        ],
      );

      await restrictedCubit.selectFileAndParse();
      restrictedCubit.confirmSheet();
      restrictedCubit.confirmHeaderRow();
      restrictedCubit.setFieldMapping(InventoryImportField.name, 0);
      restrictedCubit.setFieldMapping(InventoryImportField.sku, 1);
      restrictedCubit.setFieldMapping(InventoryImportField.category, 2);
      await restrictedCubit.confirmMapping();

      restrictedCubit.selectAllColumns();
      final previewState = restrictedCubit.state as InventoryImportPreviewState;

      // unitCostInr must NOT be in selected columns for unauthorized user
      expect(previewState.selectedColumnKeys.contains('unit_cost_inr'), isFalse);
      restrictedCubit.close();
    });

    testWidgets('13 & 14. Import screen renders gallery-style selection bar and controls', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakePicker.fileToReturn = InventoryImportSelectedFile(
        name: 'items.xlsx',
        extension: 'xlsx',
        sizeBytes: 100,
        bytes: Uint8List(10),
      );
      fakeParser.parsedToReturn = const InventoryImportParsedFile(
        fileName: 'items.xlsx',
        fileType: InventoryImportFileType.xlsx,
        sheets: [
          InventoryImportParsedSheet(
            name: 'Master',
            rows: [
              ['Item Name', 'SKU', 'Category'],
              ['Product 1', 'SKU-1', 'Electronics'],
              ['Product 2', 'SKU-2', 'Electronics'],
            ],
          ),
        ],
      );

      await importCubit.selectFileAndParse();
      importCubit.confirmSheet();
      importCubit.confirmHeaderRow();
      importCubit.setFieldMapping(InventoryImportField.name, 0);
      importCubit.setFieldMapping(InventoryImportField.sku, 1);
      importCubit.setFieldMapping(InventoryImportField.category, 2);
      await importCubit.confirmMapping();

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryImportScreen(
            user: adminUser,
            repository: repository,
            cubit: importCubit,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Prominent Select All and Clear Selection buttons
      expect(find.byKey(const Key('inventory_import_select_all_btn')), findsOneWidget);
      expect(find.byKey(const Key('inventory_import_clear_selection_btn')), findsOneWidget);

      // Live selection counters
      expect(find.byKey(const Key('inventory_import_selected_rows_chip')), findsOneWidget);
      expect(find.byKey(const Key('inventory_import_selected_cols_chip')), findsOneWidget);

      // Row select all and column select all
      expect(find.byKey(const Key('inventory_import_select_all_rows_btn')), findsOneWidget);
      expect(find.byKey(const Key('inventory_import_select_all_cols_btn')), findsOneWidget);
      expect(find.byKey(const Key('inventory_import_deselect_optional_cols_btn')), findsOneWidget);

      // Top-left header checkbox
      expect(find.byKey(const Key('inventory_import_select_all_rows_checkbox')), findsOneWidget);

      // Individual row checkboxes
      expect(find.byKey(const Key('inventory_import_row_check_2')), findsOneWidget);
      expect(find.byKey(const Key('inventory_import_row_check_3')), findsOneWidget);

      // Individual column checkboxes in header
      expect(find.byKey(const Key('inventory_import_col_check_name')), findsOneWidget);
      expect(find.byKey(const Key('inventory_import_col_check_sku')), findsOneWidget);
      expect(find.byKey(const Key('inventory_import_col_check_category')), findsOneWidget);

      // Tap Clear Selection
      await tester.tap(find.byKey(const Key('inventory_import_clear_selection_btn')));
      await tester.pumpAndSettle();

      final clearState = importCubit.state as InventoryImportPreviewState;
      expect(clearState.preview.selectedRows.length, 0);
      expect(clearState.selectedColumnKeys, {'name', 'sku'}); // Mandatory retained

      // Tap Select All
      await tester.tap(find.byKey(const Key('inventory_import_select_all_btn')));
      await tester.pumpAndSettle();

      final selectAllState = importCubit.state as InventoryImportPreviewState;
      expect(selectAllState.preview.selectedRows.length, 2);
      expect(selectAllState.selectedColumnKeys.contains('category'), isTrue);
    });
  });
}
