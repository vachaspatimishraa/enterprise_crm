import 'dart:typed_data';

import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/custom_field_definition.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_artifact.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_fields.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/policies/inventory_field_access_policy.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_export_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_export_state.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_data_loader.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_file_delivery_service.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_service.dart';
import 'package:enterprise_crm/features/inventory/presentation/widgets/inventory_export_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CapturingFileSaver implements InventoryExportFileSaver {
  String? savedFileName;
  Uint8List? savedBytes;
  int saveCount = 0;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
    String? dialogTitle,
  }) async {
    savedFileName = fileName;
    savedBytes = bytes;
    saveCount++;
    return Uri.file('/tmp/\$fileName');
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
      CrmPermissions.inventoryExportCsv,
      CrmPermissions.inventoryExportXlsx,
      InventoryFieldAccessPolicy.exportPdfPermission,
    },
  );

  late MockInventoryRepository repo;
  late _CapturingFileSaver fakeSaver;
  late InventoryExportFileDeliveryService deliveryService;

  setUp(() async {
    fakeSaver = _CapturingFileSaver();
    deliveryService = InventoryExportFileDeliveryService(
      fileSaver: fakeSaver,
      isWeb: false,
    );
    repo = MockInventoryRepository(items: []);

    // Register a custom field definition
    await repo.saveCustomFieldDefinition(
      CustomFieldDefinition(
        id: 'def_tag',
        key: 'asset_tag',
        label: 'Asset Tag',
        dataType: CustomFieldDataType.text,
      ),
    );

    // Seed 4 test inventory items
    for (int i = 1; i <= 4; i++) {
      await repo.createItem(
        CreateInventoryItemInput(
          name: 'Product $i',
          sku: 'SKU-00$i',
          category: i % 2 == 0 ? 'Electronics' : 'General',
          unitCostInr: 100.0 * i,
          sellingPriceInr: 150.0 * i,
          customFields: {'asset_tag': 'TAG-00$i'},
        ),
      );
    }
  });

  group('Phase 4: Gallery-Style Export Wizard Acceptance Tests', () {
    testWidgets('1. Export Wizard modal renders responsive and clean across all screen sizes', (tester) async {
      final viewports = <String, Size>{
        'Mobile (360x640)': const Size(360, 640),
        'Tablet (768x1024)': const Size(768, 1024),
        'Desktop (1200x800)': const Size(1200, 800),
      };

      for (final entry in viewports.entries) {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InventoryExportDialog(
                user: adminUser,
                repository: repo,
                currentUserProvider: () => adminUser,
                fileDeliveryService: deliveryService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inventory_export_dialog')), findsOneWidget);
        expect(find.byKey(const Key('inventory_export_format_csv')), findsOneWidget);
        expect(find.byKey(const Key('inventory_export_format_xlsx')), findsOneWidget);
        expect(find.byKey(const Key('inventory_export_format_pdf')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('2. Gallery column customization: toggle custom columns and live counter updates', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: adminUser,
              repository: repo,
              currentUserProvider: () => adminUser,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch preset to custom to expose column selection gallery
      final customPresetFinder = find.byKey(const Key('inventory_export_preset_custom'));
      await tester.ensureVisible(customPresetFinder);
      await tester.tap(customPresetFinder);
      await tester.pumpAndSettle();

      // Verify custom field 'asset_tag' is present in selectable columns
      final customColCheckbox = find.byKey(const Key('inventory_export_col_asset_tag'));
      expect(customColCheckbox, findsOneWidget);

      // Verify Select All and Deselect All columns buttons exist
      expect(find.byKey(const Key('inventory_export_select_all_columns')), findsOneWidget);
      expect(find.byKey(const Key('inventory_export_deselect_all_columns')), findsOneWidget);

      // Tapping Deselect All columns empties column count and disables submit button
      final deselectBtn = find.byKey(const Key('inventory_export_deselect_all_columns'));
      await tester.ensureVisible(deselectBtn);
      await tester.tap(deselectBtn);
      await tester.pumpAndSettle();

      final submitBtn = tester.widget<ButtonStyleButton>(find.byKey(const Key('inventory_export_dialog_submit_button')));
      expect(submitBtn.onPressed, isNull); // Disabled when 0 columns selected

      // Tapping Select All re-enables submit button
      final selectAllBtn = find.byKey(const Key('inventory_export_select_all_columns'));
      await tester.ensureVisible(selectAllBtn);
      await tester.tap(selectAllBtn);
      await tester.pumpAndSettle();
      final submitBtnAfter = tester.widget<ButtonStyleButton>(find.byKey(const Key('inventory_export_dialog_submit_button')));
      expect(submitBtnAfter.onPressed, isNotNull);
    });

    testWidgets('3. Record Scopes: selected scope respects exact subset of rows', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final allItems = await repo.getItems(const InventoryQuery());
      final selectedId = allItems.items.first.item.id;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: adminUser,
              repository: repo,
              currentUserProvider: () => adminUser,
              fileDeliveryService: deliveryService,
              selectedItemIds: {selectedId},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Choose 'selected' scope
      final selectedScopeFinder = find.byKey(const Key('inventory_export_scope_selected'));
      await tester.ensureVisible(selectedScopeFinder);
      await tester.tap(selectedScopeFinder);
      await tester.pumpAndSettle();

      // Prepare export
      final submitFinder = find.byKey(const Key('inventory_export_dialog_submit_button'));
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      // Trigger download
      final downloadFinder = find.byKey(const Key('inventory_export_dialog_download_button'));
      expect(downloadFinder, findsOneWidget);
      await tester.tap(downloadFinder);
      await tester.pumpAndSettle();

      // Verify file delivery was triggered
      expect(fakeSaver.saveCount, 1);
      expect(fakeSaver.savedBytes, isNotNull);
      final textContent = String.fromCharCodes(fakeSaver.savedBytes!);

      // Verify only 1 record (+ 1 header row) is present
      final lines = textContent.trim().split('\n');
      expect(lines.length, 2);
    });

    testWidgets('4. Multi-format artifact generation: CSV, XLSX, and PDF generate valid payloads', (tester) async {
      final dataLoader = InventoryExportDataLoader(repo);
      final service = InventoryExportService(dataLoader: dataLoader);
      final cubit = InventoryExportCubit(
        exportService: service,
        currentUser: adminUser,
      );

      final customDefs = await repo.getCustomFieldDefinitions();
      // CSV export
      await cubit.export(
        InventoryExportFormat.csv,
        scope: InventoryExportScope.all,
        preset: InventoryExportPreset.custom,
        columns: ['name', 'sku', 'category', 'asset_tag'],
        customFieldDefinitions: customDefs,
      );
      expect(cubit.state, isA<InventoryExportPrepared>());
      final csvState = cubit.state as InventoryExportPrepared;
      expect(csvState.artifact.format, InventoryExportFormat.csv);
      expect(csvState.artifact.mimeType, 'text/csv');
      final csvContent = String.fromCharCodes(csvState.artifact.bytes);
      expect(csvContent, contains('Product Name'));
      expect(csvContent, contains('Asset Tag'));

      // XLSX export
      await cubit.export(
        InventoryExportFormat.xlsx,
        scope: InventoryExportScope.all,
        preset: InventoryExportPreset.custom,
        columns: ['name', 'sku', 'category'],
      );
      expect(cubit.state, isA<InventoryExportPrepared>());
      final xlsxState = cubit.state as InventoryExportPrepared;
      expect(xlsxState.artifact.format, InventoryExportFormat.xlsx);
      expect(xlsxState.artifact.bytes.length, greaterThan(100));

      // PDF export
      await cubit.export(
        InventoryExportFormat.pdf,
        scope: InventoryExportScope.all,
        preset: InventoryExportPreset.legacyThreeColumn,
        columns: InventoryExportFields.legacyHeaders,
      );
      expect(cubit.state, isA<InventoryExportPrepared>());
      final pdfState = cubit.state as InventoryExportPrepared;
      expect(pdfState.artifact.format, InventoryExportFormat.pdf);
      expect(pdfState.artifact.mimeType, 'application/pdf');
      expect(pdfState.artifact.bytes.length, greaterThan(200));
    });

    testWidgets('5. Fail-closed security: missing required export permission prevents download', (tester) async {
      const viewerUser = CurrentUser(
        id: 'viewer_1',
        displayName: 'Viewer',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {CrmPermissions.inventoryView}, // No export permissions
      );

      final dataLoader = InventoryExportDataLoader(repo);
      final service = InventoryExportService(dataLoader: dataLoader);
      final cubit = InventoryExportCubit(
        exportService: service,
        currentUser: viewerUser,
      );

      // Attempting CSV export without permission must fail closed
      await cubit.export(
        InventoryExportFormat.csv,
        scope: InventoryExportScope.all,
        preset: InventoryExportPreset.legacyThreeColumn,
        columns: InventoryExportFields.legacyHeaders,
      );

      expect(cubit.state, isA<InventoryExportRestricted>());
    });
  });
}
