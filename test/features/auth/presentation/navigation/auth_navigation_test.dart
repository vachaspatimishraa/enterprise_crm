import 'package:enterprise_crm/app/crm_app.dart';
import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/login_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_dashboard_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_lead_placeholder_screen.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_dashboard_screen.dart';
import 'package:enterprise_crm/features/user_management/data/repositories/mock_user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/data/mock/mock_account_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth Navigation & Routing Integration Tests', () {
    late MockLeadRepository leadRepository;
    late MockAuthRepository authRepository;
    late MockUserManagementRepository userManagementRepository;
    late MockUserLeadLinkRepository userLeadLinkRepository;
    late MockAccountStore accountStore;

    setUp(() {
      leadRepository = MockLeadRepository();
      accountStore = MockAccountStore.seeded();
      authRepository = MockAuthRepository(accountStore: accountStore);
      userManagementRepository = MockUserManagementRepository(
        accountStore: accountStore,
      );
      userLeadLinkRepository = MockUserLeadLinkRepository();
    });

    testWidgets(
      'PRODUCTION ROOT REGRESSION: CrmApp with AuthRepository starts at Login, never directly at Lead Dashboard',
      (tester) async {
        await tester.pumpWidget(
          CrmApp(
            leadRepository: leadRepository,
            authRepository: authRepository,
            userManagementRepository: userManagementRepository,
            userLeadLinkRepository: userLeadLinkRepository,
          ),
        );
        await tester.pumpAndSettle();

        // Verified: app starts at LoginScreen
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Enterprise CRM'), findsOneWidget);
        expect(find.byKey(const Key('login_user_id_field')), findsOneWidget);

        // Verified: LeadDashboardScreen is NOT directly rendered
        expect(find.byType(LeadDashboardScreen), findsNothing);
        expect(find.byType(AdminDashboardScreen), findsNothing);
        expect(find.byType(UserDashboardScreen), findsNothing);
      },
    );

    testWidgets(
      'ADMIN FLOW: login -> Admin Dashboard -> Lead Management -> Lead Dashboard -> back -> Admin Dashboard',
      (tester) async {
        await tester.pumpWidget(
          CrmApp(
            leadRepository: leadRepository,
            authRepository: authRepository,
            userManagementRepository: userManagementRepository,
            userLeadLinkRepository: userLeadLinkRepository,
          ),
        );
        await tester.pumpAndSettle();

        // Enter admin credentials
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

        // Verified: on AdminDashboardScreen
        expect(find.byType(AdminDashboardScreen), findsOneWidget);
        expect(find.text('ADMIN DASHBOARD'), findsOneWidget);

        // Tap 'Lead Management' module card
        await tester.tap(find.byKey(const Key('module_card_leadManagement')));
        await tester.pumpAndSettle();

        // Verified: existing full Lead Dashboard is rendered
        expect(find.byType(LeadDashboardScreen), findsOneWidget);
        expect(find.text('Lead Management'), findsOneWidget);
        expect(find.text('Overview & Summary'), findsOneWidget);
        expect(find.text('Total Leads'), findsOneWidget);
        expect(find.text('Quick Actions'), findsOneWidget);
        expect(find.text('Add Lead'), findsOneWidget);
        expect(find.text('Import Leads'), findsOneWidget);
        expect(find.text('Export Leads'), findsWidgets);
        expect(find.text('Distribute Leads'), findsOneWidget);

        // Tap Back in AppBar to return to Admin Dashboard
        final backButton = find.byTooltip('Back');
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Verified: safely back on AdminDashboardScreen
        expect(find.byType(AdminDashboardScreen), findsOneWidget);
        expect(find.byType(LeadDashboardScreen), findsNothing);
      },
    );

    testWidgets(
      'USER FLOW: login -> User Dashboard -> Lead Management -> User Lead Placeholder -> back -> User Dashboard',
      (tester) async {
        await tester.pumpWidget(
          CrmApp(
            leadRepository: leadRepository,
            authRepository: authRepository,
            userManagementRepository: userManagementRepository,
            userLeadLinkRepository: userLeadLinkRepository,
          ),
        );
        await tester.pumpAndSettle();

        // Enter standard user credentials
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

        // Verified: on UserDashboardScreen
        expect(find.byType(UserDashboardScreen), findsOneWidget);
        expect(find.text('USER DASHBOARD'), findsOneWidget);
        expect(find.text('Lead Management'), findsOneWidget);
        expect(find.text('Calling'), findsOneWidget);
        expect(find.text('Inventory'), findsNothing);
        expect(find.text('Users & Access'), findsNothing);

        // Tap Lead Management
        await tester.tap(find.byKey(const Key('module_card_leadManagement')));
        await tester.pumpAndSettle();

        // Verified: opens safe UserLeadPlaceholderScreen, NOT unrestricted LeadDashboardScreen
        expect(find.byType(UserLeadPlaceholderScreen), findsOneWidget);
        expect(find.byType(LeadDashboardScreen), findsNothing);
        // New screen shows YOUR ACCESS capability section instead of old placeholder text
        expect(find.text('YOUR ACCESS'), findsOneWidget);

        // Tap Back
        await tester.tap(find.text('Back to Dashboard'));
        await tester.pumpAndSettle();

        expect(find.byType(UserDashboardScreen), findsOneWidget);
      },
    );

    testWidgets(
      'LOGOUT NAVIGATION SAFETY: Admin logout returns to Login and Back cannot re-enter dashboard',
      (tester) async {
        await tester.pumpWidget(
          CrmApp(
            leadRepository: leadRepository,
            authRepository: authRepository,
            userManagementRepository: userManagementRepository,
            userLeadLinkRepository: userLeadLinkRepository,
          ),
        );
        await tester.pumpAndSettle();

        // Login as admin
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

        // Tap Logout
        await tester.tap(find.byKey(const Key('crm_header_logout_button')));
        await tester.pumpAndSettle();

        // Verified: on LoginScreen
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(AdminDashboardScreen), findsNothing);
        expect(authRepository.currentUser, isNull);

        // Attempt Navigator pop (system back)
        final navigatorState = tester.state<NavigatorState>(
          find.byType(Navigator),
        );
        final didPop = await navigatorState.maybePop();

        // Verified: cannot pop, remains on LoginScreen
        expect(didPop, isFalse);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(AdminDashboardScreen), findsNothing);
      },
    );

    testWidgets(
      'NESTED-ROUTE LOGOUT REGRESSION: Logout while inside Lead Dashboard returns to Login and Back cannot restore session',
      (tester) async {
        await tester.pumpWidget(
          CrmApp(
            leadRepository: leadRepository,
            authRepository: authRepository,
            userManagementRepository: userManagementRepository,
            userLeadLinkRepository: userLeadLinkRepository,
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

        // Navigate into nested Lead Management
        await tester.tap(find.byKey(const Key('module_card_leadManagement')));
        await tester.pumpAndSettle();

        expect(find.byType(LeadDashboardScreen), findsOneWidget);

        // Trigger logout from authenticated shell inside Lead Dashboard
        expect(find.byKey(const Key('shell_logout_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('shell_logout_button')));
        await tester.pumpAndSettle();

        // Verified: immediately back on LoginScreen
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(LeadDashboardScreen), findsNothing);
        expect(find.byType(AdminDashboardScreen), findsNothing);
        expect(authRepository.currentUser, isNull);

        // Attempt Navigator pop (system back)
        final navigatorState = tester.state<NavigatorState>(
          find.byType(Navigator),
        );
        final didPop = await navigatorState.maybePop();

        // Verified: cannot pop back into authenticated route
        expect(didPop, isFalse);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(LeadDashboardScreen), findsNothing);
      },
    );
  });
}
