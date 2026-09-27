import '../entities/employee_kpi.dart';

/// Abstract domain repository interface for HR Employee KPI management.
///
/// Follows pure repository patterns established across the Enterprise CRM.
/// Presentation Cubits and future UI screens depend exclusively on this abstraction.
abstract interface class EmployeeKpiRepository {
  /// Retrieves all KPI records, optionally filtered by [employeeId],
  /// [startDate], and [endDate].
  Future<List<EmployeeKpi>> getKpis({
    String? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Retrieves all KPI records associated with a specific [employeeId],
  /// optionally bounded by [startDate] and [endDate].
  Future<List<EmployeeKpi>> getKpisForEmployee(
    String employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Retrieves an individual KPI record by its unique [id], or `null` if not found.
  Future<EmployeeKpi?> getKpiById(String id);
}

/// Domain exception thrown when an employee KPI repository operation fails.
class EmployeeKpiException implements Exception {
  final String message;
  final String? code;

  const EmployeeKpiException(this.message, {this.code});

  @override
  String toString() =>
      'EmployeeKpiException: $message${code != null ? ' (code: $code)' : ''}';
}
