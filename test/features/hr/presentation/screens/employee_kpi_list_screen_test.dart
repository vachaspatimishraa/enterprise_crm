import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/hr/data/mock/mock_employee_kpi_store.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employee_kpi.dart';
import 'package:enterprise_crm/features/hr/domain/repositories/employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_kpi_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingKpiRepo implements EmployeeKpiRepository {
  bool shouldFail = true;

  @override
  Future<List<EmployeeKpi>> getKpis({
    String? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (shouldFail) {
      throw const EmployeeKpiException('Service temporary glitch');
    }
    return [
      EmployeeKpi(
        id: 'kpi_rec_1',
        employeeId: 'emp_1',
        periodStart: DateTime.utc(2026, 7, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
        metricName: 'Recovered Metric',
        targetValue: 10.0,
        actualValue: 12.0,
      ),
    ];
  }

  @override
  Future<List<EmployeeKpi>> getKpisForEmployee(
    String employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return getKpis();
  }

  @override
  Future<EmployeeKpi?> getKpiById(String id) async => null;
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

  Widget buildTestWidget({
    CurrentUser user = adminUser,
    EmployeeKpiRepository? repo,
    String? initialEmployeeId,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: themeMode,
      home: EmployeeKpiListScreen(
        user: user,
        kpiRepository: repo ?? kpiRepository,
        employeeRepository: employeeRepository,
        initialEmployeeId: initialEmployeeId,
      ),
    );
  }

  group('EmployeeKpiListScreen — HR-5.3 List UI Tests', () {
    testWidgets('unauthorized user sees AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: unauthorizedUser));
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
      expect(find.text('Access Restricted'), findsOneWidget);
    });

    testWidgets('authorized non-admin user with HR permissions sees KPI list', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: hrViewerUser));
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsNothing);
      expect(find.text('KPI Management'), findsOneWidget);
    });

    testWidgets(
      'mobile layout (<600px) renders cards with resolved employee names',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('kpi_mobile_list_view')), findsOneWidget);
        expect(find.byKey(const Key('kpi_desktop_table_view')), findsNothing);

        // Verify seeded cards are present
        expect(find.byKey(const Key('kpi_card_kpi_101')), findsOneWidget);
        expect(find.byKey(const Key('kpi_card_kpi_201')), findsOneWidget);

        // Verify resolved employee names
        expect(find.text('Alice Johnson'), findsWidgets);
        expect(find.text('Bob Miller'), findsWidgets);

        // Verify metric name and target/actual/score stats
        expect(find.text('Employee Retention Rate'), findsOneWidget);
        expect(find.text('90.0'), findsWidgets); // Target
        expect(find.text('92.5'), findsOneWidget); // Actual
        expect(find.text('95.0'), findsWidgets); // Score
      },
    );

    testWidgets(
      'desktop layout (>=600px) renders DataTable with structured columns',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('kpi_desktop_table_view')), findsOneWidget);
        expect(find.byKey(const Key('kpi_mobile_list_view')), findsNothing);

        // Table columns
        expect(find.text('Metric'), findsOneWidget);
        expect(find.text('Employee'), findsOneWidget);
        expect(find.text('Period'), findsOneWidget);
        expect(find.text('Target'), findsOneWidget);
        expect(find.text('Actual'), findsOneWidget);
        expect(find.text('Score'), findsOneWidget);
        expect(find.text('Remarks'), findsOneWidget);

        // Table rows
        expect(find.byKey(const ValueKey('kpi_row_kpi_101')), findsOneWidget);
        expect(find.byKey(const ValueKey('kpi_row_kpi_201')), findsOneWidget);
        expect(find.byKey(const ValueKey('kpi_row_kpi_301')), findsOneWidget);
      },
    );

    testWidgets('empty repository displays truthful empty state', (
      tester,
    ) async {
      final emptyStore = MockEmployeeKpiStore(seedInitialData: false);
      final emptyRepo = MockEmployeeKpiRepository(store: emptyStore);

      await tester.pumpWidget(buildTestWidget(repo: emptyRepo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('kpi_empty_state')), findsOneWidget);
      expect(find.text('No KPI records available.'), findsOneWidget);
    });

    testWidgets('repository error displays error state with functional Retry', (
      tester,
    ) async {
      final failingRepo = FailingKpiRepo();

      await tester.pumpWidget(buildTestWidget(repo: failingRepo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('kpi_error_state')), findsOneWidget);
      expect(find.text('Service temporary glitch'), findsOneWidget);

      // Fix failure and tap Retry
      failingRepo.shouldFail = false;
      final retryBtn = find.byKey(const Key('kpi_retry_button'));
      expect(retryBtn, findsOneWidget);
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('kpi_error_state')), findsNothing);
      expect(find.text('Recovered Metric'), findsOneWidget);
    });
  });

  group('EmployeeKpiListScreen — HR-5.4 Search & Filtering Tests', () {
    testWidgets('search query filters records by metric name', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('kpi_search_field'));
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'retention');
      await tester.pumpAndSettle();

      // Only Alice's retention KPI should remain
      expect(find.text('Employee Retention Rate'), findsOneWidget);
      expect(find.text('Inventory Accuracy'), findsNothing);

      // Active filter chip appears
      expect(find.text('Query: "retention"'), findsOneWidget);
    });

    testWidgets('search query filters records by resolved employee name', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('kpi_search_field'));
      await tester.enterText(searchField, 'Charlie');
      await tester.pumpAndSettle();

      // Charlie Davis's KPI (kpi_301)
      expect(find.text('Quarterly Sales Revenue (\$k)'), findsOneWidget);
      expect(find.text('Employee Retention Rate'), findsNothing);
    });

    testWidgets('search clear button restores full record list', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('kpi_search_field'));
      await tester.enterText(searchField, 'retention');
      await tester.pumpAndSettle();

      expect(find.text('Inventory Accuracy'), findsNothing);

      final clearBtn = find.byKey(const Key('kpi_search_clear_button'));
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // All records restored
      expect(find.text('Inventory Accuracy'), findsOneWidget);
    });

    testWidgets(
      'search matching nothing displays no-results state with Clear Filters button',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final searchField = find.byKey(const Key('kpi_search_field'));
        await tester.enterText(searchField, 'xyz_nothing_matches');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('kpi_no_results_state')), findsOneWidget);
        expect(find.text('No KPI records match your filters.'), findsOneWidget);

        final clearFiltersBtn = find.byKey(
          const Key('kpi_clear_filters_button'),
        );
        expect(clearFiltersBtn, findsOneWidget);
        await tester.tap(clearFiltersBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('kpi_no_results_state')), findsNothing);
        expect(find.text('Employee Retention Rate'), findsOneWidget);
      },
    );

    testWidgets('employee dropdown filters records to selected employee', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final dropdown = find.byKey(const Key('kpi_employee_filter'));
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Tap Bob Miller (emp_2)
      final bobItem = find.byKey(const Key('kpi_employee_item_emp_2')).last;
      await tester.tap(bobItem);
      await tester.pumpAndSettle();

      expect(find.text('Inventory Accuracy'), findsOneWidget);
      expect(find.text('Order Dispatch Lead Time (Hours)'), findsOneWidget);
      expect(find.text('Employee Retention Rate'), findsNothing);
    });

    testWidgets('period filter modal allows selecting Q3 2026', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final periodBtn = find.byKey(const Key('kpi_period_filter_button'));
      expect(periodBtn, findsOneWidget);
      await tester.tap(periodBtn);
      await tester.pumpAndSettle();

      // Bottom sheet options
      expect(find.byKey(const Key('kpi_period_all')), findsOneWidget);
      expect(find.byKey(const Key('kpi_period_q3_2026')), findsOneWidget);
      expect(find.byKey(const Key('kpi_period_custom')), findsOneWidget);

      await tester.tap(find.byKey(const Key('kpi_period_q3_2026')));
      await tester.pumpAndSettle();

      expect(find.text('Q3 2026 (Jul–Sep)'), findsWidgets);
    });

    testWidgets('Reset button clears all active filters and reloads', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Apply search
      final searchField = find.byKey(const Key('kpi_search_field'));
      await tester.enterText(searchField, 'retention');
      await tester.pumpAndSettle();

      expect(find.text('Inventory Accuracy'), findsNothing);

      // Tap Reset button
      final resetBtn = find.byKey(const Key('kpi_reset_filters_button'));
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(find.text('Inventory Accuracy'), findsOneWidget);
      expect(find.text('Employee Retention Rate'), findsOneWidget);
    });
  });

  group('EmployeeKpiListScreen — Responsive & Theme Tests', () {
    testWidgets('renders cleanly without overflow across screen sizes', (
      tester,
    ) async {
      const screenSizes = [
        Size(320, 568),
        Size(360, 640),
        Size(768, 1024),
        Size(1200, 800),
      ];

      for (final size in screenSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('employee_kpi_list_scaffold')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }

      tester.view.resetPhysicalSize();
    });

    testWidgets('dark theme renders cleanly', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('employee_kpi_list_scaffold')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
