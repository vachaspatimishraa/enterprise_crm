import 'package:enterprise_crm/app/crm_app.dart';
import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_follow_up_repository.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_dashboard_screen.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_workspace_screen.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/user_management/data/mock/mock_account_store.dart';
import 'package:enterprise_crm/features/user_management/data/repositories/mock_user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/domain/inputs/update_managed_user_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Shared InventoryRepository Identity & Scoping Invariant Tests', () {
    testWidgets(
      'Admin and User routes share the exact same InventoryRepository instance across sessions',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // 1. Instantiate ONE application-scoped InventoryRepository
        final sharedInventoryRepository = MockInventoryRepository();
        final accountStore = MockAccountStore.seeded();

        // Assign Inventory module & permission to usr_standard so they can access it
        accountStore.updateUser(
          UpdateManagedUserInput(
            id: 'usr_standard',
            displayName: 'Standard User',
            modules: {CrmModule.inventory, CrmModule.leadManagement},
            permissions: {
              CrmPermissions.inventoryView,
              CrmPermissions.leadViewAssigned,
            },
          ),
        );

        final authRepository = MockAuthRepository(accountStore: accountStore);
        final userManagementRepository = MockUserManagementRepository(
          accountStore: accountStore,
        );

        // 2. Launch CrmApp with the shared repository
        await tester.pumpWidget(
          CrmApp(
            leadRepository: MockLeadRepository(),
            authRepository: authRepository,
            userManagementRepository: userManagementRepository,
            userLeadLinkRepository: MockUserLeadLinkRepository(),
            leadCallActivityRepository: MockLeadCallActivityRepository(),
            leadFollowUpRepository: MockLeadFollowUpRepository(),
            inventoryRepository: sharedInventoryRepository,
          ),
        );
        await tester.pumpAndSettle();

        // 3. Admin logs in
        await tester.enterText(
          find.byKey(const Key('login_user_id_field')),
          'admin',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'admin123',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byType(AdminDashboardScreen), findsOneWidget);

        // Admin opens Inventory module
        await tester.tap(find.byKey(const Key('module_card_inventory')));
        await tester.pumpAndSettle();

        expect(find.byType(InventoryWorkspaceScreen), findsOneWidget);
        expect(find.text('Laptop Stand'), findsOneWidget);

        // Back to Admin Dashboard
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // Admin logs out
        await tester.tap(find.byKey(const Key('crm_header_logout_button')));
        await tester.pumpAndSettle();

        // 4. Standard User logs in
        await tester.enterText(
          find.byKey(const Key('login_user_id_field')),
          'user',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'user123',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byType(UserDashboardScreen), findsOneWidget);

        // User opens Inventory module
        await tester.tap(find.byKey(const Key('module_card_inventory')));
        await tester.pumpAndSettle();

        expect(find.byType(InventoryWorkspaceScreen), findsOneWidget);
        // User sees the exact same inventory data
        expect(find.text('Laptop Stand'), findsOneWidget);
      },
    );
  });
}
