import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/module_placeholder_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_dashboard_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_lead_workspace_screen.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/user_management/data/mock/mock_account_store.dart';
import 'package:enterprise_crm/features/user_management/data/repositories/mock_user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/managed_user.dart';
import 'package:enterprise_crm/features/user_management/domain/inputs/update_managed_user_input.dart';
import 'package:enterprise_crm/features/user_management/presentation/screens/users_and_access_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpyUserManagementRepository extends MockUserManagementRepository {
  int getUsersCallCount = 0;

  _SpyUserManagementRepository(MockAccountStore accountStore)
    : super(accountStore: accountStore);

  @override
  Future<List<ManagedUser>> getUsers() {
    getUsersCallCount++;
    return super.getUsers();
  }
}

void main() {
  group('Module Route Guard & Authorization Invariants', () {
    testWidgets(
      'Zero-module user sees empty state and no administration controls',
      (tester) async {
        const zeroModuleUser = CurrentUser(
          id: 'usr_zero',
          displayName: 'Zero User',
          accountType: AccountType.user,
          modules: {},
          permissions: {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: UserDashboardScreen(
              user: zeroModuleUser,
              onLogout: () {},
              userLeadLinkRepository: MockUserLeadLinkRepository(),
              leadRepository: MockLeadRepository(),
              callActivityRepository: MockLeadCallActivityRepository(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('USER DASHBOARD'), findsOneWidget);
        expect(find.byKey(const Key('user_no_modules_card')), findsOneWidget);
        expect(
          find.text('No modules have been assigned to your account.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('user_assigned_modules_grid')),
          findsNothing,
        );
        expect(find.text('Users & Access'), findsNothing);
        expect(find.text('ADMINISTRATION'), findsNothing);
      },
    );

    testWidgets(
      'Dynamic store mutation reflects in next login and protects newly revoked modules',
      (tester) async {
        final store = MockAccountStore.seeded();
        final authRepo = MockAuthRepository(accountStore: store);

        // 1. Initial user has Lead Management and Calling
        final initialUser = (await tester.runAsync(
          () => authRepo.login(userId: 'user', password: 'user123'),
        ))!;
        expect(
          initialUser.modules,
          containsAll({CrmModule.leadManagement, CrmModule.calling}),
        );

        // 2. Admin mutates user's modules in shared store to HR and Inventory only
        store.updateUser(
          UpdateManagedUserInput(
            id: 'usr_standard',
            displayName: 'Standard User',
            modules: {CrmModule.hrPayroll, CrmModule.inventory},
            permissions: {CrmPermissions.hrView, CrmPermissions.inventoryView},
          ),
        );

        // 3. User logs in again to establish new session
        final updatedUser = (await tester.runAsync(
          () => authRepo.login(userId: 'user', password: 'user123'),
        ))!;

        // 4. Verify updated modules on dashboard
        await tester.pumpWidget(
          MaterialApp(
            home: UserDashboardScreen(
              user: updatedUser,
              onLogout: () {},
              userLeadLinkRepository: MockUserLeadLinkRepository(),
              leadRepository: MockLeadRepository(),
              callActivityRepository: MockLeadCallActivityRepository(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('module_card_hrPayroll')), findsOneWidget);
        expect(find.byKey(const Key('module_card_inventory')), findsOneWidget);
        expect(
          find.byKey(const Key('module_card_leadManagement')),
          findsNothing,
        );
        expect(find.byKey(const Key('module_card_calling')), findsNothing);

        // 5. Attempt direct navigation to previously assigned Lead Management module
        await tester.pumpWidget(
          MaterialApp(
            home: UserLeadWorkspaceScreen(
              user: updatedUser,
              linkRepository: MockUserLeadLinkRepository(),
              leadRepository: MockLeadRepository(),
              callActivityRepository: MockLeadCallActivityRepository(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.text('Access Restricted'), findsOneWidget);
        expect(find.text('LEAD MANAGEMENT'), findsNothing);

        // 6. Attempt direct navigation to previously assigned Calling module
        await tester.pumpWidget(
          MaterialApp(
            home: ModulePlaceholderScreen(
              module: CrmModule.calling,
              user: updatedUser,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.text('Access Restricted'), findsOneWidget);
        expect(find.text('Access granted.'), findsNothing);
      },
    );

    testWidgets(
      'Unauthorized access attempt to UsersAndAccessScreen prevents repository initialization',
      (tester) async {
        final store = MockAccountStore.seeded();
        final spyRepo = _SpyUserManagementRepository(store);

        const standardUser = CurrentUser(
          id: 'usr_user',
          displayName: 'Standard User',
          accountType: AccountType.user,
          modules: {CrmModule.leadManagement},
          permissions: {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: UsersAndAccessScreen(user: standardUser, repository: spyRepo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Access Restricted'), findsOneWidget);
        // Spy must have recorded exactly 0 calls
        expect(spyRepo.getUsersCallCount, 0);
      },
    );
  });
}
