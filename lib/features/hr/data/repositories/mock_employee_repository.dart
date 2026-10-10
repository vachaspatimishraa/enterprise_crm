import '../../domain/entities/employee.dart';
import '../../domain/inputs/create_employee_input.dart';
import '../../domain/inputs/update_employee_input.dart';
import '../../domain/repositories/employee_repository.dart';
import '../mock/mock_employee_store.dart';

/// In-memory mock implementation of [EmployeeRepository].
///
/// Wraps [MockEmployeeStore] to simulate asynchronous repository calls
/// with defensive copies and consistent error handling.
class MockEmployeeRepository implements EmployeeRepository {
  final MockEmployeeStore _store;

  MockEmployeeRepository({MockEmployeeStore? store})
    : _store = store ?? MockEmployeeStore();

  @override
  Future<List<Employee>> getEmployees() async {
    return _store.getAll();
  }

  @override
  Future<Employee?> getEmployeeById(String id) async {
    return _store.getById(id);
  }

  @override
  Future<Employee> createEmployee(CreateEmployeeInput input) async {
    return _store.create(input);
  }

  @override
  Future<Employee> updateEmployee(UpdateEmployeeInput input) async {
    return _store.update(input);
  }
}
