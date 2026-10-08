import 'dart:io';
import 'dart:typed_data';

import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_import_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_import_state.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockFilePicker implements InventoryImportFilePicker {
  final InventoryImportSelectedFile file;
  _MockFilePicker(this.file);

  @override
  Future<InventoryImportSelectedFile?> pickFile({
    List<String>? allowedExtensions,
  }) async {
    return file;
  }
}

void main() {
  const targetWorkbookPath =
      r'C:\Users\vacha\Desktop\inventory_mock_test_data.xlsx';

  group('INVENTORY-7.9 Full Cubit Import Workflow with stock_quantity mapped', () {
    late Uint8List bytes;

    setUpAll(() async {
      final file = File(targetWorkbookPath);
      bytes = await file.readAsBytes();
    });

    test('Full Cubit workflow imports 72 items with 0 errors and creates all 72 items', () async {
      final repo = MockInventoryRepository();
      final adminUser = CurrentUser(
        id: 'admin_1',
        displayName: 'Admin User',
        accountType: AccountType.admin,
        modules: {CrmModule.inventory},
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryCreate,
          CrmPermissions.inventoryEdit,
          CrmPermissions.inventoryStockManage,
        },
      );

      final selectedFile = InventoryImportSelectedFile(
        name: 'inventory_mock_test_data.xlsx',
        extension: 'xlsx',
        sizeBytes: bytes.length,
        bytes: bytes,
      );

      final cubit = InventoryImportCubit(
        repository: repo,
        user: adminUser,
        filePicker: _MockFilePicker(selectedFile),
      );

      // 1. Select and parse file
      await cubit.selectFileAndParse();
      expect(cubit.state, isA<InventoryImportSheetSelect>());

      // 2. Select sheet 0 ('Inventory_Data') and confirm
      cubit.selectSheetIndex(0);
      cubit.confirmSheet();
      expect(cubit.state, isA<InventoryImportHeaderSelect>());

      // 3. Confirm header row (row 0)
      cubit.confirmHeaderRow();
      expect(cubit.state, isA<InventoryImportMappingState>());

      // 4. Set import mode to createOnly and map columns
      cubit.setImportMode(InventoryImportMode.createOnly);
      cubit.setFieldMapping(InventoryImportField.name, 1);
      cubit.setFieldMapping(InventoryImportField.sku, 0);
      cubit.setFieldMapping(InventoryImportField.openingStock, 11);

      // Verify openingStock is mapped to Col 11
      final mappingState = cubit.state as InventoryImportMappingState;
      expect(
        mappingState.mapping.getColumnFor(InventoryImportField.openingStock),
        11,
      );

      // 5. Confirm mapping -> Builds Preview
      await cubit.confirmMapping();
      expect(cubit.state, isA<InventoryImportPreviewState>());
      final previewState = cubit.state as InventoryImportPreviewState;
      expect(previewState.preview.totalRows, 72);
      expect(previewState.preview.validCount, 72);
      expect(previewState.preview.invalidCount, 0);
      expect(previewState.preview.selectedCount, 72);

      // 6. Execute Import
      await cubit.executeImport();
      expect(cubit.state, isA<InventoryImportSuccessState>());
      final successState = cubit.state as InventoryImportSuccessState;
      expect(successState.result.requestedCount, 72);
      expect(successState.result.successCount, 72);
      expect(successState.result.effectiveCreatedCount, 72);
      expect(successState.result.failureCount, 0);

      // 7. Verify post-import repository items (25 seed + 72 created = 97)
      final existingSkus = await repo.getExistingSkus();
      expect(existingSkus.length, 97);

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
      final itemsBySku = await repo.getExistingItemsBySku();
      for (final sku in zeroStockSkus) {
        expect(itemsBySku.containsKey(sku.toLowerCase()), isTrue);
        final item = itemsBySku[sku.toLowerCase()]!;
        final summary = await repo.getItemById(item.id);
        expect(summary!.quantityOnHand, 0.0);

        final movements = await repo.getStockMovements(item.id);
        expect(movements.isEmpty, isTrue);
      }
    });
  });
}
