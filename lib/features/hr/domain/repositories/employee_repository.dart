import '../entities/employee.dart';
import '../inputs/create_employee_input.dart';
import '../inputs/update_employee_input.dart';

/// Abstract domain repository interface for HR Employee management.
///
/// UI widgets and Cubits depend exclusively on this abstraction rather
/// than concrete mock or network data sources.
abstract interface class EmployeeRepository {
  /// Retrieves all employee records in deterministic order.
  Future<List<Employee>> getEmployees();

  /// Retrieves an employee by their stable unique identifier [id], or `null` if not found.
  Future<Employee?> getEmployeeById(String id);

  /// Creates a new employee record.
  ///
  /// Throws [EmployeeException] on validation failure or duplicate code.
  Future<Employee> createEmployee(CreateEmployeeInput input);

  /// Updates an existing employee record.
  ///
  /// Throws [EmployeeException] if not found or on validation failure.
  Future<Employee> updateEmployee(UpdateEmployeeInput input);
}

/// Represents an operational failure in the HR Employee domain.
class EmployeeException implements Exception {
  final String message;

  const EmployeeException(this.message);

  @override
  String toString() => message;
}
