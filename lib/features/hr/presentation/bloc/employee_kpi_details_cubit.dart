import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/employee_kpi_repository.dart';
import 'employee_kpi_details_state.dart';

/// Cubit managing state for viewing a specific Employee KPI record.
class EmployeeKpiDetailsCubit extends Cubit<EmployeeKpiDetailsState> {
  final EmployeeKpiRepository _repository;

  EmployeeKpiDetailsCubit({required EmployeeKpiRepository repository})
    : _repository = repository,
      super(const EmployeeKpiDetailsState());

  /// Loads an individual KPI record by its unique identifier.
  Future<void> loadKpi(String id) async {
    emit(
      state.copyWith(status: EmployeeKpiDetailsStatus.loading, searchedId: id),
    );

    try {
      final kpi = await _repository.getKpiById(id);
      if (isClosed) return;

      if (kpi == null) {
        emit(
          state.copyWith(
            status: EmployeeKpiDetailsStatus.notFound,
            searchedId: id,
            clearKpi: true,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: EmployeeKpiDetailsStatus.loaded,
            kpi: kpi,
            clearError: true,
          ),
        );
      }
    } on EmployeeKpiException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EmployeeKpiDetailsStatus.failure,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EmployeeKpiDetailsStatus.failure,
          errorMessage: 'Failed to load KPI details. Please try again.',
        ),
      );
    }
  }

  /// Reloads the KPI record currently loaded or searched.
  Future<void> reload() async {
    final id = state.kpi?.id ?? state.searchedId;
    if (id != null) {
      await loadKpi(id);
    }
  }
}
