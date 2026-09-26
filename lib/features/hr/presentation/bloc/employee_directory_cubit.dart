import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/employee.dart';
import '../../domain/entities/employment_status.dart';
import '../../domain/repositories/employee_repository.dart';
import 'employee_directory_state.dart';

/// Cubit managing state for the Employee Directory workspace.
class EmployeeDirectoryCubit extends Cubit<EmployeeDirectoryState> {
  final EmployeeRepository _repository;

  EmployeeDirectoryCubit({required EmployeeRepository repository})
    : _repository = repository,
      super(const EmployeeDirectoryState());

  /// Loads all employee records from repository and applies active filters.
  Future<void> loadEmployees() async {
    emit(state.copyWith(status: EmployeeDirectoryStatus.loading));

    try {
      final employees = await _repository.getEmployees();
      final filtered = _applyFiltersAndSort(
        employees: employees,
        query: state.searchQuery,
        department: state.selectedDepartment,
        status: state.selectedStatus,
        sort: state.sortOption,
      );

      emit(
        state.copyWith(
          status: EmployeeDirectoryStatus.loaded,
          employees: employees,
          filteredEmployees: filtered,
          clearError: true,
        ),
      );
    } on EmployeeException catch (e) {
      emit(
        state.copyWith(
          status: EmployeeDirectoryStatus.failure,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: EmployeeDirectoryStatus.failure,
          errorMessage: 'Failed to load employee directory. Please try again.',
        ),
      );
    }
  }

  /// Refreshes employee records while maintaining current filters.
  Future<void> refresh() async {
    await loadEmployees();
  }

  /// Sets the search query filter.
  void setSearchQuery(String query) {
    final filtered = _applyFiltersAndSort(
      employees: state.employees,
      query: query,
      department: state.selectedDepartment,
      status: state.selectedStatus,
      sort: state.sortOption,
    );
    emit(state.copyWith(searchQuery: query, filteredEmployees: filtered));
  }

  /// Sets or clears the department filter.
  void setDepartmentFilter(String? department) {
    final filtered = _applyFiltersAndSort(
      employees: state.employees,
      query: state.searchQuery,
      department: department,
      status: state.selectedStatus,
      sort: state.sortOption,
    );
    emit(
      state.copyWith(
        selectedDepartment: department,
        clearDepartment: department == null,
        filteredEmployees: filtered,
      ),
    );
  }

  /// Sets or clears the employment status filter.
  void setStatusFilter(EmploymentStatus? status) {
    final filtered = _applyFiltersAndSort(
      employees: state.employees,
      query: state.searchQuery,
      department: state.selectedDepartment,
      status: status,
      sort: state.sortOption,
    );
    emit(
      state.copyWith(
        selectedStatus: status,
        clearStatus: status == null,
        filteredEmployees: filtered,
      ),
    );
  }

  /// Changes the sort option and reapplies sorting.
  void setSortOption(EmployeeSortOption sortOption) {
    final filtered = _applyFiltersAndSort(
      employees: state.employees,
      query: state.searchQuery,
      department: state.selectedDepartment,
      status: state.selectedStatus,
      sort: sortOption,
    );
    emit(state.copyWith(sortOption: sortOption, filteredEmployees: filtered));
  }

  /// Clears all active filters and search queries.
  void resetFilters() {
    final filtered = _applyFiltersAndSort(
      employees: state.employees,
      query: '',
      department: null,
      status: null,
      sort: EmployeeSortOption.nameAsc,
    );
    emit(
      state.copyWith(
        searchQuery: '',
        clearDepartment: true,
        clearStatus: true,
        sortOption: EmployeeSortOption.nameAsc,
        filteredEmployees: filtered,
      ),
    );
  }

  List<Employee> _applyFiltersAndSort({
    required List<Employee> employees,
    required String query,
    required String? department,
    required EmploymentStatus? status,
    required EmployeeSortOption sort,
  }) {
    final trimmedQuery = query.trim().toLowerCase();

    var results = employees.where((emp) {
      if (trimmedQuery.isNotEmpty) {
        final nameMatch = emp.fullName.toLowerCase().contains(trimmedQuery);
        final codeMatch =
            emp.employeeCode?.toLowerCase().contains(trimmedQuery) ?? false;
        final deptMatch =
            emp.department?.toLowerCase().contains(trimmedQuery) ?? false;
        final desigMatch =
            emp.designation?.toLowerCase().contains(trimmedQuery) ?? false;
        final emailMatch =
            emp.email?.toLowerCase().contains(trimmedQuery) ?? false;

        if (!nameMatch &&
            !codeMatch &&
            !deptMatch &&
            !desigMatch &&
            !emailMatch) {
          return false;
        }
      }

      if (department != null && department.isNotEmpty) {
        if (emp.department?.toLowerCase() != department.toLowerCase()) {
          return false;
        }
      }

      if (status != null) {
        if (emp.employmentStatus != status) {
          return false;
        }
      }

      return true;
    }).toList();

    switch (sort) {
      case EmployeeSortOption.nameAsc:
        results.sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );
        break;
      case EmployeeSortOption.nameDesc:
        results.sort(
          (a, b) =>
              b.fullName.toLowerCase().compareTo(a.fullName.toLowerCase()),
        );
        break;
      case EmployeeSortOption.codeAsc:
        results.sort((a, b) {
          final codeA = a.employeeCode ?? '';
          final codeB = b.employeeCode ?? '';
          return codeA.compareTo(codeB);
        });
        break;
      case EmployeeSortOption.joiningDateDesc:
        results.sort((a, b) {
          if (a.joiningDate == null && b.joiningDate == null) return 0;
          if (a.joiningDate == null) return 1;
          if (b.joiningDate == null) return -1;
          return b.joiningDate!.compareTo(a.joiningDate!);
        });
        break;
    }

    return results;
  }
}
