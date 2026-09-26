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
import 'package:enterprise_crm/features/hr/data/repositories/mock_attendance_repository.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_document_repository.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/attendance_list_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_attendance_history_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_details_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_directory_screen.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/mock_auth_test_fixtures.dart';

void main() {
  late MockEmployeeRepository employeeRepository;
  late MockEmployeeDocumentRepository documentRepository;
  late MockAttendanceRepository attendanceRepository;

  const hrViewerUser = CurrentUser(
    id: 'usr_hr_viewer',
    displayName: 'HR Viewer',
    accountType: AccountType.user,
    modules: {CrmModule.hrPayroll},
    permissions: {CrmPermissions.hrView},
  );

  const unauthorizedUser = CurrentUser(
    id: 'usr_sales',
    displayName: 'Sales User',
    accountType: AccountType.user,
    modules: {CrmModule.leadManagement},
    permissions: {CrmPermissions.leadViewAssigned},
  );

  setUp(() {
    employeeRepository = MockEmployeeRepository();
    documentRepository = MockEmployeeDocumentRepository();
    attendanceRepository = MockAttendanceRepository();
  });

  Widget buildAdminApp({ThemeMode themeMode = ThemeMode.light}) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
      home: AdminDashboardScreen(
        user: MockAuthTestFixtures.admin,
        onLogout: () {},
        onOpenLeadManagement: () {},
        employeeRepository: employeeRepository,
        employeeDocumentRepository: documentRepository,
        attendanceRepository: attendanceRepository,
      ),
    );
  }

  Widget buildUserApp({
    required CurrentUser user,
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
        employeeRepository: employeeRepository,
        employeeDocumentRepository: documentRepository,
        attendanceRepository: attendanceRepository,
      ),
    );
  }

  group('HR-4 Attendance Navigation Flow Tests', () {
    testWidgets(
      'Admin Dashboard -> HR / Payroll -> Attendance icon opens AttendanceListScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        // Open HR / Payroll module from Admin Dashboard
        final hrModuleCard = find.text('HR / Payroll');
        expect(hrModuleCard, findsOneWidget);
        await tester.tap(hrModuleCard);
        await tester.pumpAndSettle();

        // We are now in EmployeeDirectoryScreen
        expect(find.byType(EmployeeDirectoryScreen), findsOneWidget);

        // Tap the Attendance action in the AppBar
        final attendanceButton = find.byKey(
          const Key('employee_directory_attendance_button'),
        );
        expect(attendanceButton, findsOneWidget);
        await tester.tap(attendanceButton);
        await tester.pumpAndSettle();

        // Should be in AttendanceListScreen
        expect(find.byType(AttendanceListScreen), findsOneWidget);
        expect(find.text('Attendance Management'), findsOneWidget);
        expect(
          find.byKey(const Key('attendance_search_field')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Employee Directory -> Employee Details -> Attendance History tile opens EmployeeAttendanceHistoryScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        // Open HR / Payroll
        await tester.tap(find.text('HR / Payroll'));
        await tester.pumpAndSettle();

        // Tap first employee row/card (emp_1)
        final firstEmployeeTile = find.text('Alice Johnson');
        expect(firstEmployeeTile, findsWidgets);
        await tester.tap(firstEmployeeTile.first);
        await tester.pumpAndSettle();

        // We are in EmployeeDetailsScreen
        expect(find.byType(EmployeeDetailsScreen), findsOneWidget);

        // Find and tap "Attendance History" tile
        final attendanceTile = find.byKey(
          const Key('employee_attendance_tile'),
        );
        expect(attendanceTile, findsOneWidget);
        await tester.ensureVisible(attendanceTile);
        await tester.tap(attendanceTile);
        await tester.pumpAndSettle();

        // We are now in EmployeeAttendanceHistoryScreen
        expect(find.byType(EmployeeAttendanceHistoryScreen), findsOneWidget);
        expect(find.text('Alice Johnson — Attendance'), findsOneWidget);

        // In seeded data, Alice (emp_1) has 5 records
        expect(
          find.byKey(const Key('employee_history_card_att_101')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Cross-Employee Attendance Isolation: emp_1 and emp_2 show distinct histories',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        // Open HR / Payroll
        await tester.tap(find.text('HR / Payroll'));
        await tester.pumpAndSettle();

        // Navigate to Bob Miller (emp_2)
        final bobTile = find.text('Bob Miller');
        expect(bobTile, findsWidgets);
        await tester.tap(bobTile.first);
        await tester.pumpAndSettle();

        // Tap Attendance History
        final attendanceTile = find.byKey(
          const Key('employee_attendance_tile'),
        );
        await tester.ensureVisible(attendanceTile);
        await tester.tap(attendanceTile);
        await tester.pumpAndSettle();

        // Bob's history is displayed
        expect(find.text('Bob Miller — Attendance'), findsOneWidget);
        // In seeded data, Bob has att_201, att_202, att_203, att_204
        expect(
          find.byKey(const Key('employee_history_card_att_201')),
          findsOneWidget,
        );
        // Alice's record must NOT be present
        expect(
          find.byKey(const Key('employee_history_card_att_101')),
          findsNothing,
        );
      },
    );

    testWidgets('User Dashboard with HR module can view Attendance', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildUserApp(user: hrViewerUser));
      await tester.pumpAndSettle();

      // User has hrPayroll module
      final hrModuleCard = find.text('HR / Payroll');
      expect(hrModuleCard, findsOneWidget);
      await tester.tap(hrModuleCard);
      await tester.pumpAndSettle();

      // In directory, tap attendance button
      final attendanceButton = find.byKey(
        const Key('employee_directory_attendance_button'),
      );
      expect(attendanceButton, findsOneWidget);
      await tester.tap(attendanceButton);
      await tester.pumpAndSettle();

      // User sees attendance records
      expect(find.byType(AttendanceListScreen), findsOneWidget);
    });

    testWidgets('Unauthorized user cannot access Attendance directly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AttendanceListScreen(
            repository: attendanceRepository,
            user: unauthorizedUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
      expect(find.text('Access Restricted'), findsOneWidget);
    });

    testWidgets(
      'Responsive layouts render without errors across screen sizes',
      (tester) async {
        const screenSizes = [
          Size(320, 568), // Small phone
          Size(360, 640), // Standard phone
          Size(768, 1024), // Tablet
          Size(1200, 800), // Desktop
        ];

        for (final size in screenSizes) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            MaterialApp(
              home: AttendanceListScreen(
                repository: attendanceRepository,
                user: MockAuthTestFixtures.admin,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(AttendanceListScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        tester.view.resetPhysicalSize();
      },
    );

    testWidgets('Dark theme renders correctly in Attendance screens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: ThemeMode.dark,
          home: AttendanceListScreen(
            repository: attendanceRepository,
            user: MockAuthTestFixtures.admin,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
