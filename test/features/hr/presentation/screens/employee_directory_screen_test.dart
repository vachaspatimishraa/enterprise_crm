import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_directory_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockEmployeeRepository repository;

  const adminUser = CurrentUser(
    id: 'usr_admin',
    displayName: 'Admin User',
    accountType: AccountType.admin,
    modules: {},
    permissions: {},
  );

  const hrStandardUser = CurrentUser(
    id: 'usr_hr',
    displayName: 'HR Specialist',
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
    repository = MockEmployeeRepository();
  });

  Widget buildTestWidget({
    required CurrentUser user,
    Size size = const Size(800, 1000),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: EmployeeDirectoryScreen(user: user, repository: repository),
      ),
    );
  }

  group('EmployeeDirectoryScreen', () {
    testWidgets('unauthorized user sees AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: unauthorizedUser));
      await tester.pumpAndSettle();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(
        find.byKey(const Key('employee_directory_scaffold')),
        findsNothing,
      );
    });

    testWidgets(
      'authorized standard user sees directory without Add Employee button',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(user: hrStandardUser));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('employee_directory_scaffold')),
          findsOneWidget,
        );
        expect(find.text('Employee Directory'), findsOneWidget);
        expect(
          find.byKey(const Key('employee_directory_add_button')),
          findsNothing,
        );
        expect(find.text('Alice Johnson'), findsOneWidget);
      },
    );

    testWidgets('admin user sees Add Employee floating action button', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('employee_directory_add_button')),
        findsOneWidget,
      );
    });

    testWidgets('mobile layout renders cards (< 600px width)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('employee_mobile_list')), findsOneWidget);
      expect(find.byKey(const Key('employee_card_emp_1')), findsOneWidget);
      expect(
        find.byKey(const Key('employee_desktop_table_scroll')),
        findsNothing,
      );
    });

    testWidgets('desktop layout renders table (>= 600px width)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('employee_desktop_table_scroll')),
        findsOneWidget,
      );
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Alice Johnson'), findsOneWidget);
      expect(find.byKey(const Key('employee_mobile_list')), findsNothing);
    });

    testWidgets('search filters records by name', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      expect(find.text('Alice Johnson'), findsOneWidget);
      expect(find.text('Bob Miller'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('employee_search_field')),
        'Alice',
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Johnson'), findsOneWidget);
      expect(find.text('Bob Miller'), findsNothing);

      // Clear search via clear icon
      await tester.tap(find.byKey(const Key('employee_search_clear_button')));
      await tester.pumpAndSettle();

      expect(find.text('Bob Miller'), findsOneWidget);
    });

    testWidgets('status filter chips filter records', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      // Tap Probation filter
      await tester.tap(find.byKey(const Key('employee_status_chip_probation')));
      await tester.pumpAndSettle();

      expect(find.text('Dana White'), findsOneWidget);
      expect(find.text('Alice Johnson'), findsNothing);

      // Reset
      await tester.tap(find.byKey(const Key('employee_status_chip_all')));
      await tester.pumpAndSettle();

      expect(find.text('Alice Johnson'), findsOneWidget);
    });

    testWidgets('empty search shows empty state illustration', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('employee_search_field')),
        'completely_unknown_person_123',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('employee_directory_empty_icon')),
        findsOneWidget,
      );
      expect(find.text('No employees found'), findsOneWidget);
    });
  });
}
