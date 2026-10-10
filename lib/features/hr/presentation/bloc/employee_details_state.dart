import '../../domain/entities/employee.dart';

enum EmployeeDetailsStatus { initial, loading, loaded, notFound, failure }

class EmployeeDetailsState {
  final EmployeeDetailsStatus status;
  final Employee? employee;
  final String? errorMessage;
  final String? searchedId;

  const EmployeeDetailsState({
    this.status = EmployeeDetailsStatus.initial,
    this.employee,
    this.errorMessage,
    this.searchedId,
  });

  bool get isLoading => status == EmployeeDetailsStatus.loading;
  bool get isLoaded => status == EmployeeDetailsStatus.loaded;
  bool get isNotFound => status == EmployeeDetailsStatus.notFound;
  bool get isFailure => status == EmployeeDetailsStatus.failure;

  EmployeeDetailsState copyWith({
    EmployeeDetailsStatus? status,
    Employee? employee,
    String? errorMessage,
    String? searchedId,
  }) {
    return EmployeeDetailsState(
      status: status ?? this.status,
      employee: employee ?? this.employee,
      errorMessage: errorMessage ?? this.errorMessage,
      searchedId: searchedId ?? this.searchedId,
    );
  }
}
