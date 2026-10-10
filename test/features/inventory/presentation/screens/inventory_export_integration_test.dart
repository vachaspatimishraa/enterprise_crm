import 'dart:convert';
import 'dart:typed_data';

import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_artifact.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_workspace_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_file_delivery_service.dart';
import 'package:enterprise_crm/features/inventory/presentation/widgets/inventory_export_dialog.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CapturingExportFileSaver implements InventoryExportFileSaver {
  String? lastFileName;
  Uint8List? lastBytes;
  String? lastMimeType;
  String? lastExtension;
  int callCount = 0;
  Uri? returnUri = Uri.parse('file:///mock/save/path');
  Exception? throwException;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
    String? dialogTitle,
  }) async {
    callCount++;
    lastFileName = fileName;
    lastBytes = bytes;
    lastMimeType = mimeType;
    lastExtension = extension;

    if (throwException != null) throw throwException!;
    return returnUri;
  }
}

void main() {
  group('Inventory Export End-to-End Integration Flow', () {
    late MockInventoryRepository mockRepo;
    late _CapturingExportFileSaver fileSaver;

    final adminUser = CurrentUser(
      id: 'usr_admin',
      displayName: 'Admin User',
      accountType: AccountType.admin,
      modules: {CrmModule.inventory},
      permissions: {},
    );

    final standardCsvOnly = CurrentUser(
      id: 'usr_csv',
      displayName: 'CSV User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {
        CrmPermissions.inventoryView,
        CrmPermissions.inventoryExportCsv,
      },
    );

    final standardXlsxOnly = CurrentUser(
      id: 'usr_xlsx',
      displayName: 'XLSX User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {
        CrmPermissions.inventoryView,
        CrmPermissions.inventoryExportXlsx,
      },
    );

    setUp(() {
      mockRepo = MockInventoryRepository();
      fileSaver = _CapturingExportFileSaver();
    });

    testWidgets('Full CSV export flow from Workspace to FileSaver with complete dataset', (tester) async {
      final deliveryService = InventoryExportFileDeliveryService(
        fileSaver: fileSaver,
        isWeb: false,
      );

      // 1. Open Workspace
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: adminUser, currentUserProvider: () => adminUser, repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      // 2. Tap Export Button
      expect(find.byKey(const Key('inventory_workspace_export_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('inventory_workspace_export_button')));
      await tester.pumpAndSettle();

      // Verify Dialog opens
      expect(find.byKey(const Key('inventory_export_dialog')), findsOneWidget);

      // Replace Dialog with one using our capturing deliveryService
      Navigator.of(tester.element(find.byKey(const Key('inventory_export_dialog')))).pop();
      await tester.pumpAndSettle();

      // Now open dialog with deliveryService injected
      final context = tester.element(find.byType(InventoryWorkspaceScreen));
      showInventoryExportDialog(
        context: context,
        user: adminUser,
        currentUserProvider: () => adminUser,
        repository: mockRepo,
        fileDeliveryService: deliveryService,
      );
      await tester.pumpAndSettle();

      // Select CSV format
      await tester.tap(find.byKey(const Key('inventory_export_format_csv')));
      await tester.pumpAndSettle();

      // Tap Export submit to prepare
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      // Saver must NOT have been called yet
      expect(fileSaver.callCount, equals(0));
      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);

      // Tap explicit Download button
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      // Verify fileSaver was invoked
      expect(fileSaver.callCount, equals(1));
      expect(fileSaver.lastExtension, equals('csv'));
      expect(fileSaver.lastMimeType, equals('text/csv'));
      expect(fileSaver.lastFileName, startsWith('inventory_export_'));
      expect(fileSaver.lastFileName, endsWith('.csv'));

      // Verify CSV content integrity: all 25 active items exported with complete details
      final csvText = utf8.decode(fileSaver.lastBytes!);
      final lines = csvText.trim().split('\n');
      expect(lines.length, equals(26)); // Header + 25 rows
      final headerLine = lines.first.trim();
      expect(headerLine.split(',').length, equals(21));
      expect(headerLine, contains('Product Name'));
      expect(headerLine, contains('SKU'));
      expect(headerLine, contains('Current Quantity'));
      expect(headerLine, contains('Unit Cost (INR)'));
      expect(headerLine, contains('Supplier'));
      expect(headerLine, contains('Selling Price (INR)'));
      expect(headerLine, contains('Warehouse'));

      expect(find.text('Inventory exported successfully.'), findsOneWidget);
    });

    testWidgets('Full XLSX export flow preserves workbook structure and numeric quantities', (tester) async {
      final deliveryService = InventoryExportFileDeliveryService(
        fileSaver: fileSaver,
        isWeb: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: standardXlsxOnly, currentUserProvider: () => standardXlsxOnly, repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Open Dialog directly with injected deliveryService
      final context = tester.element(find.byType(InventoryWorkspaceScreen));
      showInventoryExportDialog(
        context: context,
        user: standardXlsxOnly,
        currentUserProvider: () => standardXlsxOnly,
        repository: mockRepo,
        fileDeliveryService: deliveryService,
      );
      await tester.pumpAndSettle();

      // Verify XLSX is selected and CSV is disabled
      final xlsxTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_xlsx')),
      );
      final csvTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_csv')),
      );
      expect(xlsxTile.enabled, isTrue);
      expect(csvTile.enabled, isFalse);

      // Tap Export submit to prepare
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(fileSaver.callCount, equals(0));
      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);

      // Explicit download action
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(fileSaver.callCount, equals(1));
      expect(fileSaver.lastExtension, equals('xlsx'));
      expect(
        fileSaver.lastMimeType,
        equals('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      );

      // Verify valid XLSX structure
      final excel = Excel.decodeBytes(fileSaver.lastBytes!);
      expect(excel.tables.keys, contains('Inventory'));
      final sheet = excel.tables['Inventory']!;
      expect(sheet.maxRows, equals(26)); // Header + 25 rows
      expect(sheet.maxColumns, equals(19)); // 19 permitted non-sensitive fields
      final headers = sheet.rows.first.map((c) => c?.value.toString()).toList();
      expect(headers, contains('Product Name'));
      expect(headers, contains('SKU'));
      expect(headers, contains('Current Quantity'));
      expect(headers, contains('Warehouse'));
    });

    testWidgets('Platform failure shows failure feedback and does not claim success', (tester) async {
      fileSaver.throwException = Exception('Disk write failed');
      final deliveryService = InventoryExportFileDeliveryService(
        fileSaver: fileSaver,
        isWeb: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: standardCsvOnly, currentUserProvider: () => standardCsvOnly, repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(InventoryWorkspaceScreen));
      showInventoryExportDialog(
        context: context,
        user: standardCsvOnly,
        currentUserProvider: () => standardCsvOnly,
        repository: mockRepo,
        fileDeliveryService: deliveryService,
      );
      await tester.pumpAndSettle();

      // 1. Prepare
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      // 2. Download
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(fileSaver.callCount, equals(1));
      expect(find.text('Inventory exported successfully.'), findsNothing);
      expect(find.byKey(const Key('inventory_export_dialog_delivery_feedback')), findsOneWidget);
      expect(find.textContaining('Disk write failed'), findsOneWidget);
    });

    testWidgets('Legacy Three-Column preset exports frozen 3 columns when selected', (tester) async {
      final deliveryService = InventoryExportFileDeliveryService(
        fileSaver: fileSaver,
        isWeb: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: adminUser, currentUserProvider: () => adminUser, repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(InventoryWorkspaceScreen));
      showInventoryExportDialog(
        context: context,
        user: adminUser,
        currentUserProvider: () => adminUser,
        repository: mockRepo,
        fileDeliveryService: deliveryService,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_export_format_csv')));
      await tester.ensureVisible(find.byKey(const Key('inventory_export_preset_legacy')));
      await tester.tap(find.byKey(const Key('inventory_export_preset_legacy')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(fileSaver.callCount, equals(1));
      final csvText = utf8.decode(fileSaver.lastBytes!);
      final lines = csvText.trim().split('\n');
      expect(lines.first.trim(), equals('Item Name,SKU,Current Quantity'));
    });
  });
}
