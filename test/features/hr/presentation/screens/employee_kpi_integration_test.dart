import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/hr/data/mock/mock_employee_kpi_store.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_kpi_details_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_kpi_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  setUp(() {
    store = MockEmployeeKpiStore();
    kpiRepository = MockEmployeeKpiRepository(store: store);
    employeeRepository = MockEmployeeRepository();
  });

  Widget buildAppWidget({required Widget home}) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(1200, 800)),
        child: home,
      ),
    );
  }

  group('Employee KPI Add/Edit Integration Tests (HR-5.6)', () {
    testWidgets('KPI List -> Add KPI -> Save -> KPI List displays new record', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildAppWidget(
          home: EmployeeKpiListScreen(
            user: adminUser,
            kpiRepository: kpiRepository,
            employeeRepository: employeeRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state contains 5 records, verify initial metric
      expect(find.text('Employee Retention Rate'), findsOneWidget);
      expect(find.text('Brand New Automated Workflow'), findsNothing);

      // Tap Add KPI button
      final addBtn = find.byKey(const Key('kpi_add_button'));
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // We are on AddEmployeeKpiScreen
      expect(
        find.byKey(const Key('add_employee_kpi_scaffold')),
        findsOneWidget,
      );

      // Enter details
      await tester.enterText(
        find.byKey(const Key('add_kpi_metric_field')),
        'Brand New Automated Workflow',
      );
      await tester.enterText(
        find.byKey(const Key('add_kpi_target_field')),
        '100',
      );
      await tester.enterText(
        find.byKey(const Key('add_kpi_actual_field')),
        '105',
      );
      await tester.enterText(
        find.byKey(const Key('add_kpi_score_field')),
        '98',
      );
      await tester.enterText(
        find.byKey(const Key('add_kpi_remarks_field')),
        'Workflow optimized for throughput',
      );

      // Submit
      final submitBtn = find.byKey(const Key('add_kpi_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Should have returned to EmployeeKpiListScreen
      expect(
        find.byKey(const Key('employee_kpi_list_scaffold')),
        findsOneWidget,
      );

      // New record is now visible in the list
      expect(find.text('Brand New Automated Workflow'), findsOneWidget);
    });

    testWidgets(
      'KPI Details -> Edit KPI -> Save -> Details refreshed with updated values',
      (tester) async {
        await tester.pumpWidget(
          buildAppWidget(
            home: EmployeeKpiDetailsScreen(
              user: adminUser,
              kpiId: 'kpi_101',
              kpiRepository: kpiRepository,
              employeeRepository: employeeRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify initial details
        expect(find.text('Employee Retention Rate'), findsOneWidget);
        expect(find.text('90.0'), findsOneWidget);
        expect(find.text('92.5'), findsOneWidget);
        expect(find.text('95.0'), findsOneWidget);

        // Tap Edit button in AppBar
        final editBtn = find.byKey(const Key('kpi_details_edit_button'));
        expect(editBtn, findsOneWidget);
        await tester.tap(editBtn);
        await tester.pumpAndSettle();

        // We are on EditEmployeeKpiScreen
        expect(
          find.byKey(const Key('edit_employee_kpi_scaffold')),
          findsOneWidget,
        );

        // Edit fields
        await tester.enterText(
          find.byKey(const Key('edit_kpi_metric_field')),
          'Upgraded Retention Metric',
        );
        await tester.enterText(
          find.byKey(const Key('edit_kpi_target_field')),
          '92.0',
        );
        await tester.enterText(
          find.byKey(const Key('edit_kpi_actual_field')),
          '95.5',
        );
        await tester.enterText(
          find.byKey(const Key('edit_kpi_score_field')),
          '97.0',
        );

        // Submit update
        final updateSubmitBtn = find.byKey(const Key('edit_kpi_submit_button'));
        await tester.ensureVisible(updateSubmitBtn);
        await tester.tap(updateSubmitBtn);
        await tester.pumpAndSettle();

        // Should have returned to EmployeeKpiDetailsScreen
        expect(
          find.byKey(const Key('employee_kpi_details_scaffold')),
          findsOneWidget,
        );

        // Details view refreshed with updated values
        expect(find.text('Upgraded Retention Metric'), findsOneWidget);
        expect(find.text('92.0'), findsOneWidget);
        expect(find.text('95.5'), findsOneWidget);
        expect(find.text('97.0'), findsOneWidget);
      },
    );
  });
}
