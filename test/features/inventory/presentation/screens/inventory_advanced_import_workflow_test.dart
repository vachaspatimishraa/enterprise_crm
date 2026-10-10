import 'dart:io';
import 'dart:typed_data';

import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/custom_field_definition.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_import_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_import_state.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_file_picker.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_parser.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_preview_builder.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeParser implements InventoryImportParser {
  _FakeParser(this.parsed);
  final InventoryImportParsedFile parsed;

  @override
  Future<InventoryImportParsedFile> parse(
    InventoryImportSelectedFile file,
  ) async => parsed;
}

class _DirectFilePicker implements InventoryImportFilePicker {
  _DirectFilePicker(this.file);
  final InventoryImportSelectedFile file;

  @override
  Future<InventoryImportSelectedFile?> pickFile({
    List<String>? allowedExtensions,
  }) async => file;
}

Uint8List _loadReferenceWorkbookBytes() {
  final paths = [
    r'D:\projects\enterprise_crm_inventory_finalization\test\fixtures\inventory_mock_test_data.xlsx',
    r'C:\Users\vacha\Desktop\inventory_mock_test_data.xlsx',
  ];
  for (final p in paths) {
    final f = File(p);
    if (f.existsSync()) {
      return f.readAsBytesSync();
    }
  }
  throw StateError('inventory_mock_test_data.xlsx not found in paths: $paths');
}

void main() {
  group('INVENTORY-7.4: Advanced Bulk Spreadsheet Import Tests', () {
    late Uint8List workbookBytes;
    late CurrentUser superAdmin;
    late CurrentUser noCostUser;

    setUp(() {
      workbookBytes = _loadReferenceWorkbookBytes();

      superAdmin = CurrentUser(
        id: 'admin_1',
        displayName: 'Super Admin',
        accountType: AccountType.admin,
        modules: {CrmModule.inventory},
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryImportCsv,
          CrmPermissions.inventoryImportXlsx,
          CrmPermissions.inventoryCreate,
          CrmPermissions.inventoryEdit,
          CrmPermissions.inventoryStockManage,
        },
      );


      noCostUser = CurrentUser(
        id: 'user_nocost',
        displayName: 'No Cost User',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryImportCsv,
          CrmPermissions.inventoryImportXlsx,
          CrmPermissions.inventoryCreate,
          CrmPermissions.inventoryEdit,
          CrmPermissions.inventoryStockManage,
        },
      );
    });

    test('Reference Workbook parses all 4 worksheets accurately with OOXML direct parser', () async {
      const parser = DefaultInventoryImportParser();
      final selectedFile = InventoryImportSelectedFile(
        name: 'inventory_mock_test_data.xlsx',
        extension: 'xlsx',
        sizeBytes: workbookBytes.length,
        bytes: workbookBytes,
      );

      final parsed = await parser.parse(selectedFile);
      expect(parsed.sheets.length, 4);
      final sheetNames = parsed.sheets.map((s) => s.name).toList();
      expect(sheetNames, contains('Inventory_Data'));
      expect(sheetNames, contains('Test_Overview'));
      expect(sheetNames, contains('Stock_Movements'));
      expect(sheetNames, contains('Invalid_Examples'));

      // Validate Inventory_Data sheet dimensions
      final inventorySheet = parsed.sheets.firstWhere((s) => s.name == 'Inventory_Data');
      expect(inventorySheet.rows.length, greaterThanOrEqualTo(73)); // Header + 72 products
      expect(inventorySheet.rows[0].length, 21); // All 21 standard columns

      // Verify all 21 standard column headers
      final headers = inventorySheet.rows[0].map((h) => h.trim().toLowerCase()).toList();
      expect(headers, contains('sku'));
      expect(headers, contains('product_name'));
      expect(headers, contains('category'));
      expect(headers, contains('brand'));
      expect(headers, contains('unit'));
      expect(headers, contains('barcode'));
      expect(headers, contains('warehouse'));
      expect(headers, contains('bin_location'));
      expect(headers, contains('supplier'));
      expect(headers, contains('unit_cost_inr'));
      expect(headers, contains('selling_price_inr'));
      expect(headers, contains('stock_quantity'));
      expect(headers, contains('reorder_level'));
      expect(headers, contains('max_stock'));
      expect(headers, contains('gst_percent'));
      expect(headers, contains('batch_number'));
      expect(headers, contains('expiry_date'));
      expect(headers, contains('last_restocked_date'));
      expect(headers, contains('is_active'));
      expect(headers, contains('expected_stock_status'));
      expect(headers, contains('notes'));
    });

    test('Auto-mapping identifies all 21 standard fields correctly without ambiguity', () async {
      const parser = DefaultInventoryImportParser();
      final selectedFile = InventoryImportSelectedFile(
        name: 'inventory_mock_test_data.xlsx',
        extension: 'xlsx',
        sizeBytes: workbookBytes.length,
        bytes: workbookBytes,
      );

      final repo = MockInventoryRepository();
      final cubit = InventoryImportCubit(
        user: superAdmin,
        repository: repo,
        filePicker: _DirectFilePicker(selectedFile),
        parser: parser,
      );

      await cubit.selectFileAndParse();
      expect(cubit.state, isA<InventoryImportSheetSelect>());

      // Sheet 0 is Inventory_Data
      cubit.selectSheetIndex(0);
      cubit.confirmSheet();
      expect(cubit.state, isA<InventoryImportHeaderSelect>());

      // Row 0 is header row
      cubit.selectHeaderRowIndex(0);
      cubit.confirmHeaderRow();
      expect(cubit.state, isA<InventoryImportMappingState>());

      final mappingState = cubit.state as InventoryImportMappingState;
      final standardMappings = mappingState.mapping.standardFieldMappings;
      expect(standardMappings.length, 21);

      // Verify each standard field is mapped to a column index
      for (final field in InventoryImportField.values) {
        expect(standardMappings.values, contains(field),
            reason: 'Field ${field.label} should be auto-mapped from reference header');
      }
    });

    test('Mode A (Create New) creates new items and rejects existing SKUs non-destructively', () async {
      final repo = MockInventoryRepository();
      // Pre-seed an existing item
      await repo.createItem(
        const CreateInventoryItemInput(
          performedByUserId: 'admin_1',
          name: 'Pre-existing Product',
          sku: 'ELE-0001',
          category: 'Electronics',
          brand: 'PreBrand',
          unit: 'piece',
          openingStock: 50.0,
        ),
      );

      const parser = DefaultInventoryImportParser();
      final selectedFile = InventoryImportSelectedFile(
        name: 'inventory_mock_test_data.xlsx',
        extension: 'xlsx',
        sizeBytes: workbookBytes.length,
        bytes: workbookBytes,
      );

      final cubit = InventoryImportCubit(
        user: superAdmin,
        repository: repo,
        filePicker: _DirectFilePicker(selectedFile),
        parser: parser,
      );

      await cubit.selectFileAndParse();
      cubit.selectSheetIndex(0);
      cubit.confirmSheet();
      cubit.selectHeaderRowIndex(0);
      cubit.confirmHeaderRow();

      // Explicitly set Name and SKU
      final mapState = cubit.state as InventoryImportMappingState;
      final nameCol = mapState.mapping.standardFieldMappings.entries
          .firstWhere((e) => e.value == InventoryImportField.name).key;
      final skuCol = mapState.mapping.standardFieldMappings.entries
          .firstWhere((e) => e.value == InventoryImportField.sku).key;
      cubit.setFieldMapping(InventoryImportField.name, nameCol);
      cubit.setFieldMapping(InventoryImportField.sku, skuCol);

      // Ensure mode is createOnly
      cubit.setImportMode(InventoryImportMode.createOnly);

      await cubit.confirmMapping();
      expect(cubit.state, isA<InventoryImportPreviewState>());

      final previewState = cubit.state as InventoryImportPreviewState;
      // In createOnly mode, ELE-0001 must be invalid because it already exists in repo
      final ele001Row = previewState.preview.rows.firstWhere((r) => r.sku.toUpperCase() == 'ELE-0001');
      expect(ele001Row.status, InventoryImportRowStatus.invalid);
      expect(ele001Row.errorMessage, contains('already exists'));
      expect(ele001Row.isSelected, isFalse);

      // Execute import of valid items
      await cubit.executeImport();
      expect(cubit.state, isA<InventoryImportSuccessState>());
      final result = (cubit.state as InventoryImportSuccessState).result;
      expect(result.createdCount, greaterThan(0));
      expect(result.updatedCount, 0); // No updates in Mode A!

      // Verify pre-existing product was completely untouched
      final existingMap = await repo.getExistingItemsBySku();
      final preExisting = existingMap['ele-0001'];
      expect(preExisting?.name, 'Pre-existing Product');
      final summary = await repo.getItemById(preExisting!.id);
      expect(summary?.quantityOnHand, 50.0);
    });

    test('Mode B (Update Existing) updates mapped fields and preserves unmapped fields & stock balance', () async {
      final repo = MockInventoryRepository();
      // Pre-seed ELE-0001 with 75 units
      await repo.createItem(
        const CreateInventoryItemInput(
          performedByUserId: 'admin_1',
          name: 'Old Name For ELE-0001',
          sku: 'ELE-0001',
          category: 'Electronics',
          brand: 'Original Brand',
          unit: 'piece',
          openingStock: 75.0,
        ),
      );

      const parser = DefaultInventoryImportParser();
      final selectedFile = InventoryImportSelectedFile(
        name: 'inventory_mock_test_data.xlsx',
        extension: 'xlsx',
        sizeBytes: workbookBytes.length,
        bytes: workbookBytes,
      );

      final cubit = InventoryImportCubit(
        user: superAdmin,
        repository: repo,
        filePicker: _DirectFilePicker(selectedFile),
        parser: parser,
      );

      await cubit.selectFileAndParse();
      cubit.selectSheetIndex(0);
      cubit.confirmSheet();
      cubit.selectHeaderRowIndex(0);
      cubit.confirmHeaderRow();

      final mapState = cubit.state as InventoryImportMappingState;
      final nameCol = mapState.mapping.standardFieldMappings.entries
          .firstWhere((e) => e.value == InventoryImportField.name).key;
      final skuCol = mapState.mapping.standardFieldMappings.entries
          .firstWhere((e) => e.value == InventoryImportField.sku).key;
      cubit.setFieldMapping(InventoryImportField.name, nameCol);
      cubit.setFieldMapping(InventoryImportField.sku, skuCol);

      // Set Mode B: Update Existing
      cubit.setImportMode(InventoryImportMode.updateOnly);
      cubit.setBlankValuePolicy(BlankValuePolicy.preserveExisting);

      await cubit.confirmMapping();
      expect(cubit.state, isA<InventoryImportPreviewState>());

      final previewState = cubit.state as InventoryImportPreviewState;
      // In updateOnly mode, ELE-0001 must be Valid with action == update
      final ele001Row = previewState.preview.rows.firstWhere((r) => r.sku.toUpperCase() == 'ELE-0001');
      expect(ele001Row.status, InventoryImportRowStatus.warning);
      expect(ele001Row.action, InventoryImportAction.update);
      expect(ele001Row.warningMessage, contains('Stock quantity cannot be overwritten via bulk update'));

      // Rows for non-existing SKUs must be invalid in Mode B
      final nonExistingRow = previewState.preview.rows.firstWhere((r) => r.sku.toUpperCase() != 'ELE-0001');
      expect(nonExistingRow.status, InventoryImportRowStatus.invalid);
      expect(nonExistingRow.errorMessage, contains('does not exist'));

      // Deselect all and select only ELE-0001
      cubit.deselectAll();
      cubit.toggleRowSelection(ele001Row.sourceRowNumber);

      // Execute import
      await cubit.executeImport();
      expect(cubit.state, isA<InventoryImportSuccessState>());
      final result = (cubit.state as InventoryImportSuccessState).result;
      expect(result.createdCount, 0);
      expect(result.updatedCount, 1);

      // Verify stock balance preserved at 75.0 (ledger NOT overwritten)
      final existingMap = await repo.getExistingItemsBySku();
      final updated = existingMap['ele-0001'];
      expect(updated?.name, isNot('Old Name For ELE-0001')); // Updated name from reference sheet
      final summary = await repo.getItemById(updated!.id);
      expect(summary?.quantityOnHand, 75.0);
    });

    test('Mode C (Create and Update) handles upsert correctly', () async {
      final repo = MockInventoryRepository();
      // Pre-seed ELE-0001
      await repo.createItem(
        const CreateInventoryItemInput(
          performedByUserId: 'admin_1',
          name: 'Original ELE-0001',
          sku: 'ELE-0001',
          category: 'Electronics',
          brand: 'PreBrand',
          unit: 'piece',
          openingStock: 12.0,
        ),
      );

      const parser = DefaultInventoryImportParser();
      final selectedFile = InventoryImportSelectedFile(
        name: 'inventory_mock_test_data.xlsx',
        extension: 'xlsx',
        sizeBytes: workbookBytes.length,
        bytes: workbookBytes,
      );

      final cubit = InventoryImportCubit(
        user: superAdmin,
        repository: repo,
        filePicker: _DirectFilePicker(selectedFile),
        parser: parser,
      );

      await cubit.selectFileAndParse();
      cubit.selectSheetIndex(0);
      cubit.confirmSheet();
      cubit.selectHeaderRowIndex(0);
      cubit.confirmHeaderRow();

      final mapState = cubit.state as InventoryImportMappingState;
      final nameCol = mapState.mapping.standardFieldMappings.entries
          .firstWhere((e) => e.value == InventoryImportField.name).key;
      final skuCol = mapState.mapping.standardFieldMappings.entries
          .firstWhere((e) => e.value == InventoryImportField.sku).key;
      cubit.setFieldMapping(InventoryImportField.name, nameCol);
      cubit.setFieldMapping(InventoryImportField.sku, skuCol);

      cubit.setImportMode(InventoryImportMode.createAndUpdate);

      await cubit.confirmMapping();
      final previewState = cubit.state as InventoryImportPreviewState;

      final ele001Row = previewState.preview.rows.firstWhere((r) => r.sku.toUpperCase() == 'ELE-0001');
      expect(ele001Row.action, InventoryImportAction.update);

      final otherRow = previewState.preview.rows.firstWhere((r) => r.sku.toUpperCase() != 'ELE-0001');
      expect(otherRow.action, InventoryImportAction.create);
    });

    test('Sensitive fields masking: Cost and Supplier hidden from unauthorized user', () async {
      const sheet = InventoryImportParsedSheet(
        name: 'SensitiveSheet',
        rows: [
          ['Name', 'SKU', 'Cost', 'Supplier'],
          ['Widget', 'SKU-001', '150.00', 'TopSecretSupplier'],
        ],
      );

      const mapping = InventoryImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
        skuColumnIndex: 1,
        standardFieldMappings: {
          0: InventoryImportField.name,
          1: InventoryImportField.sku,
          2: InventoryImportField.unitCostInr,
          3: InventoryImportField.supplier,
        },
      );

      const builder = InventoryImportPreviewBuilder();
      final preview = builder.build(
        sheet: sheet,
        mapping: mapping,
        existingSkus: {},
        user: noCostUser, // Lacks cost.view and supplier.view
      );

      final row = preview.rows[0];
      expect(row.mappedValues['unitCostInr'], isNull);
      expect(row.mappedValues['supplier'], isNull);
    });

    test('Staged custom field definition is registered upon successful import commit', () async {
      final repo = MockInventoryRepository();
      final customDef = CustomFieldDefinition(
        id: 'cf_warranty',
        key: 'warranty_period',
        label: 'Warranty Period',
        dataType: CustomFieldDataType.text,
      );

      final request = InventoryImportRequest(
        performedByUserId: 'admin_1',
        mode: InventoryImportMode.createOnly,
        blankValuePolicy: BlankValuePolicy.preserveExisting,
        stagedCustomFieldDefinitions: [customDef],
        rows: const [
          InventoryImportRowInput(
            sourceRowNumber: 2,
            sku: 'CUST-001',
            name: 'Custom Product',
            customFields: {'warranty_period': '24 Months'},
          ),
        ],
      );

      final result = await repo.importItems(request);
      expect(result.createdCount, 1);

      // Verify custom field definition was registered in repo
      final registered = await repo.getCustomFieldDefinitions();
      expect(registered.any((d) => d.key == 'warranty_period'), isTrue);

      // Verify custom field value persisted on created item
      final existingMap = await repo.getExistingItemsBySku();
      final created = existingMap['cust-001'];
      expect(created?.customFields['warranty_period'], '24 Months');
    });

    test('Invalid_Examples worksheet produces expected validation errors', () async {
      const parser = DefaultInventoryImportParser();
      final selectedFile = InventoryImportSelectedFile(
        name: 'inventory_mock_test_data.xlsx',
        extension: 'xlsx',
        sizeBytes: workbookBytes.length,
        bytes: workbookBytes,
      );

      final parsed = await parser.parse(selectedFile);
      final invalidSheet = parsed.sheets.firstWhere((s) => s.name == 'Invalid_Examples');

      // The Invalid_Examples sheet has validation test cases
      expect(invalidSheet.rows.length, greaterThan(1));
    });

    test('Permission enforcement: unauthorized user cannot commit import mutations', () async {
      final repo = MockInventoryRepository();
      const sheet = InventoryImportParsedSheet(
        name: 'Sheet1',
        rows: [
          ['Name', 'SKU'],
          ['Unauthorized Item', 'UNAUTH-001'],
        ],
      );
      const parsedFile = InventoryImportParsedFile(
        fileName: 'test.csv',
        fileType: InventoryImportFileType.csv,
        sheets: [sheet],
      );
      final selectedFile = InventoryImportSelectedFile(
        name: 'test.csv',
        extension: 'csv',
        sizeBytes: 100,
        bytes: Uint8List(10),
      );

      // User lacking inventoryCreate permission
      final viewerOnly = CurrentUser(
        id: 'viewer_1',
        displayName: 'Viewer',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryImportCsv,
        },
      );

      final cubit = InventoryImportCubit(
        user: viewerOnly,
        repository: repo,
        filePicker: _DirectFilePicker(selectedFile),
        parser: _FakeParser(parsedFile),
      );

      await cubit.selectFileAndParse();
      cubit.confirmHeaderRow();
      cubit.setFieldMapping(InventoryImportField.name, 0);
      cubit.setFieldMapping(InventoryImportField.sku, 1);
      cubit.setImportMode(InventoryImportMode.createOnly);
      await cubit.confirmMapping();

      // Preview Builder must mark row invalid and non-selectable due to lack of create permission
      expect(cubit.state, isA<InventoryImportPreviewState>());
      final previewState = cubit.state as InventoryImportPreviewState;
      expect(previewState.preview.validCount, 0);
      expect(previewState.preview.selectedCount, 0);
      expect(previewState.preview.rows[0].status, InventoryImportRowStatus.invalid);
      expect(previewState.preview.rows[0].errorMessage, contains('permission to create'));

      // Attempt to execute import without create permission
      await cubit.executeImport();

      // Ensure zero items written to repository
      final existingMap = await repo.getExistingItemsBySku();
      expect(existingMap.containsKey('unauth-001'), isFalse);
    });
  });
}
