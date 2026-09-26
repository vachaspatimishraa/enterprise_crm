import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/add_employee_screen.dart';
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

  setUp(() {
    repository = MockEmployeeRepository();
  });

  Widget buildTestWidget({required CurrentUser user}) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 1200)),
        child: AddEmployeeScreen(user: user, repository: repository),
      ),
    );
  }

  group('AddEmployeeScreen', () {
    testWidgets('non-admin user is blocked with AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: hrStandardUser));
      await tester.pumpAndSettle();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.byKey(const Key('add_employee_scaffold')), findsNothing);
    });

    testWidgets('admin user sees creation form', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_employee_scaffold')), findsOneWidget);
      expect(find.text('Add Employee'), findsOneWidget);
      expect(find.byKey(const Key('add_employee_name_field')), findsOneWidget);
    });

    testWidgets('validation rejects empty name', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const Key('add_employee_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter employee full name'), findsOneWidget);
    });

    testWidgets('validation rejects invalid email', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('add_employee_name_field')),
        'Valid Person Name',
      );
      await tester.enterText(
        find.byKey(const Key('add_employee_email_field')),
        'invalid_email_format',
      );

      final submitBtn = find.byKey(const Key('add_employee_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('successful submission creates employee in repository', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('add_employee_name_field')),
        'Zachary Vance',
      );
      await tester.enterText(
        find.byKey(const Key('add_employee_code_field')),
        'EMP-777',
      );
      await tester.enterText(
        find.byKey(const Key('add_employee_dept_field')),
        'Legal',
      );
      await tester.enterText(
        find.byKey(const Key('add_employee_designation_field')),
        'Legal Counsel',
      );

      final submitBtn = find.byKey(const Key('add_employee_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      final employees = await repository.getEmployees();
      expect(employees.any((e) => e.fullName == 'Zachary Vance'), isTrue);
    });
  });
}
