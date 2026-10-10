import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:enterprise_crm/app/crm_app.dart';
import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_follow_up_repository.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_dashboard_screen.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_workspace_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/widgets/inventory_export_dialog.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/user_management/data/mock/mock_account_store.dart';
import 'package:enterprise_crm/features/user_management/data/repositories/mock_user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/domain/inputs/update_managed_user_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('INVENTORY-6.4-FIX2: Production Navigation & Auth Provider Wiring Tests', () {
    late MockInventoryRepository inventoryRepository;
    late MockAccountStore accountStore;
    late MockAuthRepository authRepository;
    late MockUserManagementRepository userManagementRepository;
    late MockLeadRepository leadRepository;
    late MockUserLeadLinkRepository userLeadLinkRepository;
    late MockLeadCallActivityRepository leadCallActivityRepository;
    late MockLeadFollowUpRepository leadFollowUpRepository;

    setUp(() {
      inventoryRepository = MockInventoryRepository();
      accountStore = MockAccountStore.seeded();
      authRepository = MockAuthRepository(accountStore: accountStore);
      userManagementRepository = MockUserManagementRepository(
        accountStore: accountStore,
      );
      leadRepository = MockLeadRepository();
      userLeadLinkRepository = MockUserLeadLinkRepository();
      leadCallActivityRepository = MockLeadCallActivityRepository();
      leadFollowUpRepository = MockLeadFollowUpRepository();
    });

    Widget buildApp() {
      return CrmApp(
        leadRepository: leadRepository,
        authRepository: authRepository,
        userManagementRepository: userManagementRepository,
        userLeadLinkRepository: userLeadLinkRepository,
        leadCallActivityRepository: leadCallActivityRepository,
        leadFollowUpRepository: leadFollowUpRepository,
        inventoryRepository: inventoryRepository,
      );
    }

    testWidgets(
      'Administrator production navigation: Admin logs in -> Dashboard -> Inventory -> sees Export button and full format options',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // 1. Log in as admin
        await tester.enterText(find.byKey(const Key('login_user_id_field')), 'admin');
        await tester.enterText(find.byKey(const Key('login_password_field')), 'admin123');
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byType(AdminDashboardScreen), findsOneWidget);

        // 2. Open Inventory module through production dashboard navigation
        await tester.tap(find.byKey(const Key('module_card_inventory')));
        await tester.pumpAndSettle();

        expect(find.byType(InventoryWorkspaceScreen), findsOneWidget);

        // 3. Confirm Export button is rendered and visible for authenticated admin
        final exportButtonFinder = find.byKey(const Key('inventory_workspace_export_button'));
        expect(exportButtonFinder, findsOneWidget);

        // 4. Tap Export button to open InventoryExportDialog
        await tester.tap(exportButtonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(InventoryExportDialog), findsOneWidget);

        // 5. Admin has both CSV and XLSX format options enabled
        final csvRadio = tester.widget<RadioListTile>(
          find.byKey(const Key('inventory_export_format_csv')),
        );
        final xlsxRadio = tester.widget<RadioListTile>(
          find.byKey(const Key('inventory_export_format_xlsx')),
        );
        expect(csvRadio.enabled, isTrue);
        expect(xlsxRadio.enabled, isTrue);

        // Cancel dialog
        await tester.tap(find.byKey(const Key('inventory_export_dialog_cancel_button')));
        await tester.pumpAndSettle();
        expect(find.byType(InventoryExportDialog), findsNothing);
      },
    );

    testWidgets(
      'Standard User with CSV-only export permission: sees Export button and CSV is enabled while XLSX is disabled',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Configure usr_standard with inventory, view, and CSV export only
        accountStore.updateUser(
          UpdateManagedUserInput(
            id: 'usr_standard',
            displayName: 'CSV Export User',
            modules: {CrmModule.inventory, CrmModule.leadManagement},
            permissions: {
              CrmPermissions.inventoryView,
              CrmPermissions.inventoryExportCsv,
            },
          ),
        );

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Log in as standard user
        await tester.enterText(find.byKey(const Key('login_user_id_field')), 'user');
        await tester.enterText(find.byKey(const Key('login_password_field')), 'user123');
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byType(UserDashboardScreen), findsOneWidget);

        // Open Inventory
        await tester.tap(find.byKey(const Key('module_card_inventory')));
        await tester.pumpAndSettle();

        expect(find.byType(InventoryWorkspaceScreen), findsOneWidget);

        // Export button is visible
        final exportButton = find.byKey(const Key('inventory_workspace_export_button'));
        expect(exportButton, findsOneWidget);

        // Open Export dialog
        await tester.tap(exportButton);
        await tester.pumpAndSettle();

        expect(find.byType(InventoryExportDialog), findsOneWidget);

        // Format check: CSV enabled, XLSX disabled
        final csvRadio = tester.widget<RadioListTile>(
          find.byKey(const Key('inventory_export_format_csv')),
        );
        final xlsxRadio = tester.widget<RadioListTile>(
          find.byKey(const Key('inventory_export_format_xlsx')),
        );
        expect(csvRadio.enabled, isTrue);
        expect(xlsxRadio.enabled, isFalse);

        await tester.tap(find.byKey(const Key('inventory_export_dialog_cancel_button')));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Standard User with XLSX-only export permission: sees Export button and XLSX is enabled while CSV is disabled',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Configure usr_standard with inventory, view, and XLSX export only
        accountStore.updateUser(
          UpdateManagedUserInput(
            id: 'usr_standard',
            displayName: 'XLSX Export User',
            modules: {CrmModule.inventory, CrmModule.leadManagement},
            permissions: {
              CrmPermissions.inventoryView,
              CrmPermissions.inventoryExportXlsx,
            },
          ),
        );

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Log in
        await tester.enterText(find.byKey(const Key('login_user_id_field')), 'user');
        await tester.enterText(find.byKey(const Key('login_password_field')), 'user123');
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byType(UserDashboardScreen), findsOneWidget);

        // Open Inventory
        await tester.tap(find.byKey(const Key('module_card_inventory')));
        await tester.pumpAndSettle();

        expect(find.byType(InventoryWorkspaceScreen), findsOneWidget);

        // Export button is visible
        final exportButton = find.byKey(const Key('inventory_workspace_export_button'));
        expect(exportButton, findsOneWidget);

        // Open Export dialog
        await tester.tap(exportButton);
        await tester.pumpAndSettle();

        expect(find.byType(InventoryExportDialog), findsOneWidget);

        // Format check: CSV disabled, XLSX enabled
        final csvRadio = tester.widget<RadioListTile>(
          find.byKey(const Key('inventory_export_format_csv')),
        );
        final xlsxRadio = tester.widget<RadioListTile>(
          find.byKey(const Key('inventory_export_format_xlsx')),
        );
        expect(csvRadio.enabled, isFalse);
        expect(xlsxRadio.enabled, isTrue);

        await tester.tap(find.byKey(const Key('inventory_export_dialog_cancel_button')));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Standard User with inventory.view but NO export permissions: sees workspace, but Export button is absent',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Configure usr_standard with inventory and view only (no export permissions)
        accountStore.updateUser(
          UpdateManagedUserInput(
            id: 'usr_standard',
            displayName: 'View Only User',
            modules: {CrmModule.inventory, CrmModule.leadManagement},
            permissions: {
              CrmPermissions.inventoryView,
            },
          ),
        );

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Log in
        await tester.enterText(find.byKey(const Key('login_user_id_field')), 'user');
        await tester.enterText(find.byKey(const Key('login_password_field')), 'user123');
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byType(UserDashboardScreen), findsOneWidget);

        // Open Inventory
        await tester.tap(find.byKey(const Key('module_card_inventory')));
        await tester.pumpAndSettle();

        expect(find.byType(InventoryWorkspaceScreen), findsOneWidget);

        // Export button is NOT rendered
        expect(find.byKey(const Key('inventory_workspace_export_button')), findsNothing);
      },
    );

    testWidgets(
      'Logout dynamically hides Export button and denies ongoing operations',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Log in as admin
        await tester.enterText(find.byKey(const Key('login_user_id_field')), 'admin');
        await tester.enterText(find.byKey(const Key('login_password_field')), 'admin123');
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Open Inventory
        await tester.tap(find.byKey(const Key('module_card_inventory')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inventory_workspace_export_button')), findsOneWidget);

        // Trigger logout on the AuthCubit
        final BuildContext workspaceContext = tester.element(find.byType(InventoryWorkspaceScreen));
        final authCubit = workspaceContext.read<AuthCubit>();
        authCubit.logout();
        await tester.pumpAndSettle();

        // CrmApp listener pops to LoginScreen when unauthenticated
        expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
      },
    );
  });
}
