// ignore_for_file: depend_on_referenced_packages, avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_import_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_import_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_file_picker.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _DirectFilePicker implements InventoryImportFilePicker {
  InventoryImportSelectedFile? fileToReturn;

  @override
  Future<InventoryImportSelectedFile?> pickFile({
    List<String>? allowedExtensions,
  }) async =>
      fileToReturn;
}

class _DirectParser implements InventoryImportParser {
  InventoryImportParsedFile? parsedToReturn;

  @override
  Future<InventoryImportParsedFile> parse(
    InventoryImportSelectedFile file,
  ) async =>
      parsedToReturn!;
}

void main() {
  testWidgets('Capture visual screenshots of Import Gallery Selection states', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const adminUser = CurrentUser(
      id: 'admin_1',
      displayName: 'Admin User',
      accountType: AccountType.admin,
      modules: {CrmModule.inventory},
      permissions: {CrmPermissions.inventoryView},
    );

    final repository = MockInventoryRepository();
    final picker = _DirectFilePicker();
    final parser = _DirectParser();

    final importCubit = InventoryImportCubit(
      repository: repository,
      user: adminUser,
      filePicker: picker,
      parser: parser,
    );

    picker.fileToReturn = InventoryImportSelectedFile(
      name: 'inventory_master.xlsx',
      extension: 'xlsx',
      sizeBytes: 1024,
      bytes: Uint8List(10),
    );

    parser.parsedToReturn = const InventoryImportParsedFile(
      fileName: 'inventory_master.xlsx',
      fileType: InventoryImportFileType.xlsx,
      sheets: [
        InventoryImportParsedSheet(
          name: 'Inventory_Data',
          rows: [
            ['Product Name', 'SKU', 'Category', 'Selling Price', 'Cost Price'],
            ['Ultra HD 4K Monitor', 'SKU-SAMPLE-101', 'Electronics', '349.99', '220.00'],
            ['Mechanical Keyboard RGB', 'SKU-SAMPLE-102', 'Electronics', '89.50', '45.00'],
            ['Ergonomic Office Chair', 'SKU-SAMPLE-103', 'Office Supplies', '199.00', '110.00'],
            ['Wireless Laser Mouse', 'SKU-SAMPLE-104', 'Electronics', '49.99', '25.00'],
            ['Desk Lamp Dimmable', 'SKU-SAMPLE-105', 'Stationery', '29.99', '14.00'],
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
    importCubit.setFieldMapping(InventoryImportField.sellingPriceInr, 3);
    importCubit.setFieldMapping(InventoryImportField.unitCostInr, 4);
    await importCubit.confirmMapping();

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: repaintKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.indigo,
          ),
          home: InventoryImportScreen(
            user: adminUser,
            repository: repository,
            cubit: importCubit,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> saveScreenshot(String path) async {
      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 1.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            File(path).writeAsBytesSync(byteData.buffer.asUint8List());
            print('Saved screenshot to: $path (${byteData.lengthInBytes} bytes)');
          }
        }
      });
    }

    const artifactDir = r'C:\Users\vacha\.gemini\antigravity-ide\brain\8ff93468-6248-4a2f-b0fc-839c9627afa5';

    // 1. Select All rows and columns
    importCubit.selectAll();
    await tester.pumpAndSettle();
    await saveScreenshot('$artifactDir\\import_gallery_all_selected.png');

    // 2. Clear Selection (Rows & optional columns cleared, Name & SKU retained)
    importCubit.clearSelection();
    await tester.pumpAndSettle();
    await saveScreenshot('$artifactDir\\import_gallery_clear_selection.png');

    // 3. Individual row and column selection with highlighting
    importCubit.toggleRowSelection(2);
    importCubit.toggleRowSelection(3);
    importCubit.toggleColumnSelection('sellingPriceInr');
    await tester.pumpAndSettle();
    await saveScreenshot('$artifactDir\\import_gallery_individual_selection.png');

    // 4. Execute Import and capture Success Result Screen
    await importCubit.executeImport();
    await tester.pumpAndSettle();
    await saveScreenshot('$artifactDir\\import_gallery_result_success.png');

    importCubit.close();
  });
}
