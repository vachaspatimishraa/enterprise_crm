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
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_parser.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFilePicker implements InventoryImportFilePicker {
  InventoryImportSelectedFile? fileToReturn;
  Object? errorToThrow;

  @override
  Future<InventoryImportSelectedFile?> pickFile() async {
    if (errorToThrow != null) throw errorToThrow!;
    return fileToReturn;
  }
}

class _FakeParser implements InventoryImportParser {
  InventoryImportParsedFile? parsedToReturn;
  Object? errorToThrow;

  @override
  Future<InventoryImportParsedFile> parse(
    InventoryImportSelectedFile file,
  ) async {
    if (errorToThrow != null) throw errorToThrow!;
    return parsedToReturn!;
  }
}

void main() {
  group('InventoryImportCubit', () {
    late CurrentUser adminUser;
    late MockInventoryRepository repository;
    late _FakeFilePicker fakePicker;
    late _FakeParser fakeParser;
    late InventoryImportCubit cubit;

    setUp(() {
      adminUser = CurrentUser(
        id: 'admin_1',
        displayName: 'Admin User',
        accountType: AccountType.admin,
        modules: {CrmModule.inventory},
        permissions: {CrmPermissions.inventoryView},
      );
      repository = MockInventoryRepository();
      fakePicker = _FakeFilePicker();
      fakeParser = _FakeParser();
      cubit = InventoryImportCubit(
        user: adminUser,
        repository: repository,
        filePicker: fakePicker,
        parser: fakeParser,
      );
    });

    test('initial state is InventoryImportInitial', () {
      expect(cubit.state, isA<InventoryImportInitial>());
    });

    test(
      'selectFileAndParse: user cancels picker -> remains in current state',
      () async {
        fakePicker.fileToReturn = null;
        await cubit.selectFileAndParse();
        expect(cubit.state, isA<InventoryImportInitial>());
      },
    );

    test(
      'selectFileAndParse: picker error -> emits InventoryImportErrorState',
      () async {
        fakePicker.errorToThrow = Exception('Picker failed');
        await cubit.selectFileAndParse();
        expect(cubit.state, isA<InventoryImportErrorState>());
      },
    );

    test(
      'selectFileAndParse: single sheet CSV -> transitions to InventoryImportHeaderSelect',
      () async {
        fakePicker.fileToReturn = InventoryImportSelectedFile(
          name: 'test.csv',
          extension: 'csv',
          sizeBytes: 100,
          bytes: Uint8List(10),
        );
        fakeParser.parsedToReturn = const InventoryImportParsedFile(
          fileName: 'test.csv',
          fileType: InventoryImportFileType.csv,
          sheets: [
            InventoryImportParsedSheet(
              name: 'CSV',
              rows: [
                ['Name', 'SKU', 'Stock'],
                ['Widget A', 'SKU-001', '10'],
              ],
            ),
          ],
        );

        await cubit.selectFileAndParse();
        expect(cubit.state, isA<InventoryImportHeaderSelect>());
        final headerState = cubit.state as InventoryImportHeaderSelect;
        expect(headerState.sheetIndex, 0);
        expect(headerState.selectedHeaderRowIndex, 0);
      },
    );

    test(
      'selectFileAndParse: multi-sheet XLSX -> transitions to InventoryImportSheetSelect',
      () async {
        fakePicker.fileToReturn = InventoryImportSelectedFile(
          name: 'test.xlsx',
          extension: 'xlsx',
          sizeBytes: 100,
          bytes: Uint8List(10),
        );
        fakeParser.parsedToReturn = const InventoryImportParsedFile(
          fileName: 'test.xlsx',
          fileType: InventoryImportFileType.xlsx,
          sheets: [
            InventoryImportParsedSheet(name: 'Sheet 1', rows: []),
            InventoryImportParsedSheet(name: 'Sheet 2', rows: []),
          ],
        );

        await cubit.selectFileAndParse();
        expect(cubit.state, isA<InventoryImportSheetSelect>());
        final sheetState = cubit.state as InventoryImportSheetSelect;
        expect(sheetState.file.sheets.length, 2);

        cubit.selectSheetIndex(1);
        expect(
          (cubit.state as InventoryImportSheetSelect).selectedSheetIndex,
          1,
        );

        cubit.confirmSheet();
        expect(cubit.state, isA<InventoryImportHeaderSelect>());
        expect((cubit.state as InventoryImportHeaderSelect).sheetIndex, 1);
      },
    );

    test('header selection and column mapping workflow', () async {
      fakePicker.fileToReturn = InventoryImportSelectedFile(
        name: 'test.csv',
        extension: 'csv',
        sizeBytes: 100,
        bytes: Uint8List(10),
      );
      fakeParser.parsedToReturn = const InventoryImportParsedFile(
        fileName: 'test.csv',
        fileType: InventoryImportFileType.csv,
        sheets: [
          InventoryImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Item Name', 'Item SKU', 'Opening Qty'],
              ['Widget A', 'SKU-001', '10'],
            ],
          ),
        ],
      );

      await cubit.selectFileAndParse();
      cubit.confirmHeaderRow();

      expect(cubit.state, isA<InventoryImportMappingState>());
      var mappingState = cubit.state as InventoryImportMappingState;
      expect(mappingState.availableColumns.length, 3);
      expect(mappingState.mapping.isValid, isFalse);

      // Try confirming mapping before required fields are set
      await cubit.confirmMapping();
      mappingState = cubit.state as InventoryImportMappingState;
      expect(
        mappingState.validationError,
        'Please map both Name and SKU columns.',
      );

      // Map columns
      cubit.setFieldMapping(InventoryImportField.name, 0);
      cubit.setFieldMapping(InventoryImportField.sku, 1);
      cubit.setFieldMapping(InventoryImportField.openingStock, 2);

      mappingState = cubit.state as InventoryImportMappingState;
      expect(mappingState.mapping.isValid, isTrue);
      expect(mappingState.validationError, isNull);

      // Confirm mapping -> transitions to Preview
      await cubit.confirmMapping();
      expect(cubit.state, isA<InventoryImportPreviewState>());
      final previewState = cubit.state as InventoryImportPreviewState;
      expect(previewState.preview.validCount, 1);
      expect(previewState.preview.selectedCount, 1);
    });

    test('row selection toggles and executeImport', () async {
      fakePicker.fileToReturn = InventoryImportSelectedFile(
        name: 'test.csv',
        extension: 'csv',
        sizeBytes: 100,
        bytes: Uint8List(10),
      );
      fakeParser.parsedToReturn = const InventoryImportParsedFile(
        fileName: 'test.csv',
        fileType: InventoryImportFileType.csv,
        sheets: [
          InventoryImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Name', 'SKU', 'Stock'],
              ['Widget A', 'SKU-001', '10'],
            ],
          ),
        ],
      );

      await cubit.selectFileAndParse();
      cubit.confirmHeaderRow();
      cubit.setFieldMapping(InventoryImportField.name, 0);
      cubit.setFieldMapping(InventoryImportField.sku, 1);
      cubit.setFieldMapping(InventoryImportField.openingStock, 2);
      await cubit.confirmMapping();

      var previewState = cubit.state as InventoryImportPreviewState;
      expect(previewState.preview.selectedCount, 1);

      // Deselect all
      cubit.deselectAll();
      previewState = cubit.state as InventoryImportPreviewState;
      expect(previewState.preview.selectedCount, 0);

      // With 0 selected, executeImport does nothing
      await cubit.executeImport();
      expect(cubit.state, isA<InventoryImportPreviewState>());

      // Select all valid
      cubit.selectAllValid();
      previewState = cubit.state as InventoryImportPreviewState;
      expect(previewState.preview.selectedCount, 1);

      // Toggle row selection
      cubit.toggleRowSelection(2);
      previewState = cubit.state as InventoryImportPreviewState;
      expect(previewState.preview.selectedCount, 0);

      cubit.toggleRowSelection(2);
      previewState = cubit.state as InventoryImportPreviewState;
      expect(previewState.preview.selectedCount, 1);

      // Execute import -> Success
      await cubit.executeImport();
      expect(cubit.state, isA<InventoryImportSuccessState>());
      final successState = cubit.state as InventoryImportSuccessState;
      expect(successState.result.successCount, 1);
      expect(successState.result.failureCount, 0);
    });

    test('back navigation works through all workflow stages', () async {
      fakePicker.fileToReturn = InventoryImportSelectedFile(
        name: 'test.xlsx',
        extension: 'xlsx',
        sizeBytes: 100,
        bytes: Uint8List(10),
      );
      fakeParser.parsedToReturn = const InventoryImportParsedFile(
        fileName: 'test.xlsx',
        fileType: InventoryImportFileType.xlsx,
        sheets: [
          InventoryImportParsedSheet(
            name: 'Sheet 1',
            rows: [
              ['Name', 'SKU'],
              ['A', 'S1'],
            ],
          ),
          InventoryImportParsedSheet(name: 'Sheet 2', rows: []),
        ],
      );

      await cubit.selectFileAndParse();
      expect(cubit.state, isA<InventoryImportSheetSelect>());

      cubit.confirmSheet();
      expect(cubit.state, isA<InventoryImportHeaderSelect>());

      cubit.confirmHeaderRow();
      expect(cubit.state, isA<InventoryImportMappingState>());

      cubit.setFieldMapping(InventoryImportField.name, 0);
      cubit.setFieldMapping(InventoryImportField.sku, 1);
      await cubit.confirmMapping();
      expect(cubit.state, isA<InventoryImportPreviewState>());

      // Navigate back to Mapping
      cubit.backToMapping();
      expect(cubit.state, isA<InventoryImportMappingState>());

      // Navigate back to Header
      cubit.backToHeaderSelection();
      expect(cubit.state, isA<InventoryImportHeaderSelect>());

      // Navigate back to Sheet
      cubit.backToSheetSelection();
      expect(cubit.state, isA<InventoryImportSheetSelect>());

      // Navigate back to Initial
      cubit.backToFileSelection();
      expect(cubit.state, isA<InventoryImportInitial>());
    });
  });
}
