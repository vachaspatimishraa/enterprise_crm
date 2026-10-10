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

  /// Creates a new KPI record and returns the persisted [EmployeeKpi].
  ///
  /// Throws [EmployeeKpiException] if validation fails or persistence errors occur.
  Future<EmployeeKpi> createKpi({
    required String employeeId,
    required String metricName,
    required DateTime periodStart,
    required DateTime periodEnd,
    required double targetValue,
    required double actualValue,
    double? score,
    String? remarks,
  });

  /// Updates an existing KPI record identified by [id] and returns the updated [EmployeeKpi].
  ///
  /// Throws [EmployeeKpiException] if the record is not found or update fails.
  Future<EmployeeKpi> updateKpi({
    required String id,
    required String metricName,
    required DateTime periodStart,
    required DateTime periodEnd,
    required double targetValue,
    required double actualValue,
    double? score,
    bool clearScore = false,
    String? remarks,
    bool clearRemarks = false,
  });
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
