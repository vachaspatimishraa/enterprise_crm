import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/hr/data/mock/mock_employee_kpi_store.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employee_kpi.dart';
import 'package:enterprise_crm/features/hr/domain/repositories/employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/edit_employee_kpi_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingEditKpiRepo implements EmployeeKpiRepository {
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
  }) async => throw UnimplementedError();

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
  }) async {
    throw const EmployeeKpiException('Simulated repository update error');
  }
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

  final sampleKpi = EmployeeKpi(
    id: 'kpi_101',
    employeeId: 'emp_1',
    periodStart: DateTime.utc(2026, 7, 1),
    periodEnd: DateTime.utc(2026, 9, 30),
    metricName: 'Employee Retention Rate',
    targetValue: 90.0,
    actualValue: 92.5,
    score: 95.0,
    remarks: 'Exceeded retention target across departments',
  );

  setUp(() {
    store = MockEmployeeKpiStore();
    kpiRepository = MockEmployeeKpiRepository(store: store);
    employeeRepository = MockEmployeeRepository();
  });

  Widget buildTestWidget({
    required CurrentUser user,
    EmployeeKpi? kpi,
    EmployeeKpiRepository? repo,
    Size size = const Size(1200, 800),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: EditEmployeeKpiScreen(
          user: user,
          kpi: kpi ?? sampleKpi,
          kpiRepository: repo ?? kpiRepository,
          employeeRepository: employeeRepository,
        ),
      ),
    );
  }

  group('EditEmployeeKpiScreen Widget Tests', () {
    testWidgets('non-admin user is blocked with AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: regularHrUser));
      await tester.pumpAndSettle();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.byKey(const Key('edit_employee_kpi_scaffold')), findsNothing);
    });

    testWidgets(
      'admin user sees prefilled edit form and immutable identifiers',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(user: adminUser));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('edit_employee_kpi_scaffold')),
          findsOneWidget,
        );
        expect(find.text('Edit Employee KPI'), findsOneWidget);

        // Verify immutable identifiers
        expect(find.byKey(const Key('edit_kpi_id_text')), findsOneWidget);
        expect(find.text('kpi_101'), findsOneWidget);
        expect(
          find.text('Alice Johnson'),
          findsOneWidget,
        ); // Resolved emp_1 name

        // Verify prefilled form fields
        expect(find.text('Employee Retention Rate'), findsOneWidget);
        expect(find.text('90.0'), findsOneWidget);
        expect(find.text('92.5'), findsOneWidget);
        expect(find.text('95.0'), findsOneWidget);
        expect(
          find.text('Exceeded retention target across departments'),
          findsOneWidget,
        );
      },
    );

    testWidgets('validation rejects empty metric name on edit', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('edit_kpi_metric_field')),
        '',
      );

      final submitBtn = find.byKey(const Key('edit_kpi_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Metric name is required'), findsOneWidget);
    });

    testWidgets('successful save updates record in repository', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('edit_kpi_metric_field')),
        'Updated Retention Strategy Rate',
      );
      await tester.enterText(
        find.byKey(const Key('edit_kpi_target_field')),
        '94.0',
      );
      await tester.enterText(
        find.byKey(const Key('edit_kpi_actual_field')),
        '96.5',
      );
      await tester.enterText(
        find.byKey(const Key('edit_kpi_score_field')),
        '99.0',
      );

      final submitBtn = find.byKey(const Key('edit_kpi_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      final updated = await kpiRepository.getKpiById('kpi_101');
      expect(updated, isNotNull);
      expect(updated!.metricName, 'Updated Retention Strategy Rate');
      expect(updated.targetValue, 94.0);
      expect(updated.actualValue, 96.5);
      expect(updated.score, 99.0);
      expect(updated.employeeId, 'emp_1'); // Immutable association preserved
    });

    testWidgets(
      'shows error banner on repository failure while preserving edits',
      (tester) async {
        final failingRepo = FailingEditKpiRepo();
        await tester.pumpWidget(
          buildTestWidget(user: adminUser, repo: failingRepo),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('edit_kpi_metric_field')),
          'Attempted Revision',
        );

        final submitBtn = find.byKey(const Key('edit_kpi_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('edit_kpi_error_banner')), findsOneWidget);
        expect(
          find.text('Simulated repository update error'),
          findsAtLeastNWidgets(1),
        );

        // Edits preserved
        expect(find.text('Attempted Revision'), findsOneWidget);
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
          find.byKey(const Key('edit_employee_kpi_scaffold')),
          findsOneWidget,
        );
      },
    );
  });
}
