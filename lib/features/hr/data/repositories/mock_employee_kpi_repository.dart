import '../../domain/entities/employee_kpi.dart';
import '../../domain/repositories/employee_kpi_repository.dart';
import '../mock/mock_employee_kpi_store.dart';

/// Mock implementation of [EmployeeKpiRepository] backed by [MockEmployeeKpiStore].
///
/// Follows project architecture and patterns from [MockEmployeeRepository] and
/// [MockAttendanceRepository].
class MockEmployeeKpiRepository implements EmployeeKpiRepository {
  final MockEmployeeKpiStore _store;

  MockEmployeeKpiRepository({MockEmployeeKpiStore? store})
    : _store = store ?? MockEmployeeKpiStore();

  @override
  Future<List<EmployeeKpi>> getKpis({
    String? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _store.getKpis(
      employeeId: employeeId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<List<EmployeeKpi>> getKpisForEmployee(
    String employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _store.getKpisForEmployee(
      employeeId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<EmployeeKpi?> getKpiById(String id) async {
    return _store.getKpiById(id);
  }
}
