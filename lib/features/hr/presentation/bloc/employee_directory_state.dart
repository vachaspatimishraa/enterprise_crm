import '../../domain/entities/employee.dart';
import '../../domain/entities/employment_status.dart';

enum EmployeeDirectoryStatus { initial, loading, loaded, failure }

enum EmployeeSortOption {
  nameAsc('Name (A-Z)'),
  nameDesc('Name (Z-A)'),
  codeAsc('Employee Code (A-Z)'),
  joiningDateDesc('Joining Date (Newest)');

  final String label;
  const EmployeeSortOption(this.label);
}

class EmployeeDirectoryState {
  final EmployeeDirectoryStatus status;
  final List<Employee> employees;
  final List<Employee> filteredEmployees;
  final String searchQuery;
  final String? selectedDepartment;
  final EmploymentStatus? selectedStatus;
  final EmployeeSortOption sortOption;
  final String? errorMessage;

  const EmployeeDirectoryState({
    this.status = EmployeeDirectoryStatus.initial,
    this.employees = const [],
    this.filteredEmployees = const [],
    this.searchQuery = '',
    this.selectedDepartment,
    this.selectedStatus,
    this.sortOption = EmployeeSortOption.nameAsc,
    this.errorMessage,
  });

  bool get isLoading => status == EmployeeDirectoryStatus.loading;
  bool get isLoaded => status == EmployeeDirectoryStatus.loaded;
  bool get isFailure => status == EmployeeDirectoryStatus.failure;
  bool get isEmpty => isLoaded && filteredEmployees.isEmpty;

  /// Returns unique department names present in the current employee dataset.
  Set<String> get availableDepartments {
    return employees
        .map((e) => e.department?.trim())
        .where((d) => d != null && d.isNotEmpty)
        .cast<String>()
        .toSet();
  }

  EmployeeDirectoryState copyWith({
    EmployeeDirectoryStatus? status,
    List<Employee>? employees,
    List<Employee>? filteredEmployees,
    String? searchQuery,
    String? selectedDepartment,
    bool clearDepartment = false,
    EmploymentStatus? selectedStatus,
    bool clearStatus = false,
    EmployeeSortOption? sortOption,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EmployeeDirectoryState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      filteredEmployees: filteredEmployees ?? this.filteredEmployees,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedDepartment: clearDepartment
          ? null
          : (selectedDepartment ?? this.selectedDepartment),
      selectedStatus: clearStatus
          ? null
          : (selectedStatus ?? this.selectedStatus),
      sortOption: sortOption ?? this.sortOption,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
