import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/hr/data/mock/mock_employee_kpi_store.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employee_kpi.dart';
import 'package:enterprise_crm/features/hr/domain/repositories/employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/add_employee_kpi_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingEmployeeKpiRepo implements EmployeeKpiRepository {
  @override
  Future<List<EmployeeKpi>> getKpis({
    String? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async => [];

  @override
  Future<List<EmployeeKpi>> getKpisForEmployee(
    String employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async => [];

  @override
  Future<EmployeeKpi?> getKpiById(String id) async => null;

  @override
  Future<EmployeeKpi> createKpi({
    required String employeeId,
    required String metricName,
    required DateTime periodStart,
    required DateTime periodEnd,
    required double targetValue,
    required double actualValue,
    double? score,
    String? remarks,
  }) async {
    throw const EmployeeKpiException('Simulated repository creation error');
  }

  @override
  Future<EmployeeKpi> updateKpi({
    required String id,
    required String metricName,
    required DateTime periodStart,
    required DateTime periodEnd,
    required double targetValue,
    required double actualValue,
    double? score,
    bool clearScore = false,
    String? remarks,
    bool clearRemarks = false,
  }) async => throw UnimplementedError();
}

void main() {
  late MockEmployeeKpiStore store;
  late MockEmployeeKpiRepository kpiRepository;
  late MockEmployeeRepository employeeRepository;

  const adminUser = CurrentUser(
    id: 'usr_admin',
    displayName: 'Admin User',
    accountType: AccountType.admin,
    modules: {},
    permissions: {},
  );

  const regularHrUser = CurrentUser(
    id: 'usr_hr',
    displayName: 'HR Specialist',
    accountType: AccountType.user,
    modules: {CrmModule.hrPayroll},
    permissions: {CrmPermissions.hrView},
  );

  setUp(() {
    store = MockEmployeeKpiStore();
    kpiRepository = MockEmployeeKpiRepository(store: store);
    employeeRepository = MockEmployeeRepository();
  });

  Widget buildTestWidget({
    required CurrentUser user,
    EmployeeKpiRepository? repo,
    Size size = const Size(1200, 800),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: AddEmployeeKpiScreen(
          user: user,
          kpiRepository: repo ?? kpiRepository,
          employeeRepository: employeeRepository,
        ),
      ),
    );
  }

  group('AddEmployeeKpiScreen Widget Tests', () {
    testWidgets('non-admin user is blocked with AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: regularHrUser));
      await tester.pumpAndSettle();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.byKey(const Key('add_employee_kpi_scaffold')), findsNothing);
    });

    testWidgets('admin user sees creation form with all approved fields', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('add_employee_kpi_scaffold')),
        findsOneWidget,
      );
      expect(find.text('Add Employee KPI'), findsOneWidget);
      expect(
        find.byKey(const Key('add_kpi_employee_dropdown')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('add_kpi_metric_field')), findsOneWidget);
      expect(
        find.byKey(const Key('add_kpi_start_date_picker')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('add_kpi_end_date_picker')), findsOneWidget);
      expect(find.byKey(const Key('add_kpi_target_field')), findsOneWidget);
      expect(find.byKey(const Key('add_kpi_actual_field')), findsOneWidget);
      expect(find.byKey(const Key('add_kpi_score_field')), findsOneWidget);
      expect(find.byKey(const Key('add_kpi_remarks_field')), findsOneWidget);
      expect(find.byKey(const Key('add_kpi_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('add_kpi_cancel_button')), findsOneWidget);
    });

    testWidgets(
      'validation rejects submission when required fields are empty',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(user: adminUser));
        await tester.pumpAndSettle();

        final submitBtn = find.byKey(const Key('add_kpi_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(find.text('Metric name is required'), findsOneWidget);
        expect(find.text('Target value is required'), findsOneWidget);
        expect(find.text('Actual value is required'), findsOneWidget);
      },
    );

    testWidgets(
      'validation rejects invalid numeric format in target and actual',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(user: adminUser));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('add_kpi_metric_field')),
          'Client Satisfaction Score',
        );
        await tester.enterText(
          find.byKey(const Key('add_kpi_target_field')),
          'not_a_number',
        );
        await tester.enterText(
          find.byKey(const Key('add_kpi_actual_field')),
          'abc',
        );

        final submitBtn = find.byKey(const Key('add_kpi_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(find.text('Enter a valid number'), findsNWidgets(2));
      },
    );

    testWidgets(
      'successful submission creates KPI in repository and shows success feedback',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(user: adminUser));
        await tester.pumpAndSettle();

        // Fill in form
        await tester.enterText(
          find.byKey(const Key('add_kpi_metric_field')),
          'Quarterly Code Review Throughput',
        );
        await tester.enterText(
          find.byKey(const Key('add_kpi_target_field')),
          '50',
        );
        await tester.enterText(
          find.byKey(const Key('add_kpi_actual_field')),
          '55',
        );
        await tester.enterText(
          find.byKey(const Key('add_kpi_score_field')),
          '95',
        );
        await tester.enterText(
          find.byKey(const Key('add_kpi_remarks_field')),
          'Excellent engineering review engagement',
        );

        final submitBtn = find.byKey(const Key('add_kpi_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Check repository persistence
        final allKpis = await kpiRepository.getKpis();
        expect(
          allKpis.any(
            (k) => k.metricName == 'Quarterly Code Review Throughput',
          ),
          isTrue,
        );
        final created = allKpis.firstWhere(
          (k) => k.metricName == 'Quarterly Code Review Throughput',
        );
        expect(created.targetValue, 50.0);
        expect(created.actualValue, 55.0);
        expect(created.score, 95.0);
        expect(created.remarks, 'Excellent engineering review engagement');
      },
    );

    testWidgets(
      'shows error feedback and banner on repository failure while preserving entered text',
      (tester) async {
        final failingRepo = FailingEmployeeKpiRepo();
        await tester.pumpWidget(
          buildTestWidget(user: adminUser, repo: failingRepo),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('add_kpi_metric_field')),
          'Resilient Field Data',
        );
        await tester.enterText(
          find.byKey(const Key('add_kpi_target_field')),
          '80',
        );
        await tester.enterText(
          find.byKey(const Key('add_kpi_actual_field')),
          '85',
        );

        final submitBtn = find.byKey(const Key('add_kpi_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('add_kpi_error_banner')), findsOneWidget);
        expect(
          find.text('Simulated repository creation error'),
          findsAtLeastNWidgets(1),
        );

        // Input was preserved
        expect(find.text('Resilient Field Data'), findsOneWidget);
      },
    );

    testWidgets(
      'responsive layout on mobile screen (360x640) without overflow',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(user: adminUser, size: const Size(360, 640)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('add_employee_kpi_scaffold')),
          findsOneWidget,
        );
      },
    );
  });
}
