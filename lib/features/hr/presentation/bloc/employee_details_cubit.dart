import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/employee_repository.dart';
import 'employee_details_state.dart';

/// Cubit managing state for viewing a specific Employee record.
class EmployeeDetailsCubit extends Cubit<EmployeeDetailsState> {
  final EmployeeRepository _repository;

  EmployeeDetailsCubit({required EmployeeRepository repository})
    : _repository = repository,
      super(const EmployeeDetailsState());

  /// Loads an employee record by their stable unique identifier.
  Future<void> loadEmployee(String id) async {
    emit(state.copyWith(status: EmployeeDetailsStatus.loading, searchedId: id));

    try {
      final employee = await _repository.getEmployeeById(id);
      if (employee == null) {
        emit(
          state.copyWith(
            status: EmployeeDetailsStatus.notFound,
            searchedId: id,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: EmployeeDetailsStatus.loaded,
            employee: employee,
          ),
        );
      }
    } on EmployeeException catch (e) {
      emit(
        state.copyWith(
          status: EmployeeDetailsStatus.failure,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: EmployeeDetailsStatus.failure,
          errorMessage: 'Failed to load employee details. Please try again.',
        ),
      );
    }
  }

  /// Reloads the employee currently loaded or searched.
  Future<void> reload() async {
    final id = state.employee?.id ?? state.searchedId;
    if (id != null) {
      await loadEmployee(id);
    }
  }
}
