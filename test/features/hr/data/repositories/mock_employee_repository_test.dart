import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employment_status.dart';
import 'package:enterprise_crm/features/hr/domain/inputs/create_employee_input.dart';
import 'package:enterprise_crm/features/hr/domain/inputs/update_employee_input.dart';
import 'package:enterprise_crm/features/hr/domain/repositories/employee_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockEmployeeRepository repository;

  setUp(() {
    repository = MockEmployeeRepository();
  });

  group('MockEmployeeRepository', () {
    test(
      'getEmployees returns deterministic seeded employees sorted by name A-Z',
      () async {
        final employees = await repository.getEmployees();
        expect(employees, isNotEmpty);
        expect(employees.length, 5);

        // Verify deterministic alphabetical order
        for (int i = 0; i < employees.length - 1; i++) {
          expect(
            employees[i].fullName.toLowerCase().compareTo(
              employees[i + 1].fullName.toLowerCase(),
            ),
            lessThanOrEqualTo(0),
          );
        }
      },
    );

    test('getEmployeeById returns matching record when exists', () async {
      final employee = await repository.getEmployeeById('emp_1');
      expect(employee, isNotNull);
      expect(employee!.fullName, 'Alice Johnson');
      expect(employee.employeeCode, 'EMP-001');
    });

    test('getEmployeeById returns null when ID is not found', () async {
      final employee = await repository.getEmployeeById('emp_nonexistent');
      expect(employee, isNull);
    });

    test('createEmployee creates record and updates list', () async {
      final input = CreateEmployeeInput(
        fullName: 'New Hire',
        employeeCode: 'EMP-999',
        email: 'new.hire@enterprise.com',
        phone: '+1 555-0999',
        department: 'Engineering',
        designation: 'Junior Developer',
        employmentStatus: EmploymentStatus.probation,
        joiningDate: DateTime(2025, 1, 1),
      );

      final created = await repository.createEmployee(input);
      expect(created.id, startsWith('emp_'));
      expect(created.fullName, 'New Hire');
      expect(created.employeeCode, 'EMP-999');

      final fetched = await repository.getEmployeeById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.fullName, 'New Hire');

      final all = await repository.getEmployees();
      expect(all.length, 6);
    });

    test('createEmployee rejects empty full name', () async {
      const input = CreateEmployeeInput(fullName: '   ');
      expect(
        () => repository.createEmployee(input),
        throwsA(isA<EmployeeException>()),
      );
    });

    test(
      'createEmployee rejects duplicate employee code (case-insensitive)',
      () async {
        const input = CreateEmployeeInput(
          fullName: 'Duplicate Code Person',
          employeeCode: 'emp-001', // already used by Alice
        );
        expect(
          () => repository.createEmployee(input),
          throwsA(
            isA<EmployeeException>().having(
              (e) => e.message,
              'message',
              contains('already in use'),
            ),
          ),
        );
      },
    );

    test('createEmployee rejects invalid email format without @', () async {
      const input = CreateEmployeeInput(
        fullName: 'Bad Email Person',
        email: 'bad-email-without-at',
      );
      expect(
        () => repository.createEmployee(input),
        throwsA(
          isA<EmployeeException>().having(
            (e) => e.message,
            'message',
            contains('valid email'),
          ),
        ),
      );
    });

    test('updateEmployee updates existing record successfully', () async {
      const input = UpdateEmployeeInput(
        id: 'emp_2',
        fullName: 'Robert Miller',
        employeeCode: 'EMP-002-MOD',
        department: 'Logistics Central',
        designation: 'Director of Logistics',
        employmentStatus: EmploymentStatus.active,
      );

      final updated = await repository.updateEmployee(input);
      expect(updated.fullName, 'Robert Miller');
      expect(updated.employeeCode, 'EMP-002-MOD');
      expect(updated.department, 'Logistics Central');

      final fetched = await repository.getEmployeeById('emp_2');
      expect(fetched!.fullName, 'Robert Miller');
    });

    test('updateEmployee throws when employee does not exist', () async {
      const input = UpdateEmployeeInput(
        id: 'emp_missing',
        fullName: 'Ghost Person',
        employmentStatus: EmploymentStatus.active,
      );
      expect(
        () => repository.updateEmployee(input),
        throwsA(isA<EmployeeException>()),
      );
    });
  });
}
