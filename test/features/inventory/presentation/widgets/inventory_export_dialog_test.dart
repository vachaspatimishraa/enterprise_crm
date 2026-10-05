import 'dart:async';
import 'dart:typed_data';

import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:enterprise_crm/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:enterprise_crm/features/auth/presentation/bloc/auth_state.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_artifact.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_page.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_workspace_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_file_delivery_service.dart';
import 'package:enterprise_crm/features/inventory/domain/policies/inventory_export_policy.dart';
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

class _DelayedInventoryRepository extends MockInventoryRepository {
  Completer<void>? delayCompleter;

  @override
  Future<InventoryPage> getItems(InventoryQuery query) async {
    if (delayCompleter != null) {
      await delayCompleter!.future;
    }
    return super.getItems(query);
  }
}


class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(super.initialState);

  void emitState(AuthState state) => emit(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TrackingInventoryRepository implements InventoryRepository {
  final InventoryRepository delegate;
  int getItemsCount = 0;
  _TrackingInventoryRepository(this.delegate);

  @override
  Future<InventoryPage> getItems(InventoryQuery query) {
    getItemsCount++;
    return delegate.getItems(query);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => invocation;
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
              currentUserProvider: () => user,
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

      final pdfTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_pdf')),
      );

      expect(csvTile.enabled, isTrue);
      expect(xlsxTile.enabled, isTrue);
      expect(pdfTile.enabled, isFalse);
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
              currentUserProvider: () => user,
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

      final pdfTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_pdf')),
      );

      expect(csvTile.enabled, isTrue);
      expect(xlsxTile.enabled, isFalse);
      expect(pdfTile.enabled, isFalse);
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
              currentUserProvider: () => user,
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

      final pdfTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_pdf')),
      );

      expect(csvTile.enabled, isFalse);
      expect(xlsxTile.enabled, isTrue);
      expect(pdfTile.enabled, isFalse);
    });


    testWidgets('PDF-only user has PDF enabled and CSV/XLSX disabled', (tester) async {
      final user = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          InventoryExportPolicy.exportPdfPermission,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              currentUserProvider: () => user,
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
      final pdfTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_pdf')),
      );

      expect(csvTile.enabled, isFalse);
      expect(xlsxTile.enabled, isFalse);
      expect(pdfTile.enabled, isTrue);
      final radioGroup = tester.widget<RadioGroup<InventoryExportFormat>>(
        find.byType(RadioGroup<InventoryExportFormat>),
      );
      expect(radioGroup.groupValue, equals(InventoryExportFormat.pdf));
    });

    testWidgets('User with all three permissions has CSV, XLSX, and PDF enabled', (tester) async {
      final user = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryExportCsv,
          CrmPermissions.inventoryExportXlsx,
          InventoryExportPolicy.exportPdfPermission,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              currentUserProvider: () => user,
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
      final pdfTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_pdf')),
      );

      expect(csvTile.enabled, isTrue);
      expect(xlsxTile.enabled, isTrue);
      expect(pdfTile.enabled, isTrue);
    });

    testWidgets('PDF export flow: prepares and downloads PDF successfully', (tester) async {
      final user = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          InventoryExportPolicy.exportPdfPermission,
        },
      );
      fakeSaver.returnUri = Uri.parse('file:///storage/export.pdf');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              currentUserProvider: () => user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap prepare
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);
      expect(find.text('Download PDF'), findsOneWidget);

      // Tap download
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(1));
      expect(fakeSaver.lastMimeType, equals('application/pdf'));
      expect(fakeSaver.lastFileName, endsWith('.pdf'));
    });

    testWidgets('PDF export security: permission revocation before delivery blocks saver with 0 saver calls', (tester) async {
      CurrentUser? liveUser = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          InventoryExportPolicy.exportPdfPermission,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: liveUser,
              currentUserProvider: () => liveUser,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Prepare PDF
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);

      // 2. Revoke PDF permission
      liveUser = makeUser(
        permissions: {
          CrmPermissions.inventoryView, // No PDF permission
        },
      );

      // 3. Tap download
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(0));
      expect(
        find.text('User is not authorized to deliver this export format.'),
        findsOneWidget,
      );
    });

    testWidgets('PDF export security: account switch before delivery blocks saver with 0 saver calls', (tester) async {
      CurrentUser? liveUser = makeUser(
        id: 'user_pdf_orig',
        permissions: {
          CrmPermissions.inventoryView,
          InventoryExportPolicy.exportPdfPermission,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: liveUser,
              currentUserProvider: () => liveUser,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Prepare PDF
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);

      // 2. Account switch
      liveUser = makeUser(
        id: 'user_pdf_switched',
        permissions: {
          CrmPermissions.inventoryView,
          InventoryExportPolicy.exportPdfPermission,
        },
      );

      // 3. Tap download
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(0));
      expect(
        find.text('User identity changed since export was prepared.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping cancel closes dialog without starting export', (tester) async {
      final user = makeUser();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              currentUserProvider: () => user,
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

    testWidgets('preparing displays a loading state and progress indicator', (tester) async {
      final delayedRepo = _DelayedInventoryRepository();
      delayedRepo.delayCompleter = Completer<void>();
      final user = makeUser();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              currentUserProvider: () => user,
              repository: delayedRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Export button to prepare
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pump(); // Enter preparing state

      // Assert loading indicator is displayed while in-flight
      expect(find.byKey(const Key('inventory_export_loading_indicator')), findsOneWidget);
      expect(find.text('Preparing inventory export...'), findsOneWidget);

      // Finish async preparation
      delayedRepo.delayCompleter!.complete();
      await tester.pumpAndSettle();

      // Preparation finishes: loading indicator gone, prepared download button visible
      expect(find.byKey(const Key('inventory_export_loading_indicator')), findsNothing);
      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);
    });

    testWidgets('prepared state displays Download button and does NOT auto-invoke file saver', (tester) async {
      final user = makeUser();
      fakeSaver.returnUri = Uri.parse('file:///storage/emulated/0/Download/export.csv');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              currentUserProvider: () => user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Export button to prepare
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle(); // Preparation completes

      // Critical check: Prepared state reached, but file saver has NOT been called!
      expect(fakeSaver.callCount, equals(0));
      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);
      expect(find.text('Download CSV'), findsOneWidget);
      expect(find.text('Inventory export ready (CSV).'), findsOneWidget);
    });

    testWidgets('tapping Download button invokes file delivery exactly once', (tester) async {
      final user = makeUser();
      fakeSaver.returnUri = Uri.parse('file:///storage/emulated/0/Download/export.csv');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              currentUserProvider: () => user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Prepare export
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(0));

      // 2. Explicit user action: click Download button
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(1));
      expect(fakeSaver.lastExtension, equals('csv'));
      expect(find.text('Inventory exported successfully.'), findsOneWidget);
    });

    testWidgets('rebuild does not trigger another download', (tester) async {
      final user = makeUser();
      fakeSaver.returnUri = Uri.parse('file:///storage/emulated/0/Download/export.csv');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              currentUserProvider: () => user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(1));

      // Rebuild the tree
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              currentUserProvider: () => user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Call count remains 1
      expect(fakeSaver.callCount, equals(1));
    });

    testWidgets('duplicate concurrent clicks on download are guarded', (tester) async {
      final user = makeUser();
      fakeSaver.completer = Completer<Uri?>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              currentUserProvider: () => user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      // Click download button while saver is suspended
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pump(); // starts delivery, _isDelivering = true

      expect(fakeSaver.callCount, equals(1));

      // Attempt second tap while in-flight
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')), warnIfMissed: false);
      await tester.pump();

      expect(fakeSaver.callCount, equals(1));

      // Complete delivery
      fakeSaver.completer!.complete(Uri.parse('file:///path/export.csv'));
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(1));
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
              currentUserProvider: () => user,
              repository: mockRepo,
              fileDeliveryService: webDeliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(1));
      expect(find.text('Inventory download started.'), findsOneWidget);
    });

    testWidgets('user cancellation in save dialog shows cancellation feedback and permits retry', (tester) async {
      final user = makeUser();
      fakeSaver.returnUri = null; // User cancelled save dialog

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              currentUserProvider: () => user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      // First delivery attempt cancelled
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(1));
      expect(find.text('File save was cancelled.'), findsOneWidget);

      // Retry: tap download button again with success
      fakeSaver.returnUri = Uri.parse('file:///storage/export.csv');
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(2));
      expect(find.text('Inventory exported successfully.'), findsOneWidget);
    });

    testWidgets('logout before delivery blocks platform saver with restricted feedback', (tester) async {
      CurrentUser? liveUser = makeUser();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: liveUser,
              currentUserProvider: () => liveUser,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Prepare export while signed in
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);
      expect(fakeSaver.callCount, equals(0));

      // 2. User logs out before delivery
      liveUser = null;

      // 3. User clicks Download
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      // File saver was NOT invoked
      expect(fakeSaver.callCount, equals(0));
      expect(find.text('User session expired or unauthenticated.'), findsOneWidget);
    });

    testWidgets('account switch before delivery blocks platform saver with restricted feedback', (tester) async {
      final userA = makeUser(id: 'user_a');
      final userB = makeUser(id: 'user_b');
      CurrentUser? liveUser = userA;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: userA,
              currentUserProvider: () => liveUser,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. User A prepares export
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);

      // 2. Account switches to User B
      liveUser = userB;

      // 3. Download clicked
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      // File saver was NOT invoked for different user identity
      expect(fakeSaver.callCount, equals(0));
      expect(find.text('User identity changed since export was prepared.'), findsOneWidget);
    });

    testWidgets('permission revocation before delivery blocks platform saver', (tester) async {
      CurrentUser? liveUser = makeUser();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: liveUser,
              currentUserProvider: () => liveUser,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Prepare CSV
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);

      // 2. CSV permission revoked before delivery
      liveUser = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryExportXlsx, // Only XLSX now, CSV revoked
        },
      );

      // 3. Tap download CSV
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(0));
      expect(
        find.text('User is not authorized to deliver this export format.'),
        findsOneWidget,
      );
    });

    testWidgets('inventory.view revocation before delivery blocks platform saver', (tester) async {
      CurrentUser? liveUser = makeUser();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: liveUser,
              currentUserProvider: () => liveUser,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      // inventory.view revoked
      liveUser = makeUser(
        permissions: {
          CrmPermissions.inventoryExportCsv,
        },
      );

      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(fakeSaver.callCount, equals(0));
      expect(
        find.text('User is not authorized to deliver this export format.'),
        findsOneWidget,
      );
    });

    testWidgets('format switch after prepared resets state and requires re-preparation', (tester) async {
      final user = makeUser();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              currentUserProvider: () => user,
              repository: mockRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Prepare CSV
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);
      expect(find.text('Download CSV'), findsOneWidget);

      // 2. Switch to Excel format
      await tester.tap(find.byKey(const Key('inventory_export_format_xlsx')));
      await tester.pumpAndSettle();

      // State is reset: submit button reappears for XLSX, download button gone
      expect(find.byKey(const Key('inventory_export_dialog_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsNothing);

      // 3. Prepare Excel
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);
      expect(find.text('Download Excel'), findsOneWidget);
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
              currentUserProvider: () => user,
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

    testWidgets('consistent styling across light and dark themes', (tester) async {
      final user = makeUser();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: InventoryExportDialog(
              user: user,
              currentUserProvider: () => user,
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
          home: InventoryWorkspaceScreen(
            user: admin,
            currentUserProvider: () => admin,
            repository: mockRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_workspace_export_button')), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);

      // Mobile
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(
            user: admin,
            currentUserProvider: () => admin,
            repository: mockRepo,
          ),
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
          home: InventoryWorkspaceScreen(
            user: standardWithCsv,
            currentUserProvider: () => standardWithCsv,
            repository: mockRepo,
          ),
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
          home: InventoryWorkspaceScreen(
            user: viewOnlyUser,
            currentUserProvider: () => viewOnlyUser,
            repository: mockRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_workspace_export_button')), findsNothing);
    });

    testWidgets('tapping Export button on workspace opens InventoryExportDialog with live provider', (tester) async {
      CurrentUser? liveUser = CurrentUser(
        id: 'adm_1',
        displayName: 'Admin User',
        accountType: AccountType.admin,
        modules: {CrmModule.inventory},
        permissions: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(
            user: liveUser,
            currentUserProvider: () => liveUser,
            repository: mockRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inventory_workspace_export_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_export_dialog')), findsOneWidget);
      expect(find.text('Export Inventory'), findsOneWidget);
    });
  });

  group('INVENTORY-6.4-FIX1 Fail-Closed Security Regression Tests', () {
    late MockInventoryRepository baseRepo;
    late _TrackingInventoryRepository trackingRepo;
    late _FakeExportFileSaver fakeSaver;
    late InventoryExportFileDeliveryService deliveryService;

    final adminUser = CurrentUser(
      id: 'adm_sec',
      displayName: 'Sec Admin',
      accountType: AccountType.admin,
      modules: {CrmModule.inventory},
      permissions: {},
    );

    setUp(() {
      baseRepo = MockInventoryRepository();
      trackingRepo = _TrackingInventoryRepository(baseRepo);
      fakeSaver = _FakeExportFileSaver();
      deliveryService = InventoryExportFileDeliveryService(
        fileSaver: fakeSaver,
        isWeb: false,
      );
    });

    testWidgets('Workspace screen: missing AuthCubit and no provider hides Export button (fail closed)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(
            user: adminUser,
            repository: trackingRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_workspace_export_button')), findsNothing);
      expect(fakeSaver.callCount, equals(0));
    });

    testWidgets('Workspace screen: AuthCubit in AuthAuthenticating hides Export button (fail closed)', (tester) async {
      final fakeAuth = _FakeAuthCubit(const AuthAuthenticating());

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: fakeAuth,
          child: MaterialApp(
            home: InventoryWorkspaceScreen(
              user: adminUser,
              repository: trackingRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_workspace_export_button')), findsNothing);
      expect(fakeSaver.callCount, equals(0));
    });

    testWidgets('Workspace screen: AuthCubit in AuthUnauthenticated hides Export button (fail closed)', (tester) async {
      final fakeAuth = _FakeAuthCubit(const AuthUnauthenticated());

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: fakeAuth,
          child: MaterialApp(
            home: InventoryWorkspaceScreen(
              user: adminUser,
              repository: trackingRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_workspace_export_button')), findsNothing);
      expect(fakeSaver.callCount, equals(0));
    });

    testWidgets('Workspace screen: AuthCubit in AuthFailure hides Export button (fail closed)', (tester) async {
      final fakeAuth = _FakeAuthCubit(const AuthFailure('Authentication connection lost'));

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: fakeAuth,
          child: MaterialApp(
            home: InventoryWorkspaceScreen(
              user: adminUser,
              repository: trackingRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_workspace_export_button')), findsNothing);
      expect(fakeSaver.callCount, equals(0));
    });

    testWidgets('Workspace screen: throwing provider fails closed and hides Export button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(
            user: adminUser,
            currentUserProvider: () => throw StateError('Session store disconnected'),
            repository: trackingRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_workspace_export_button')), findsNothing);
      expect(fakeSaver.callCount, equals(0));
    });

    testWidgets('Workspace screen: AuthCubit in AuthAuthenticated dynamically displays Export button and reacts to logout', (tester) async {
      final fakeAuth = _FakeAuthCubit(AuthAuthenticated(adminUser));

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: fakeAuth,
          child: MaterialApp(
            home: InventoryWorkspaceScreen(
              user: adminUser,
              repository: trackingRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_workspace_export_button')), findsOneWidget);

      // Transition to unauthenticated
      fakeAuth.emitState(const AuthUnauthenticated());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_workspace_export_button')), findsNothing);
      expect(fakeSaver.callCount, equals(0));
    });

    testWidgets('InventoryExportDialog without trusted live provider disables format selection and preparation with 0 repo reads', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: adminUser,
              // No currentUserProvider and no AuthCubit in tree
              repository: trackingRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_export_dialog_unauthenticated_notice')), findsOneWidget);

      final csvTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_csv')),
      );
      final xlsxTile = tester.widget<RadioListTile<InventoryExportFormat>>(
        find.byKey(const Key('inventory_export_format_xlsx')),
      );
      final submitButton = tester.widget<FilledButton>(
        find.byKey(const Key('inventory_export_dialog_submit_button')),
      );

      expect(csvTile.enabled, isFalse);
      expect(xlsxTile.enabled, isFalse);
      expect(submitButton.onPressed, isNull);

      // Verify zero repository reads and zero file saver calls
      expect(trackingRepo.getItemsCount, equals(0));
      expect(fakeSaver.callCount, equals(0));
    });

    testWidgets('InventoryExportDialog with throwing provider denies preparation with 0 repo reads', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: adminUser,
              currentUserProvider: () => throw Exception('Corrupted session'),
              repository: trackingRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submitButton = tester.widget<FilledButton>(
        find.byKey(const Key('inventory_export_dialog_submit_button')),
      );
      expect(submitButton.onPressed, isNull);

      expect(trackingRepo.getItemsCount, equals(0));
      expect(fakeSaver.callCount, equals(0));
    });

    testWidgets('InventoryExportDialog: logout during preparation fails preparation with 0 platform saver calls', (tester) async {
      CurrentUser? liveUser = adminUser;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: adminUser,
              currentUserProvider: () => liveUser,
              repository: trackingRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Log out before tapping prepare
      liveUser = null;

      // Tap prepare
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('User session expired or unauthenticated.'), findsOneWidget);
      expect(trackingRepo.getItemsCount, equals(0));
      expect(fakeSaver.callCount, equals(0));
    });

    testWidgets('InventoryExportDialog: unauthenticated provider blocks delivery with 0 platform saver calls', (tester) async {
      CurrentUser? liveUser = adminUser;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: adminUser,
              currentUserProvider: () => liveUser,
              repository: trackingRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Prepare export while authenticated
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);
      expect(fakeSaver.callCount, equals(0));

      // 2. User logs out before clicking download
      liveUser = null;

      // 3. Attempt download
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      // Verify restricted error and zero saver calls
      expect(find.text('User session expired or unauthenticated.'), findsOneWidget);
      expect(fakeSaver.callCount, equals(0));
    });

    testWidgets('InventoryExportDialog: account switch between prepare and download blocks saver with 0 saver calls', (tester) async {
      CurrentUser? liveUser = adminUser;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryExportDialog(
              user: adminUser,
              currentUserProvider: () => liveUser,
              repository: trackingRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Prepare
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);

      // 2. Switch to another user
      liveUser = CurrentUser(
        id: 'other_user_sec',
        displayName: 'Other User',
        accountType: AccountType.admin,
        modules: {CrmModule.inventory},
        permissions: {},
      );

      // 3. Download
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(find.text('User identity changed since export was prepared.'), findsOneWidget);
      expect(fakeSaver.callCount, equals(0));
    });

    testWidgets('InventoryExportDialog: permission revocation between prepare and download blocks saver with 0 saver calls', (tester) async {
      CurrentUser? liveUser = CurrentUser(
        id: 'usr_csv_perm',
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
          home: Scaffold(
            body: InventoryExportDialog(
              user: liveUser,
              currentUserProvider: () => liveUser,
              repository: trackingRepo,
              fileDeliveryService: deliveryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Prepare
      await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);

      // 2. Revoke inventory.export.csv permission
      liveUser = CurrentUser(
        id: 'usr_csv_perm',
        displayName: 'CSV User',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {
          CrmPermissions.inventoryView,
        },
      );

      // 3. Download
      await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
      await tester.pumpAndSettle();

      expect(find.text("User is not authorized to deliver this export format."), findsOneWidget);
      expect(fakeSaver.callCount, equals(0));
    });
     group('Customizable Export Dialog Tests (INVENTORY-7.5)', () {
      late MockInventoryRepository mockRepo;

      void setScreenSize(WidgetTester tester) {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1200, 1600);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
      }

      setUp(() {
        mockRepo = MockInventoryRepository();
      });

      testWidgets('displays preset selector and record scope options when CSV or Excel is selected', (tester) async {
        setScreenSize(tester);

        final user = makeUser();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InventoryExportDialog(
                user: user,
                currentUserProvider: () => user,
                repository: mockRepo,
                fileDeliveryService: deliveryService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inventory_export_preset_legacy')), findsOneWidget);
        expect(find.byKey(const Key('inventory_export_preset_custom')), findsOneWidget);
        expect(find.byKey(const Key('inventory_export_scope_all')), findsOneWidget);
        expect(find.byKey(const Key('inventory_export_scope_filtered')), findsOneWidget);
        expect(find.byKey(const Key('inventory_export_scope_selected')), findsOneWidget);
      });

      testWidgets('hides preset and column selector when PDF format is selected', (tester) async {
        setScreenSize(tester);

        final user = makeUser(
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportCsv,
            CrmPermissions.inventoryExportXlsx,
            InventoryExportPolicy.exportPdfPermission,
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InventoryExportDialog(
                user: user,
                currentUserProvider: () => user,
                repository: mockRepo,
                fileDeliveryService: deliveryService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to PDF
        await tester.ensureVisible(find.byKey(const Key('inventory_export_format_pdf')));
        await tester.tap(find.byKey(const Key('inventory_export_format_pdf')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inventory_export_preset_legacy')), findsNothing);
        expect(find.byKey(const Key('inventory_export_preset_custom')), findsNothing);
        expect(find.byKey(const Key('inventory_export_scope_all')), findsNothing);
        expect(find.text('Printable report with frozen three columns (Item Name, SKU, Current Quantity).'), findsOneWidget);
      });

      testWidgets('switching to custom preset reveals column selection and reordering controls', (tester) async {
        setScreenSize(tester);

        final user = makeUser();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InventoryExportDialog(
                user: user,
                currentUserProvider: () => user,
                repository: mockRepo,
                fileDeliveryService: deliveryService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Custom Preset
        await tester.ensureVisible(find.byKey(const Key('inventory_export_preset_custom')));
        await tester.tap(find.byKey(const Key('inventory_export_preset_custom')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inventory_export_select_all_columns')), findsOneWidget);
        expect(find.byKey(const Key('inventory_export_deselect_all_columns')), findsOneWidget);
        expect(find.byKey(const Key('inventory_export_col_sku')), findsOneWidget);
        expect(find.byKey(const Key('inventory_export_col_product_name')), findsOneWidget);
      });

      testWidgets('deselecting all columns disables submit button', (tester) async {
        setScreenSize(tester);

        final user = makeUser();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InventoryExportDialog(
                user: user,
                currentUserProvider: () => user,
                repository: mockRepo,
                fileDeliveryService: deliveryService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Custom Preset
        await tester.ensureVisible(find.byKey(const Key('inventory_export_preset_custom')));
        await tester.tap(find.byKey(const Key('inventory_export_preset_custom')));
        await tester.pumpAndSettle();

        // Tap Deselect All
        await tester.ensureVisible(find.byKey(const Key('inventory_export_deselect_all_columns')));
        await tester.tap(find.byKey(const Key('inventory_export_deselect_all_columns')));
        await tester.pumpAndSettle();

        final submitButton = tester.widget<FilledButton>(
          find.byKey(const Key('inventory_export_dialog_submit_button')),
        );
        expect(submitButton.onPressed, isNull);
      });

      testWidgets('selected scope with 0 selected items disables submit button', (tester) async {
        setScreenSize(tester);

        final user = makeUser();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InventoryExportDialog(
                user: user,
                currentUserProvider: () => user,
                repository: mockRepo,
                fileDeliveryService: deliveryService,
                selectedItemIds: {}, // empty
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Selected Scope
        await tester.ensureVisible(find.byKey(const Key('inventory_export_scope_selected')));
        await tester.tap(find.byKey(const Key('inventory_export_scope_selected')));
        await tester.pumpAndSettle();

        final submitButton = tester.widget<FilledButton>(
          find.byKey(const Key('inventory_export_dialog_submit_button')),
        );
        expect(submitButton.onPressed, isNull);
      });

      testWidgets('changing preset after preparation resets prepared state and requires re-preparation', (tester) async {
        setScreenSize(tester);

        final user = makeUser();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InventoryExportDialog(
                user: user,
                currentUserProvider: () => user,
                repository: mockRepo,
                fileDeliveryService: deliveryService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Prepare legacy export
        await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);

        // 2. Switch preset to custom
        await tester.ensureVisible(find.byKey(const Key('inventory_export_preset_custom')));
        await tester.tap(find.byKey(const Key('inventory_export_preset_custom')));
        await tester.pumpAndSettle();

        // 3. Download button disappears, submit button reappears
        expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsNothing);
        expect(find.byKey(const Key('inventory_export_dialog_submit_button')), findsOneWidget);
      });

      testWidgets('custom export flow prepares and downloads CSV with custom columns', (tester) async {
        setScreenSize(tester);

        final user = makeUser();
        fakeSaver.returnUri = Uri.parse('file:///storage/custom.csv');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InventoryExportDialog(
                user: user,
                currentUserProvider: () => user,
                repository: mockRepo,
                fileDeliveryService: deliveryService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Custom Preset
        await tester.ensureVisible(find.byKey(const Key('inventory_export_preset_custom')));
        await tester.tap(find.byKey(const Key('inventory_export_preset_custom')));
        await tester.pumpAndSettle();

        // Tap prepare
        await tester.tap(find.byKey(const Key('inventory_export_dialog_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inventory_export_dialog_download_button')), findsOneWidget);

        // Tap download
        await tester.tap(find.byKey(const Key('inventory_export_dialog_download_button')));
        await tester.pumpAndSettle();

        expect(fakeSaver.callCount, equals(1));
        expect(fakeSaver.lastExtension, equals('csv'));
        expect(find.text('Inventory exported successfully.'), findsOneWidget);
      });
    });
  });
}
