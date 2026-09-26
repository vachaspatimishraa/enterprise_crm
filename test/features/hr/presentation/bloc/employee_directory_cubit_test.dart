import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employment_status.dart';
import 'package:enterprise_crm/features/hr/domain/inputs/create_employee_input.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/employee_directory_cubit.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/employee_directory_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockEmployeeRepository repository;
  late EmployeeDirectoryCubit cubit;

  setUp(() {
    repository = MockEmployeeRepository();
    cubit = EmployeeDirectoryCubit(repository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  group('EmployeeDirectoryCubit', () {
    test('initial state has initial status and empty lists', () {
      expect(cubit.state.status, EmployeeDirectoryStatus.initial);
      expect(cubit.state.employees, isEmpty);
      expect(cubit.state.filteredEmployees, isEmpty);
      expect(cubit.state.searchQuery, '');
    });

    test('loadEmployees loads records and emits loaded state', () async {
      await cubit.loadEmployees();
      expect(cubit.state.status, EmployeeDirectoryStatus.loaded);
      expect(cubit.state.employees.length, 5);
      expect(cubit.state.filteredEmployees.length, 5);
      expect(cubit.state.availableDepartments, contains('Human Resources'));
      expect(cubit.state.availableDepartments, contains('Sales & Marketing'));
    });

    test(
      'setSearchQuery filters employees by name, department, designation, or code',
      () async {
        await cubit.loadEmployees();

        // Search by name
        cubit.setSearchQuery('Alice');
        expect(cubit.state.filteredEmployees.length, 1);
        expect(cubit.state.filteredEmployees.first.fullName, 'Alice Johnson');

        // Search by department
        cubit.setSearchQuery('Finance');
        expect(cubit.state.filteredEmployees.length, 1);
        expect(cubit.state.filteredEmployees.first.fullName, 'Evan Wright');

        // Search by code
        cubit.setSearchQuery('EMP-003');
        expect(cubit.state.filteredEmployees.length, 1);
        expect(cubit.state.filteredEmployees.first.fullName, 'Charlie Davis');

        // Non-matching query
        cubit.setSearchQuery('nonexistent_person_xyz');
        expect(cubit.state.filteredEmployees, isEmpty);
        expect(cubit.state.isEmpty, isTrue);
      },
    );

    test('setDepartmentFilter filters strictly by department', () async {
      await cubit.loadEmployees();

      cubit.setDepartmentFilter('Human Resources');
      expect(cubit.state.selectedDepartment, 'Human Resources');
      expect(cubit.state.filteredEmployees.length, 1);
      expect(cubit.state.filteredEmployees.first.department, 'Human Resources');

      cubit.setDepartmentFilter(null);
      expect(cubit.state.selectedDepartment, isNull);
      expect(cubit.state.filteredEmployees.length, 5);
    });

    test('setStatusFilter filters strictly by employment status', () async {
      await cubit.loadEmployees();

      cubit.setStatusFilter(EmploymentStatus.probation);
      expect(cubit.state.selectedStatus, EmploymentStatus.probation);
      expect(cubit.state.filteredEmployees.length, 1);
      expect(cubit.state.filteredEmployees.first.fullName, 'Dana White');

      cubit.setStatusFilter(null);
      expect(cubit.state.filteredEmployees.length, 5);
    });

    test('setSortOption sorts employees predictably', () async {
      await cubit.loadEmployees();

      // Name Descending
      cubit.setSortOption(EmployeeSortOption.nameDesc);
      expect(cubit.state.filteredEmployees.first.fullName, 'Evan Wright');
      expect(cubit.state.filteredEmployees.last.fullName, 'Alice Johnson');

      // Code Ascending
      cubit.setSortOption(EmployeeSortOption.codeAsc);
      expect(cubit.state.filteredEmployees.first.employeeCode, 'EMP-001');

      // Joining Date Descending
      cubit.setSortOption(EmployeeSortOption.joiningDateDesc);
      expect(
        cubit.state.filteredEmployees.first.fullName,
        'Dana White',
      ); // Nov 2025
    });

    test(
      'resetFilters restores all default filters and shows all employees',
      () async {
        await cubit.loadEmployees();

        cubit.setSearchQuery('Alice');
        cubit.setDepartmentFilter('Human Resources');
        cubit.setStatusFilter(EmploymentStatus.active);
        cubit.setSortOption(EmployeeSortOption.nameDesc);

        cubit.resetFilters();
        expect(cubit.state.searchQuery, '');
        expect(cubit.state.selectedDepartment, isNull);
        expect(cubit.state.selectedStatus, isNull);
        expect(cubit.state.sortOption, EmployeeSortOption.nameAsc);
        expect(cubit.state.filteredEmployees.length, 5);
      },
    );

    test('refresh preserves active filters while updating dataset', () async {
      await cubit.loadEmployees();
      cubit.setDepartmentFilter('Human Resources');
      expect(cubit.state.filteredEmployees.length, 1);

      // Add new HR employee in repository
      await repository.createEmployee(
        const CreateEmployeeInput(
          fullName: 'Helen Troy',
          department: 'Human Resources',
          designation: 'HR Coordinator',
        ),
      );

      await cubit.refresh();
      expect(cubit.state.selectedDepartment, 'Human Resources');
      expect(cubit.state.filteredEmployees.length, 2);
    });
  });
}
