import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employee_kpi.dart';
import 'package:enterprise_crm/features/hr/domain/repositories/employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/employee_kpi_details_cubit.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_kpi_details_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_kpi_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingEmployeeKpiRepository extends MockEmployeeKpiRepository {
  @override
  Future<EmployeeKpi?> getKpiById(String id) async {
    throw const EmployeeKpiException('Simulated repository failure');
  }
}

class NullableFieldsKpiRepository extends MockEmployeeKpiRepository {
  @override
  Future<EmployeeKpi?> getKpiById(String id) async {
    return EmployeeKpi(
      id: id,
      employeeId: 'emp_1',
      periodStart: DateTime.utc(2026, 7, 1),
      periodEnd: DateTime.utc(2026, 9, 30),
      metricName: 'HR Ticket Resolution SLA',
      targetValue: 95.0,
      actualValue: 90.0,
      score: null,
      remarks: null,
      createdAt: null,
      updatedAt: null,
    );
  }
}

void main() {
  late MockEmployeeKpiRepository kpiRepository;
  late MockEmployeeRepository employeeRepository;

  const adminUser = CurrentUser(
    id: 'usr_admin',
    displayName: 'Admin User',
    accountType: AccountType.admin,
  );

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
    kpiRepository = MockEmployeeKpiRepository();
    employeeRepository = MockEmployeeRepository();
  });

  Widget buildDetailsTestWidget({
    CurrentUser user = adminUser,
    required String kpiId,
    EmployeeKpiRepository? repo,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: themeMode,
      home: EmployeeKpiDetailsScreen(
        user: user,
        kpiId: kpiId,
        kpiRepository: repo ?? kpiRepository,
        employeeRepository: employeeRepository,
      ),
    );
  }

  group('EmployeeKpiDetailsScreen — HR-5.5 Authorization & States', () {
    testWidgets('unauthorized user is blocked with AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildDetailsTestWidget(user: unauthorizedUser, kpiId: 'kpi_101'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
      expect(find.text('Access Restricted'), findsOneWidget);
    });

    testWidgets('authorized non-admin user with HR permissions sees KPI details', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildDetailsTestWidget(user: hrViewerUser, kpiId: 'kpi_101'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsNothing);
      expect(find.byKey(const Key('employee_kpi_details_scaffold')), findsOneWidget);
      expect(find.text('Employee Retention Rate'), findsOneWidget);
    });

    testWidgets('valid KPI ID loads and renders all approved fields accurately', (
      tester,
    ) async {
      await tester.pumpWidget(buildDetailsTestWidget(kpiId: 'kpi_101'));
      await tester.pumpAndSettle();

      // Header card
      expect(find.byKey(const Key('kpi_details_header_card')), findsOneWidget);
      expect(find.text('Employee Retention Rate'), findsOneWidget);
      // Resolved employee name for emp_1
      expect(find.text('Alice Johnson'), findsOneWidget);
      // Period
      expect(find.text('Period: 2026-07-01 – 2026-09-30'), findsOneWidget);

      // Performance stats
      expect(find.byKey(const Key('kpi_details_target_value')), findsOneWidget);
      expect(find.text('90.0'), findsOneWidget);
      expect(find.byKey(const Key('kpi_details_actual_value')), findsOneWidget);
      expect(find.text('92.5'), findsOneWidget);
      expect(find.byKey(const Key('kpi_details_score_value')), findsOneWidget);
      expect(find.text('95.0'), findsOneWidget);

      // Metadata rows
      expect(find.text('kpi_101'), findsOneWidget);
      expect(find.text('emp_1'), findsOneWidget);
      expect(find.text('2026-07-01'), findsOneWidget);
      expect(find.text('2026-09-30'), findsOneWidget);
      expect(find.text('Exceeded retention target across departments'), findsOneWidget);

      // Scoring integrity: verify NO fabricated percentage calculation like 102.7%
      expect(find.textContaining('102.7'), findsNothing);
      // No fabricated performance grade labels
      expect(find.text('Excellent'), findsNothing);
      expect(find.text('Grade A'), findsNothing);
    });

    testWidgets('KPI with null score renders Not recorded and null remarks as None recorded', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildDetailsTestWidget(
          kpiId: 'kpi_null_fields',
          repo: NullableFieldsKpiRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HR Ticket Resolution SLA'), findsOneWidget);
      expect(find.text('Not recorded'), findsOneWidget);
      expect(find.text('None recorded'), findsOneWidget);
    });

    testWidgets('unknown KPI ID displays not found state with functional return button', (
      tester,
    ) async {
      await tester.pumpWidget(buildDetailsTestWidget(kpiId: 'non_existent_kpi'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('kpi_details_not_found')), findsOneWidget);
      expect(find.text('KPI record not found.'), findsOneWidget);
      expect(find.byKey(const Key('kpi_details_back_to_list_button')), findsOneWidget);
    });

    testWidgets('repository error displays error state with functional Retry', (
      tester,
    ) async {
      final failingRepo = FailingEmployeeKpiRepository();
      await tester.pumpWidget(
        buildDetailsTestWidget(kpiId: 'kpi_101', repo: failingRepo),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('kpi_details_error_message')), findsOneWidget);
      expect(find.text('Simulated repository failure'), findsOneWidget);
      expect(find.byKey(const Key('kpi_details_retry_button')), findsOneWidget);
    });
  });

  group('EmployeeKpiDetailsScreen — List to Details Navigation & Refresh', () {
    testWidgets('tapping mobile KPI card navigates to KPI Details screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: EmployeeKpiListScreen(
            user: adminUser,
            kpiRepository: kpiRepository,
            employeeRepository: employeeRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify on List Screen
      expect(find.byKey(const Key('kpi_card_kpi_101')), findsOneWidget);

      // Tap on card
      await tester.tap(find.byKey(const Key('kpi_card_tap_kpi_101')));
      await tester.pumpAndSettle();

      // Verify on Details Screen
      expect(find.byKey(const Key('employee_kpi_details_scaffold')), findsOneWidget);
      expect(find.text('KPI Details'), findsOneWidget);
      expect(find.text('Employee Retention Rate'), findsOneWidget);
      expect(find.text('Alice Johnson'), findsOneWidget);

      // Back navigation
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Back on List Screen
      expect(find.byKey(const Key('employee_kpi_list_scaffold')), findsOneWidget);
      expect(find.byKey(const Key('kpi_card_kpi_101')), findsOneWidget);
    });

    testWidgets('tapping desktop table row navigates to KPI Details screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: EmployeeKpiListScreen(
            user: adminUser,
            kpiRepository: kpiRepository,
            employeeRepository: employeeRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify on Desktop Table
      expect(find.byKey(const Key('kpi_desktop_table_view')), findsOneWidget);

      // Tap on row cell
      await tester.tap(find.byKey(const Key('kpi_row_kpi_201')));
      await tester.pumpAndSettle();

      // Verify on Details Screen
      expect(find.byKey(const Key('employee_kpi_details_scaffold')), findsOneWidget);
      expect(find.text('Inventory Accuracy'), findsOneWidget);
      expect(find.text('Bob Miller'), findsOneWidget);

      // Back navigation
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Back on List Screen
      expect(find.byKey(const Key('kpi_desktop_table_view')), findsOneWidget);
    });
  });

  group('EmployeeKpiDetailsScreen — Responsive & Theme', () {
    testWidgets('renders cleanly without overflow across screen sizes', (
      tester,
    ) async {
      FlutterError.onError = (details) {
        debugPrint('DETAILS: ${details.exceptionAsString()}');
        debugPrint('CONTEXT: ${details.context?.toDescription()}');
        debugPrint('STACK: ${details.stack}');
      };

      const testSizes = [
        Size(320, 568),
        Size(360, 640),
        Size(768, 1024),
        Size(1200, 800),
      ];

      for (final size in testSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildDetailsTestWidget(kpiId: 'kpi_101'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('kpi_details_header_card')), findsOneWidget);
        expect(find.text('Employee Retention Rate'), findsOneWidget);
      }
    });

    testWidgets('renders cleanly in dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildDetailsTestWidget(kpiId: 'kpi_101', themeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('kpi_details_header_card')), findsOneWidget);
    });
  });
}
