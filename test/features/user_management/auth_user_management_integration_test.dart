import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_follow_up_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/repositories/auth_repository.dart';
import 'package:enterprise_crm/features/user_management/data/mock/mock_account_store.dart';
import 'package:enterprise_crm/features/user_management/data/repositories/mock_user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/user_account_status.dart';
import 'package:enterprise_crm/features/user_management/domain/inputs/create_managed_user_input.dart';
import 'package:enterprise_crm/features/user_management/domain/inputs/update_managed_user_input.dart';
import 'package:enterprise_crm/features/user_management/domain/repositories/user_management_repository.dart';
import 'package:enterprise_crm/app/crm_app.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_dashboard_screen.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth & User Management Integration Tests (AUTH-2B.1)', () {
    late MockAccountStore accountStore;
    late MockAuthRepository authRepo;
    late MockUserManagementRepository userMgmtRepo;

    setUp(() {
      accountStore = MockAccountStore.seeded();
      authRepo = MockAuthRepository(accountStore: accountStore);
      userMgmtRepo = MockUserManagementRepository(accountStore: accountStore);
    });

    test(
      'INTEGRATION 1: Create user through UserManagementRepository -> Login through AuthRepository',
      () async {
        // 1. Admin creates user in UserManagementRepository
        final created = await userMgmtRepo.createUser(
          CreateManagedUserInput(
            userId: 'sales_agent',
            displayName: 'Sales Agent',
            modules: {CrmModule.leadManagement, CrmModule.calling},
            permissions: {'lead.view_assigned', 'calling.use'},
          ),
          temporaryPassword: 'initialPassword123',
        );

        expect(created.userId, 'sales_agent');
        expect(created.accountType, AccountType.user);

        // 2. Newly created user logs in through AuthRepository
        final sessionUser = await authRepo.login(
          userId: 'sales_agent',
          password: 'initialPassword123',
        );

        // 3. CurrentUser reflects exactly the assigned modules and permissions
        expect(sessionUser.id, 'sales_agent');
        expect(sessionUser.displayName, 'Sales Agent');
        expect(sessionUser.accountType, AccountType.user);
        expect(sessionUser.modules, {
          CrmModule.leadManagement,
          CrmModule.calling,
        });
        expect(sessionUser.permissions, {'lead.view_assigned', 'calling.use'});
        expect(authRepo.currentUser, equals(sessionUser));
      },
    );

    test(
      'INTEGRATION 2: Update user modules in repository -> Re-login reflects updated modules and pruned permissions',
      () async {
        // 1. Initial user login
        final initialSession = await authRepo.login(
          userId: 'user',
          password: 'user123',
        );
        expect(initialSession.modules, contains(CrmModule.leadManagement));
        expect(initialSession.permissions, contains('lead.view_assigned'));
        await authRepo.logout();

        // 2. Admin mutates user in UserManagementRepository: removes leadManagement, assigns hrPayroll
        await userMgmtRepo.updateUser(
          UpdateManagedUserInput(
            id: 'usr_standard',
            displayName: 'Standard User (Promoted)',
            modules: {CrmModule.hrPayroll},
            permissions: {
              'hr.view',
              'lead.view_assigned',
            }, // lead perm should be pruned
          ),
        );

        // 3. User logs in again
        final updatedSession = await authRepo.login(
          userId: 'user',
          password: 'user123',
        );

        // 4. CurrentUser strictly derived from shared store state
        expect(updatedSession.displayName, 'Standard User (Promoted)');
        expect(updatedSession.modules, {CrmModule.hrPayroll});
        expect(
          updatedSession.modules.contains(CrmModule.leadManagement),
          isFalse,
        );
        expect(updatedSession.permissions, {'hr.view'});
        expect(
          updatedSession.permissions.contains('lead.view_assigned'),
          isFalse,
        );
      },
    );

    test(
      'INTEGRATION 3: Disable user in repository -> Login rejected -> Re-enable -> Login succeeds',
      () async {
        // 1. User can initially log in
        await authRepo.login(userId: 'user', password: 'user123');
        await authRepo.logout();

        // 2. Admin disables user in UserManagementRepository
        await userMgmtRepo.setUserStatus(
          id: 'usr_standard',
          status: UserAccountStatus.disabled,
        );

        // 3. Login attempt fails with safe AuthException without leaking account status
        expect(
          () => authRepo.login(userId: 'user', password: 'user123'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'Invalid User ID or password.',
            ),
          ),
        );
        expect(authRepo.currentUser, isNull);

        // 4. Admin re-enables user in UserManagementRepository
        await userMgmtRepo.setUserStatus(
          id: 'usr_standard',
          status: UserAccountStatus.active,
        );

        // 5. Login succeeds again
        final reEnabledSession = await authRepo.login(
          userId: 'user',
          password: 'user123',
        );
        expect(reEnabledSession.id, 'user');
        expect(authRepo.currentUser, isNotNull);
      },
    );

    test(
      'INTEGRATION 4: Password reset in repository -> Old password rejected -> New password accepted',
      () async {
        // 1. Initial password works
        await authRepo.login(userId: 'user', password: 'user123');
        await authRepo.logout();

        // 2. Admin resets password in UserManagementRepository
        await userMgmtRepo.resetPassword(
          id: 'usr_standard',
          newPassword: 'brandNewSecurePassword456',
        );

        // 3. Old password fails
        expect(
          () => authRepo.login(userId: 'user', password: 'user123'),
          throwsA(isA<AuthException>()),
        );

        // 4. New password succeeds
        final newSession = await authRepo.login(
          userId: 'user',
          password: 'brandNewSecurePassword456',
        );
        expect(newSession.id, 'user');
      },
    );

    test(
      'INTEGRATION 5: Password reset establishes login for directory-only account',
      () async {
        // 1. hr_user initially has no credential
        expect(
          () => authRepo.login(userId: 'hr_user', password: 'any'),
          throwsA(isA<AuthException>()),
        );

        // 2. Admin resets/establishes password in UserManagementRepository
        await userMgmtRepo.resetPassword(
          id: 'usr_hr',
          newPassword: 'hrEstablishedPassword',
        );

        // 3. hr_user can now log in
        final hrSession = await authRepo.login(
          userId: 'hr_user',
          password: 'hrEstablishedPassword',
        );
        expect(hrSession.id, 'hr_user');
        expect(hrSession.displayName, 'HR User');
        expect(hrSession.modules, {CrmModule.hrPayroll});
        expect(hrSession.permissions, {'hr.view', 'payroll.view'});
      },
    );

    test(
      'INTEGRATION 6: Master Administrator protection across repositories',
      () async {
        // Cannot disable Master Admin
        expect(
          () => userMgmtRepo.setUserStatus(
            id: 'usr_admin',
            status: UserAccountStatus.disabled,
          ),
          throwsA(
            isA<UserManagementException>().having(
              (e) => e.message,
              'message',
              contains('Master Administrator account cannot be disabled'),
            ),
          ),
        );

        // Cannot modify Master Admin modules
        expect(
          () => userMgmtRepo.updateUser(
            UpdateManagedUserInput(
              id: 'usr_admin',
              displayName: 'Administrator',
              modules: {CrmModule.leadManagement},
            ),
          ),
          throwsA(isA<UserManagementException>()),
        );

        // Admin password reset is allowed as an administrative operation
        await userMgmtRepo.resetPassword(
          id: 'usr_admin',
          newPassword: 'newAdminPassword123',
        );

        final adminSession = await authRepo.login(
          userId: 'admin',
          password: 'newAdminPassword123',
        );
        expect(adminSession.isAdmin, isTrue);
        expect(adminSession.modules.length, 8);
      },
    );

    testWidgets(
      'INTEGRATION 7: End-to-end CrmApp widget: Create user -> Login on screen -> User Dashboard displays assigned modules',
      (tester) async {
        final leadRepo = MockLeadRepository();

        // 1. Admin creates user in shared account store with calling module only
        accountStore.createUser(
          CreateManagedUserInput(
            userId: 'tele_caller',
            displayName: 'Tele Caller',
            modules: const {CrmModule.calling},
            permissions: const {'calling.use'},
          ),
          temporaryPassword: 'telePassword123',
        );

        // 2. Launch CrmApp
        await tester.pumpWidget(
          CrmApp(
            leadRepository: leadRepo,
            authRepository: authRepo,
            userManagementRepository: userMgmtRepo,
            userLeadLinkRepository: MockUserLeadLinkRepository(),
            leadCallActivityRepository: MockLeadCallActivityRepository(),
            leadFollowUpRepository: MockLeadFollowUpRepository(),
          ),
        );
        await tester.pumpAndSettle();

        // 3. Log in as newly created user
        await tester.enterText(
          find.byKey(const Key('login_user_id_field')),
          'tele_caller',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'telePassword123',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // 4. Verifies UserDashboardScreen is displayed with Tele Caller identity
        expect(find.byType(UserDashboardScreen), findsOneWidget);
        expect(find.text('Tele Caller'), findsOneWidget);

        // 5. Verifies Calling module card is present, and Lead Management is absent
        expect(find.text('Calling'), findsOneWidget);
        expect(find.text('Lead Management'), findsNothing);
      },
    );
  });
}
