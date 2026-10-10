import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employee.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employment_status.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/edit_employee_screen.dart';
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

  final sampleEmployee = Employee(
    id: 'emp_1',
    employeeCode: 'EMP-001',
    fullName: 'Alice Johnson',
    email: 'alice.johnson@enterprise.com',
    phone: '+1 555-0101',
    department: 'Human Resources',
    designation: 'HR Manager',
    employmentStatus: EmploymentStatus.active,
  );

  setUp(() {
    repository = MockEmployeeRepository();
  });

  Widget buildTestWidget({required CurrentUser user}) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 1200)),
        child: EditEmployeeScreen(
          user: user,
          employee: sampleEmployee,
          repository: repository,
        ),
      ),
    );
  }

  group('EditEmployeeScreen', () {
    testWidgets('non-admin user is blocked with AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: hrStandardUser));
      await tester.pumpAndSettle();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.byKey(const Key('edit_employee_scaffold')), findsNothing);
    });

    testWidgets('admin user sees prefilled edit form', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit_employee_scaffold')), findsOneWidget);
      expect(find.text('Alice Johnson'), findsOneWidget);
      expect(find.text('EMP-001'), findsOneWidget);
      expect(find.text('Human Resources'), findsOneWidget);
      expect(find.text('HR Manager'), findsOneWidget);
    });

    testWidgets('validation rejects empty name on update', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('edit_employee_name_field')),
        '',
      );
      final submitBtn = find.byKey(const Key('edit_employee_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter employee full name'), findsOneWidget);
    });

    testWidgets('successful save updates record in repository', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('edit_employee_name_field')),
        'Alice Johnson-Smith',
      );
      await tester.enterText(
        find.byKey(const Key('edit_employee_designation_field')),
        'VP of People',
      );

      final submitBtn = find.byKey(const Key('edit_employee_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      final updated = await repository.getEmployeeById('emp_1');
      expect(updated!.fullName, 'Alice Johnson-Smith');
      expect(updated.designation, 'VP of People');
    });
  });
}
