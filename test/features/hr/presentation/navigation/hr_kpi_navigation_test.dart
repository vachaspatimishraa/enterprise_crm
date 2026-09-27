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
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_directory_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_kpi_list_screen.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/mock_auth_test_fixtures.dart';

void main() {
  late MockEmployeeRepository employeeRepository;
  late MockEmployeeDocumentRepository documentRepository;
  late MockAttendanceRepository attendanceRepository;
  late MockEmployeeKpiRepository kpiRepository;

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
    kpiRepository = MockEmployeeKpiRepository();
  });

  Widget buildAdminApp() {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      home: AdminDashboardScreen(
        user: MockAuthTestFixtures.admin,
        onLogout: () {},
        onOpenLeadManagement: () {},
        employeeRepository: employeeRepository,
        employeeDocumentRepository: documentRepository,
        attendanceRepository: attendanceRepository,
        employeeKpiRepository: kpiRepository,
      ),
    );
  }

  Widget buildUserApp({required CurrentUser user}) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
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
        employeeKpiRepository: kpiRepository,
      ),
    );
  }

  group('HR-5.3 KPI Navigation Flow Tests', () {
    testWidgets(
      'Admin Dashboard -> HR / Payroll -> KPI icon opens EmployeeKpiListScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        // Tap HR / Payroll card on Admin Dashboard
        final hrCard = find.text('HR / Payroll');
        expect(hrCard, findsOneWidget);
        await tester.tap(hrCard);
        await tester.pumpAndSettle();

        // In EmployeeDirectoryScreen
        expect(find.byType(EmployeeDirectoryScreen), findsOneWidget);

        // Tap KPI action in AppBar
        final kpiBtn = find.byKey(const Key('employee_directory_kpi_button'));
        expect(kpiBtn, findsOneWidget);
        await tester.tap(kpiBtn);
        await tester.pumpAndSettle();

        // In EmployeeKpiListScreen
        expect(find.byType(EmployeeKpiListScreen), findsOneWidget);
        expect(find.text('KPI Management'), findsOneWidget);
        expect(find.byKey(const Key('kpi_search_field')), findsOneWidget);
      },
    );

    testWidgets(
      'User Dashboard with HR module can navigate to EmployeeKpiListScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildUserApp(user: hrViewerUser));
        await tester.pumpAndSettle();

        // Open HR / Payroll
        final hrCard = find.text('HR / Payroll');
        expect(hrCard, findsOneWidget);
        await tester.tap(hrCard);
        await tester.pumpAndSettle();

        // In Directory, tap KPI button
        final kpiBtn = find.byKey(const Key('employee_directory_kpi_button'));
        expect(kpiBtn, findsOneWidget);
        await tester.tap(kpiBtn);
        await tester.pumpAndSettle();

        // In KPI List
        expect(find.byType(EmployeeKpiListScreen), findsOneWidget);
        expect(find.text('KPI Management'), findsOneWidget);
      },
    );

    testWidgets(
      'Unauthorized user navigating to EmployeeKpiListScreen directly is blocked',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EmployeeKpiListScreen(
              user: unauthorizedUser,
              kpiRepository: kpiRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.text('Access Restricted'), findsOneWidget);
      },
    );
  });
}
