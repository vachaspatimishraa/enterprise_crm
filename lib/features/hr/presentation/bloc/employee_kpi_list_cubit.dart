import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/employee_kpi.dart';
import '../../domain/repositories/employee_kpi_repository.dart';
import 'employee_kpi_list_state.dart';

/// Cubit managing state for loading, searching, and filtering Employee KPI records.
///
/// Follows repository and Cubit conventions established across the Enterprise CRM HR module.
class EmployeeKpiListCubit extends Cubit<EmployeeKpiListState> {
  final EmployeeKpiRepository _repository;
  Map<String, String> _employeeNameMap = const {};

  EmployeeKpiListCubit({
    required EmployeeKpiRepository repository,
    String? initialEmployeeId,
    Map<String, String>? employeeNameMap,
  }) : _repository = repository,
       _employeeNameMap = employeeNameMap != null
           ? Map.unmodifiable(employeeNameMap)
           : const {},
       super(EmployeeKpiListState(selectedEmployeeId: initialEmployeeId));

  /// Updates the employee ID to name mapping for search resolution.
  void updateEmployeeNameMap(Map<String, String> map) {
    _employeeNameMap = Map.unmodifiable(map);
    _applyLocalFilters();
  }

  /// Loads KPI records from the repository applying current active filters.
  Future<void> loadKpis() async {
    emit(state.copyWith(status: EmployeeKpiListStatus.loading));

    try {
      final records = await _repository.getKpis(
        employeeId: state.selectedEmployeeId,
        startDate: state.startDate,
        endDate: state.endDate,
      );

      if (isClosed) return;

      final filtered = _filterRecords(
        source: records,
        query: state.searchQuery,
        metric: state.selectedMetric,
      );

      emit(
        state.copyWith(
          status: EmployeeKpiListStatus.loaded,
          kpis: records,
          filteredKpis: filtered,
          clearError: true,
        ),
      );
    } on EmployeeKpiException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EmployeeKpiListStatus.failure,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EmployeeKpiListStatus.failure,
          errorMessage:
              'Failed to load employee KPI records. Please try again.',
        ),
      );
    }
  }

  /// Sets or clears the employee filter and reloads KPI records.
  Future<void> setEmployeeFilter(String? employeeId) async {
    final normalized = employeeId?.trim();
    emit(
      state.copyWith(
        selectedEmployeeId: normalized,
        clearEmployeeId: normalized == null || normalized.isEmpty,
      ),
    );
    await loadKpis();
  }

  /// Sets or clears date boundaries and reloads KPI records.
  Future<void> setDateRangeFilter({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    emit(
      state.copyWith(
        startDate: startDate,
        clearStartDate: startDate == null,
        endDate: endDate,
        clearEndDate: endDate == null,
      ),
    );
    await loadKpis();
  }

  /// Sets the search query and filters records locally without re-querying repository.
  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
    _applyLocalFilters();
  }

  /// Sets or clears the metric filter and filters records locally.
  void setSelectedMetric(String? metric) {
    emit(
      state.copyWith(
        selectedMetric: metric,
        clearSelectedMetric: metric == null || metric.isEmpty,
      ),
    );
    _applyLocalFilters();
  }

  /// Clears all search, metric, employee, and period filters and reloads all records.
  Future<void> resetFilters() async {
    emit(
      state.copyWith(
        searchQuery: '',
        clearSelectedMetric: true,
        clearEmployeeId: true,
        clearStartDate: true,
        clearEndDate: true,
      ),
    );
    await loadKpis();
  }

  /// Reloads the KPI records using the currently active filters.
  Future<void> reload() async {
    await loadKpis();
  }

  void _applyLocalFilters() {
    final filtered = _filterRecords(
      source: state.kpis,
      query: state.searchQuery,
      metric: state.selectedMetric,
    );
    emit(state.copyWith(filteredKpis: filtered));
  }

  List<EmployeeKpi> _filterRecords({
    required List<EmployeeKpi> source,
    required String query,
    required String? metric,
  }) {
    final trimmedQuery = query.trim().toLowerCase();

    return source.where((kpi) {
      if (metric != null && metric.isNotEmpty && metric != 'All') {
        if (kpi.metricName.toLowerCase() != metric.toLowerCase()) {
          return false;
        }
      }

      if (trimmedQuery.isNotEmpty) {
        final metricMatch = kpi.metricName.toLowerCase().contains(trimmedQuery);
        final employeeName =
            _employeeNameMap[kpi.employeeId]?.toLowerCase() ?? '';
        final employeeMatch = employeeName.contains(trimmedQuery);
        final idMatch = kpi.employeeId.toLowerCase().contains(trimmedQuery);

        if (!metricMatch && !employeeMatch && !idMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}
