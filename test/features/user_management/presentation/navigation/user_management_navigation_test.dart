import 'package:enterprise_crm/app/crm_app.dart';
import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/user_management/data/repositories/mock_user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/managed_user.dart';
import 'package:enterprise_crm/features/user_management/domain/repositories/user_management_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_dashboard_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_lead_placeholder_screen.dart';
import 'package:enterprise_crm/features/user_management/presentation/screens/create_user_screen.dart';
import 'package:enterprise_crm/features/user_management/presentation/screens/user_details_screen.dart';
import 'package:enterprise_crm/features/user_management/presentation/screens/users_and_access_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enterprise_crm/features/user_management/data/mock/mock_account_store.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/user_account_status.dart';
import 'package:enterprise_crm/features/user_management/domain/inputs/create_managed_user_input.dart';
import 'package:enterprise_crm/features/user_management/domain/inputs/update_managed_user_input.dart';
import '../../../../helpers/mock_auth_test_fixtures.dart';

/// Spy repository tracking calls to [getUsers].
class _UserManagementRepoSpy implements UserManagementRepository {
  int getUsersCallCount = 0;

  @override
  Future<List<ManagedUser>> getUsers() async {
    getUsersCallCount++;
    return MockUserManagementRepository.defaultSeeds;
  }

  @override
  Future<ManagedUser?> getUserById(String id) async => null;

  @override
  Future<ManagedUser?> findUserByUserId(String userId) async => null;

  @override
  Future<ManagedUser> createUser(
    CreateManagedUserInput input, {
    required String temporaryPassword,
  }) => throw UnimplementedError();

  @override
  Future<ManagedUser> updateUser(UpdateManagedUserInput input) =>
      throw UnimplementedError();

  @override
  Future<ManagedUser> setUserStatus({
    required String id,
    required UserAccountStatus status,
  }) => throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String id,
    required String newPassword,
  }) => throw UnimplementedError();
}

void main() {
  group('User Management Navigation & Route Guard Integration Tests', () {
    late MockLeadRepository leadRepository;
    late MockAuthRepository authRepository;
    late MockUserManagementRepository userManagementRepository;
    late MockAccountStore accountStore;

    setUp(() {
      leadRepository = MockLeadRepository();
      accountStore = MockAccountStore.seeded();
      authRepository = MockAuthRepository(accountStore: accountStore);
      userManagementRepository = MockUserManagementRepository(
        accountStore: accountStore,
      );
    });

    testWidgets(
      'ADMIN END-TO-END FLOW: Login -> Admin Dashboard -> Users & Access -> User Details -> Back -> Users & Access -> Back -> Admin Dashboard',
      (tester) async {
        await tester.pumpWidget(
          CrmApp(
            leadRepository: leadRepository,
            authRepository: authRepository,
            userManagementRepository: userManagementRepository,
          ),
        );
        await tester.pumpAndSettle();

        // Login as Admin
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

        // Tap Users & Access
        await tester.ensureVisible(
          find.byKey(const Key('admin_card_users_and_access')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('admin_card_users_and_access')));
        await tester.pumpAndSettle();

        // Verified on UsersAndAccessScreen
        expect(find.byType(UsersAndAccessScreen), findsOneWidget);
        expect(find.text('USER DIRECTORY'), findsOneWidget);

        // Tap View for Standard User
        await tester.ensureVisible(
          find.byKey(const Key('user_view_button_usr_standard')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('user_view_button_usr_standard')),
        );
        await tester.pumpAndSettle();

        // Verified on UserDetailsScreen
        expect(find.byType(UserDetailsScreen), findsOneWidget);
        expect(find.text('Standard User'), findsWidgets);
        expect(find.text('MODULE ACCESS'), findsOneWidget);

        // Back from UserDetailsScreen to UsersAndAccessScreen
        await tester.ensureVisible(
          find.byKey(const Key('user_details_back_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('user_details_back_button')));
        await tester.pumpAndSettle();

        expect(find.byType(UsersAndAccessScreen), findsOneWidget);
        expect(find.byType(UserDetailsScreen), findsNothing);

        // Back from UsersAndAccessScreen to AdminDashboardScreen
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(AdminDashboardScreen), findsOneWidget);
        expect(find.byType(UsersAndAccessScreen), findsNothing);
      },
    );

    testWidgets(
      'CORRECTION 3: Route guard rejects non-Admin access BEFORE loading cubit, making ZERO getUsers() calls',
      (tester) async {
        final repoSpy = _UserManagementRepoSpy();
        final nonAdminUser = MockAuthTestFixtures.standardUser;
        expect(nonAdminUser.isAdmin, isFalse);

        await tester.pumpWidget(
          MaterialApp(
            home: UsersAndAccessScreen(user: nonAdminUser, repository: repoSpy),
          ),
        );
        await tester.pumpAndSettle();

        // Verified: Access restricted screen is rendered
        expect(find.text('Access Restricted'), findsOneWidget);
        expect(
          find.text(
            'You do not have administrative privileges to access this area.',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('users_and_access_unauthorized_screen')),
          findsOneWidget,
        );

        // Verified: Directory content is NOT rendered
        expect(find.text('USER DIRECTORY'), findsNothing);
        expect(find.byKey(const Key('user_search_field')), findsNothing);

        // CRITICAL CHECK: Exactly 0 calls to repository.getUsers()
        expect(
          repoSpy.getUsersCallCount,
          0,
          reason: 'Non-admin access MUST NOT invoke repository.getUsers()',
        );
      },
    );

    testWidgets(
      'CORRECTION 3: UserDetailsScreen also rejects non-Admin access',
      (tester) async {
        final nonAdminUser = MockAuthTestFixtures.standardUser;
        final managedUser = MockUserManagementRepository.defaultSeeds.first;

        await tester.pumpWidget(
          MaterialApp(
            home: UserDetailsScreen(
              currentUser: nonAdminUser,
              user: managedUser,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verified: Access restricted screen is rendered
        expect(find.text('Access Restricted'), findsOneWidget);
        expect(
          find.text(
            'You do not have administrative privileges to view user details.',
          ),
          findsOneWidget,
        );
        expect(find.text('MODULE ACCESS'), findsNothing);
      },
    );

    testWidgets(
      'CORRECTION 2: CrmApp asserts userManagementRepository != null when auth is enabled',
      (tester) async {
        expect(
          () => CrmApp(
            leadRepository: leadRepository,
            authRepository: authRepository,
            userManagementRepository: null,
          ),
          throwsAssertionError,
        );
      },
    );

    testWidgets(
      'AUTH-2B.2 END-TO-END WORKFLOW: Admin creates sales_01 with Lead Management + Calling -> logs out -> sales_01 logs in -> sees assigned modules on User Dashboard -> Lead Management opens restricted placeholder',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          CrmApp(
            leadRepository: leadRepository,
            authRepository: authRepository,
            userManagementRepository: userManagementRepository,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Admin login
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

        // 2. Open Users & Access
        await tester.tap(find.byKey(const Key('admin_card_users_and_access')));
        await tester.pumpAndSettle();
        expect(find.byType(UsersAndAccessScreen), findsOneWidget);

        // 3. Tap + Create User
        await tester.tap(find.byKey(const Key('create_user_button')));
        await tester.pumpAndSettle();
        expect(find.byType(CreateUserScreen), findsOneWidget);

        // 4. Fill form
        await tester.enterText(
          find.byKey(const Key('create_user_id_field')),
          'sales_01',
        );
        await tester.enterText(
          find.byKey(const Key('create_user_display_name_field')),
          'Sales 01',
        );
        await tester.enterText(
          find.byKey(const Key('create_user_password_field')),
          'temp123',
        );

        // Assign Lead Management + Calling
        await tester.tap(
          find.byKey(
            Key('create_user_module_${CrmModule.leadManagement.name}'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(Key('create_user_module_${CrmModule.calling.name}')),
        );
        await tester.pumpAndSettle();

        // Save
        await tester.tap(find.byKey(const Key('create_user_submit_button')));
        await tester.pumpAndSettle();

        // Returns to Users & Access and directory contains sales_01
        expect(find.byType(UsersAndAccessScreen), findsOneWidget);
        expect(find.text('Sales 01'), findsWidgets);
        expect(find.text('@sales_01'), findsOneWidget);

        // 5. Back to Admin Dashboard and logout
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(AdminDashboardScreen), findsOneWidget);

        await tester.tap(find.byKey(const Key('crm_header_logout_button')));
        await tester.pumpAndSettle();

        // 6. Login as sales_01 with temporary password
        await tester.enterText(
          find.byKey(const Key('login_user_id_field')),
          'sales_01',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'temp123',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // 7. Verified on UserDashboardScreen
        expect(find.byType(UserDashboardScreen), findsOneWidget);
        expect(find.text('Sales 01'), findsWidgets);

        // Assigned modules must be visible
        expect(
          find.byKey(Key('module_card_${CrmModule.leadManagement.name}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('module_card_${CrmModule.calling.name}')),
          findsOneWidget,
        );

        // Modules not assigned must NOT be present
        expect(
          find.byKey(Key('module_card_${CrmModule.inventory.name}')),
          findsNothing,
        );
        expect(
          find.byKey(Key('module_card_${CrmModule.dispatch.name}')),
          findsNothing,
        );

        // 8. Tapping Lead Management opens restricted placeholder (AUTH-3 boundary invariant)
        await tester.tap(
          find.byKey(Key('module_card_${CrmModule.leadManagement.name}')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserLeadPlaceholderScreen), findsOneWidget);
      },
    );

    testWidgets(
      'AUTH-2B.2 ZERO-MODULE USER: Admin creates user with 0 modules -> user logs in and sees empty state',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          CrmApp(
            leadRepository: leadRepository,
            authRepository: authRepository,
            userManagementRepository: userManagementRepository,
          ),
        );
        await tester.pumpAndSettle();

        // Admin login
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

        // Open Users & Access -> Create User
        await tester.tap(find.byKey(const Key('admin_card_users_and_access')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('create_user_button')));
        await tester.pumpAndSettle();

        // Create zero-module user
        await tester.enterText(
          find.byKey(const Key('create_user_id_field')),
          'zero_user',
        );
        await tester.enterText(
          find.byKey(const Key('create_user_display_name_field')),
          'Zero Module User',
        );
        await tester.enterText(
          find.byKey(const Key('create_user_password_field')),
          'zero123',
        );
        await tester.tap(find.byKey(const Key('create_user_submit_button')));
        await tester.pumpAndSettle();

        // Back to Dashboard and logout
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('crm_header_logout_button')));
        await tester.pumpAndSettle();

        // Login as zero_user
        await tester.enterText(
          find.byKey(const Key('login_user_id_field')),
          'zero_user',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'zero123',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byType(UserDashboardScreen), findsOneWidget);
        expect(
          find.text('No modules are currently assigned to this account.'),
          findsOneWidget,
        );
      },
    );
  });
}
