import 'dart:async';
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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExportFileSaver implements InventoryExportFileSaver {
  String? lastFileName;
  Uint8List? lastBytes;
  String? lastMimeType;
  String? lastExtension;
  int callCount = 0;
  Uri? returnUri;
  Exception? throwException;
  Completer<Uri?>? completer;

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

    if (completer != null) {
      return await completer!.future;
    }
    if (throwException != null) {
      throw throwException!;
    }
    return returnUri;
  }
}

void main() {
  CurrentUser makeUser({
    String id = 'usr_1',
    AccountType type = AccountType.user,
    Set<CrmModule>? modules,
    Set<String>? permissions,
  }) {
    return CurrentUser(
      id: id,
      displayName: 'Test User',
      accountType: type,
      modules: modules ?? {CrmModule.inventory},
      permissions: permissions ?? {
        CrmPermissions.inventoryView,
        CrmPermissions.inventoryExportCsv,
        CrmPermissions.inventoryExportXlsx,
      },
    );
  }

  group('InventoryExportDialog Widget Tests', () {
    late MockInventoryRepository mockRepo;
    late _FakeExportFileSaver fakeSaver;
    late InventoryExportFileDeliveryService deliveryService;

    setUp(() {
      mockRepo = MockInventoryRepository();
      fakeSaver = _FakeExportFileSaver();
      deliveryService = InventoryExportFileDeliveryService(
        fileSaver: fakeSaver,
        isWeb: false,
      );
    });

    testWidgets('shows both CSV and Excel options when user has both permissions', (tester) async {
      final user = makeUser();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Export Inventory'), findsOneWidget);
      expect(find.byKey(const Key('inventory_export_format_csv')), findsOneWidget);
      expect(find.byKey(const Key('inventory_export_format_xlsx')), findsOneWidget);

      final csvTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_csv')),
      );
      final xlsxTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_xlsx')),
      );

      expect(csvTile.enabled, isTrue);
      expect(xlsxTile.enabled, isTrue);
    });

    testWidgets('CSV-only user has CSV enabled and XLSX disabled', (tester) async {
      final user = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryExportCsv,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final csvTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_csv')),
      );
      final xlsxTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_xlsx')),
      );

      expect(csvTile.enabled, isTrue);
      expect(xlsxTile.enabled, isFalse);
    });

    testWidgets('XLSX-only user has XLSX enabled and CSV disabled', (tester) async {
      final user = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryExportXlsx,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final csvTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_csv')),
      );
      final xlsxTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_xlsx')),
      );

      expect(csvTile.enabled, isFalse);
      expect(xlsxTile.enabled, isTrue);
    });

    testWidgets('tapping cancel closes dialog without starting export', (tester) async {
      final user = makeUser();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_export_dialog_cancel_button')));
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(0));
    });

    testWidgets('successful export on Android saves file and shows success message', (tester) async {
      final user = makeUser();
      fakeSaver.returnUri = Uri.parse('file:///storage/emulated/0/Download/export.csv');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Export button
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pump(); // Start preparing

      // Pump through async preparation & delivery
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(1));
      expect(fakeSaver.lastExtension, equals('csv'));
      expect(find.text('Inventory exported successfully.'), findsOneWidget);
    });

    testWidgets('successful export on Web shows download started message', (tester) async {
      final user = makeUser();
      final webDeliveryService = InventoryExportFileDeliveryService(
        fileSaver: fakeSaver,
        isWeb: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              repository: mockRepo,
              fileDeliveryService: webDeliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(1));
      expect(find.text('Inventory download started.'), findsOneWidget);
    });

    testWidgets('user cancellation in save dialog shows cancellation feedback without crash', (tester) async {
      final user = makeUser();
      fakeSaver.returnUri = null; // User cancelled save dialog

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(1));
      expect(find.text('File save was cancelled.'), findsOneWidget);
    });

    testWidgets('responsive layout on narrow screen (320px width) does not overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final user = makeUser();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('inventory_export_dialog')), findsOneWidget);
    });
  });

  group('Inventory Workspace Export Action Visibility', () {
    late MockInventoryRepository mockRepo;

    setUp(() {
      mockRepo = MockInventoryRepository();
    });

    testWidgets('Admin sees Export button on desktop and mobile', (tester) async {
      final admin = CurrentUser(
        id: 'adm_1',
        displayName: 'Admin User',
        accountType: AccountType.admin,
        modules: {CrmModule.inventory},
        permissions: {},
      );

      // Desktop
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: admin, repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_workspace_export_button')), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);

      // Mobile
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: admin, repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_workspace_export_button')), findsOneWidget);
    });

    testWidgets('Standard user with inventory.view + export.csv sees Export button', (tester) async {
      final standardWithCsv = CurrentUser(
        id: 'usr_csv',
        displayName: 'CSV User',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryExportCsv,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: standardWithCsv, repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_workspace_export_button')), findsOneWidget);
    });

    testWidgets('Standard user without any export permission does NOT see Export button', (tester) async {
      final viewOnlyUser = CurrentUser(
        id: 'usr_view',
        displayName: 'View User',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {
          CrmPermissions.inventoryView,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: viewOnlyUser, repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_workspace_export_button')), findsNothing);
    });

    testWidgets('tapping Export button on workspace opens InventoryExportDialog', (tester) async {
      final admin = CurrentUser(
        id: 'adm_1',
        displayName: 'Admin User',
        accountType: AccountType.admin,
        modules: {CrmModule.inventory},
        permissions: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: admin, repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_workspace_export_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_export_dialog')), findsOneWidget);
      expect(find.text('Export Inventory'), findsOneWidget);
    });
  });
}
