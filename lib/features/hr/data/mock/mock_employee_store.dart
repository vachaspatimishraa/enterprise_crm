import '../../domain/entities/employee.dart';
import '../../domain/entities/employment_status.dart';
import '../../domain/inputs/create_employee_input.dart';
import '../../domain/inputs/update_employee_input.dart';
import '../../domain/repositories/employee_repository.dart';

/// In-memory mock store for HR Employee records.
///
/// Provides deterministic seeding, immutable defensive copies, and validation.
class MockEmployeeStore {
  final Map<String, Employee> _employees = {};
  int _sequence = 100;

  MockEmployeeStore() {
    _seedDefaultEmployees();
  }

  void _seedDefaultEmployees() {
    final seedRecords = [
      Employee(
        id: 'emp_1',
        employeeCode: 'EMP-001',
        fullName: 'Alice Johnson',
        email: 'alice.johnson@enterprise.com',
        phone: '+1 555-0101',
        department: 'Human Resources',
        designation: 'HR Manager',
        employmentStatus: EmploymentStatus.active,
        joiningDate: DateTime(2023, 3, 15),
        userId: 'usr_admin',
        createdAt: DateTime(2023, 3, 15),
      ),
      Employee(
        id: 'emp_2',
        employeeCode: 'EMP-002',
        fullName: 'Bob Miller',
        email: 'bob.miller@enterprise.com',
        phone: '+1 555-0102',
        department: 'Inventory & Logistics',
        designation: 'Warehouse Supervisor',
        employmentStatus: EmploymentStatus.active,
        joiningDate: DateTime(2023, 6, 1),
        userId: null,
        createdAt: DateTime(2023, 6, 1),
      ),
      Employee(
        id: 'emp_3',
        employeeCode: 'EMP-003',
        fullName: 'Charlie Davis',
        email: 'charlie.davis@enterprise.com',
        phone: '+1 555-0103',
        department: 'Sales & Marketing',
        designation: 'Senior Account Executive',
        employmentStatus: EmploymentStatus.active,
        joiningDate: DateTime(2024, 1, 10),
        userId: 'usr_user',
        createdAt: DateTime(2024, 1, 10),
      ),
      Employee(
        id: 'emp_4',
        employeeCode: 'EMP-004',
        fullName: 'Dana White',
        email: 'dana.white@enterprise.com',
        phone: '+1 555-0104',
        department: 'Customer Operations',
        designation: 'Support Specialist',
        employmentStatus: EmploymentStatus.probation,
        joiningDate: DateTime(2025, 11, 20),
        userId: null,
        createdAt: DateTime(2025, 11, 20),
      ),
      Employee(
        id: 'emp_5',
        employeeCode: 'EMP-005',
        fullName: 'Evan Wright',
        email: 'evan.wright@enterprise.com',
        phone: '+1 555-0105',
        department: 'Finance & Accounts',
        designation: 'Financial Analyst',
        employmentStatus: EmploymentStatus.inactive,
        joiningDate: DateTime(2022, 8, 5),
        userId: null,
        createdAt: DateTime(2022, 8, 5),
      ),
    ];

    for (final emp in seedRecords) {
      _employees[emp.id] = emp;
    }
  }

  /// Resets store to initial seed state.
  void reset() {
    _employees.clear();
    _sequence = 100;
    _seedDefaultEmployees();
  }

  List<Employee> getAll() {
    final list = _employees.values.toList();
    list.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return List.unmodifiable(list);
  }

  Employee? getById(String id) {
    return _employees[id];
  }

  Employee create(CreateEmployeeInput input) {
    final trimmedName = input.fullName.trim();
    if (trimmedName.isEmpty) {
      throw const EmployeeException('Full name is required.');
    }

    final trimmedCode = input.employeeCode?.trim();
    if (trimmedCode != null && trimmedCode.isNotEmpty) {
      final codeExists = _employees.values.any(
        (e) =>
            e.employeeCode != null &&
            e.employeeCode!.toLowerCase() == trimmedCode.toLowerCase(),
      );
      if (codeExists) {
        throw EmployeeException(
          'Employee code "$trimmedCode" is already in use.',
        );
      }
    }

    final trimmedEmail = input.email?.trim();
    if (trimmedEmail != null &&
        trimmedEmail.isNotEmpty &&
        !trimmedEmail.contains('@')) {
      throw const EmployeeException('Please enter a valid email address.');
    }

    _sequence++;
    final newId = 'emp_$_sequence';
    final now = DateTime.now();

    final created = Employee(
      id: newId,
      employeeCode: (trimmedCode != null && trimmedCode.isNotEmpty)
          ? trimmedCode
          : 'EMP-$_sequence',
      fullName: trimmedName,
      email: (trimmedEmail != null && trimmedEmail.isNotEmpty)
          ? trimmedEmail
          : null,
      phone: input.phone?.trim(),
      department: input.department?.trim(),
      designation: input.designation?.trim(),
      employmentStatus: input.employmentStatus,
      joiningDate: input.joiningDate,
      userId: input.userId?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    _employees[newId] = created;
    return created;
  }

  Employee update(UpdateEmployeeInput input) {
    final existing = _employees[input.id];
    if (existing == null) {
      throw EmployeeException('Employee with id "${input.id}" not found.');
    }

    final trimmedName = input.fullName.trim();
    if (trimmedName.isEmpty) {
      throw const EmployeeException('Full name is required.');
    }

    final trimmedCode = input.employeeCode?.trim();
    if (trimmedCode != null && trimmedCode.isNotEmpty) {
      final codeExists = _employees.values.any(
        (e) =>
            e.id != input.id &&
            e.employeeCode != null &&
            e.employeeCode!.toLowerCase() == trimmedCode.toLowerCase(),
      );
      if (codeExists) {
        throw EmployeeException(
          'Employee code "$trimmedCode" is already in use by another record.',
        );
      }
    }

    final trimmedEmail = input.email?.trim();
    if (trimmedEmail != null &&
        trimmedEmail.isNotEmpty &&
        !trimmedEmail.contains('@')) {
      throw const EmployeeException('Please enter a valid email address.');
    }

    final now = DateTime.now();
    final updated = existing.copyWith(
      fullName: trimmedName,
      employeeCode: trimmedCode,
      email: (trimmedEmail != null && trimmedEmail.isNotEmpty)
          ? trimmedEmail
          : null,
      phone: input.phone?.trim(),
      department: input.department?.trim(),
      designation: input.designation?.trim(),
      employmentStatus: input.employmentStatus,
      joiningDate: input.joiningDate,
      userId: input.userId?.trim(),
      clearUserId: input.clearUserId,
      updatedAt: now,
    );

    _employees[input.id] = updated;
    return updated;
  }
}
