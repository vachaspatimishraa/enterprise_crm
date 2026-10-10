import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_follow_up_repository.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_dashboard_screen.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/add_employee_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/edit_employee_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_details_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_directory_screen.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/mock_auth_test_fixtures.dart';

void main() {
  late MockEmployeeRepository repository;

  setUp(() {
    repository = MockEmployeeRepository();
  });

  Widget buildAdminApp({
    MockEmployeeRepository? repo,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
      home: AdminDashboardScreen(
        user: MockAuthTestFixtures.admin,
        onLogout: () {},
        onOpenLeadManagement: () {},
        employeeRepository: repo ?? repository,
      ),
    );
  }

  Widget buildUserApp({
    required CurrentUser user,
    MockEmployeeRepository? repo,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
      home: UserDashboardScreen(
        user: user,
        onLogout: () {},
        userLeadLinkRepository: MockUserLeadLinkRepository(),
        leadRepository: MockLeadRepository(),
        callActivityRepository: MockLeadCallActivityRepository(),
        leadFollowUpRepository: MockLeadFollowUpRepository(),
        employeeRepository: repo ?? repository,
      ),
    );
  }

  group('HR-2.6 Application Integration & Navigation', () {
    testWidgets(
      'Admin Dashboard navigates to Employee Directory on HR/Payroll tap',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        final hrCard = find.byKey(const Key('module_card_hrPayroll'));
        expect(hrCard, findsOneWidget);

        await tester.tap(hrCard);
        await tester.pumpAndSettle();

        expect(find.byType(EmployeeDirectoryScreen), findsOneWidget);
        expect(find.text('Employee Directory'), findsOneWidget);
        expect(find.text('Alice Johnson'), findsOneWidget);

        // Back to dashboard
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(AdminDashboardScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Full Admin flow: Directory -> Add Employee -> Directory displays new employee',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        // Open Directory
        await tester.tap(find.byKey(const Key('module_card_hrPayroll')));
        await tester.pumpAndSettle();

        // Tap Add Employee FAB
        final addFab = find.byKey(const Key('employee_directory_add_button'));
        expect(addFab, findsOneWidget);
        await tester.tap(addFab);
        await tester.pumpAndSettle();

        expect(find.byType(AddEmployeeScreen), findsOneWidget);

        // Fill in details
        await tester.enterText(
          find.byKey(const Key('add_employee_name_field')),
          'Diana Prince',
        );
        await tester.enterText(
          find.byKey(const Key('add_employee_code_field')),
          'EMP-999',
        );
        await tester.enterText(
          find.byKey(const Key('add_employee_dept_field')),
          'Security',
        );
        await tester.enterText(
          find.byKey(const Key('add_employee_designation_field')),
          'Security Director',
        );
        await tester.enterText(
          find.byKey(const Key('add_employee_email_field')),
          'diana.prince@enterprise.com',
        );

        final submitBtn = find.byKey(const Key('add_employee_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Should have returned to directory
        expect(find.byType(EmployeeDirectoryScreen), findsOneWidget);
        expect(find.text('Diana Prince'), findsOneWidget);
      },
    );

    testWidgets(
      'Full Admin flow: Directory -> Details -> Edit -> Details -> Directory refreshed',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        // Open Directory
        await tester.tap(find.byKey(const Key('module_card_hrPayroll')));
        await tester.pumpAndSettle();

        // Tap first employee row
        await tester.tap(find.text('Alice Johnson'));
        await tester.pumpAndSettle();

        expect(find.byType(EmployeeDetailsScreen), findsOneWidget);
        expect(find.text('Alice Johnson'), findsOneWidget);

        // Tap Edit button
        final editBtn = find.byKey(const Key('employee_details_edit_button'));
        expect(editBtn, findsOneWidget);
        await tester.tap(editBtn);
        await tester.pumpAndSettle();

        expect(find.byType(EditEmployeeScreen), findsOneWidget);

        // Edit designation
        await tester.enterText(
          find.byKey(const Key('edit_employee_designation_field')),
          'Senior VP HR',
        );
        final submitBtn = find.byKey(const Key('edit_employee_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Returns to Details screen with updated title
        expect(find.byType(EmployeeDetailsScreen), findsOneWidget);
        expect(find.text('Senior VP HR'), findsOneWidget);

        // Back to Directory
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(EmployeeDirectoryScreen), findsOneWidget);
        expect(find.text('Senior VP HR'), findsOneWidget);
      },
    );

    testWidgets(
      'User Dashboard with HR module navigates to read-only Employee Directory',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const hrUser = CurrentUser(
          id: 'usr_hr_rep',
          displayName: 'HR Coordinator',
          accountType: AccountType.user,
          modules: {CrmModule.hrPayroll},
          permissions: {CrmPermissions.hrView},
        );

        await tester.pumpWidget(buildUserApp(user: hrUser));
        await tester.pumpAndSettle();

        final hrCard = find.byKey(const Key('module_card_hrPayroll'));
        expect(hrCard, findsOneWidget);

        await tester.tap(hrCard);
        await tester.pumpAndSettle();

        expect(find.byType(EmployeeDirectoryScreen), findsOneWidget);
        // Read-only: no Add FAB
        expect(
          find.byKey(const Key('employee_directory_add_button')),
          findsNothing,
        );

        // Tap into Details
        await tester.tap(find.text('Alice Johnson'));
        await tester.pumpAndSettle();

        expect(find.byType(EmployeeDetailsScreen), findsOneWidget);
        // Read-only: no Edit button
        expect(
          find.byKey(const Key('employee_details_edit_button')),
          findsNothing,
        );
      },
    );

    testWidgets('User Dashboard hides HR module if unassigned', (tester) async {
      const salesUser = CurrentUser(
        id: 'usr_sales_only',
        displayName: 'Sales Agent',
        accountType: AccountType.user,
        modules: {CrmModule.leadManagement},
        permissions: {CrmPermissions.leadViewAssigned},
      );

      await tester.pumpWidget(buildUserApp(user: salesUser));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('module_card_hrPayroll')), findsNothing);
    });

    testWidgets('Direct route access is guarded when unauthorized', (
      tester,
    ) async {
      const unauth = CurrentUser(
        id: 'usr_unauth',
        displayName: 'No Access',
        accountType: AccountType.user,
        modules: {},
        permissions: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EmployeeDirectoryScreen(user: unauth, repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
      expect(find.text('Access Restricted'), findsOneWidget);
    });

    testWidgets('Responsive viewports render cleanly without overflow', (
      tester,
    ) async {
      final viewports = [
        const Size(320, 568),
        const Size(360, 640),
        const Size(768, 1024),
        const Size(1200, 800),
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: EmployeeDirectoryScreen(
              user: MockAuthTestFixtures.admin,
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmployeeDirectoryScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('Dark theme renders cleanly without errors', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildAdminApp(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('module_card_hrPayroll')));
      await tester.pumpAndSettle();

      expect(find.byType(EmployeeDirectoryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
