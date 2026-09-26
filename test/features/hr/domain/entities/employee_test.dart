import 'package:enterprise_crm/features/hr/domain/entities/employee.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employment_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmploymentStatus', () {
    test('supports string value and case-insensitive equality', () {
      const status1 = EmploymentStatus('Active');
      final status2 = EmploymentStatus.fromString('active');
      expect(status1, equals(status2));
      expect(status1.value, 'Active');
      expect(status1.toString(), 'Active');
    });

    test('predefined statuses have expected values', () {
      expect(EmploymentStatus.active.value, 'Active');
      expect(EmploymentStatus.probation.value, 'Probation');
      expect(EmploymentStatus.inactive.value, 'Inactive');
    });
  });

  group('Employee Entity', () {
    final employee = Employee(
      id: 'emp_101',
      employeeCode: 'EMP-101',
      fullName: 'Jane Doe',
      email: 'jane.doe@enterprise.com',
      phone: '+1 555-0199',
      department: 'Engineering',
      designation: 'Staff Engineer',
      employmentStatus: EmploymentStatus.active,
      joiningDate: DateTime(2023, 1, 1),
      userId: 'usr_jane',
    );

    test('retains all properties correctly', () {
      expect(employee.id, 'emp_101');
      expect(employee.employeeCode, 'EMP-101');
      expect(employee.fullName, 'Jane Doe');
      expect(employee.email, 'jane.doe@enterprise.com');
      expect(employee.phone, '+1 555-0199');
      expect(employee.department, 'Engineering');
      expect(employee.designation, 'Staff Engineer');
      expect(employee.employmentStatus, EmploymentStatus.active);
      expect(employee.isActive, isTrue);
      expect(employee.hasLinkedUser, isTrue);
    });

    test('copyWith updates specified fields and preserves others', () {
      final updated = employee.copyWith(
        fullName: 'Jane Smith',
        designation: 'Principal Engineer',
      );
      expect(updated.id, 'emp_101');
      expect(updated.fullName, 'Jane Smith');
      expect(updated.designation, 'Principal Engineer');
      expect(updated.department, 'Engineering');
    });

    test('copyWith clearUserId clears linked user', () {
      final updated = employee.copyWith(clearUserId: true);
      expect(updated.userId, isNull);
      expect(updated.hasLinkedUser, isFalse);
    });

    test('equality and hashCode adhere to value equality', () {
      final clone = Employee(
        id: 'emp_101',
        employeeCode: 'EMP-101',
        fullName: 'Jane Doe',
        email: 'jane.doe@enterprise.com',
        phone: '+1 555-0199',
        department: 'Engineering',
        designation: 'Staff Engineer',
        employmentStatus: EmploymentStatus.active,
        joiningDate: DateTime(2023, 1, 1),
        userId: 'usr_jane',
      );
      expect(employee, equals(clone));
      expect(employee.hashCode, equals(clone.hashCode));
    });
  });
}
