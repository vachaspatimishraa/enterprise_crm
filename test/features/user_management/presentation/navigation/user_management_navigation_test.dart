import 'package:enterprise_crm/app/crm_app.dart';
import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/user_management/data/repositories/mock_user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/managed_user.dart';
import 'package:enterprise_crm/features/user_management/domain/repositories/user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/presentation/screens/user_details_screen.dart';
import 'package:enterprise_crm/features/user_management/presentation/screens/users_and_access_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

void main() {
  group('User Management Navigation & Route Guard Integration Tests', () {
    late MockLeadRepository leadRepository;
    late MockAuthRepository authRepository;
    late MockUserManagementRepository userManagementRepository;

    setUp(() {
      leadRepository = MockLeadRepository();
      authRepository = MockAuthRepository();
      userManagementRepository = MockUserManagementRepository();
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
        final nonAdminUser = MockAuthRepository.mockUser;
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
        final nonAdminUser = MockAuthRepository.mockUser;
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
  });
}
