import 'package:flutter/foundation.dart';

import '../../domain/entities/employee_kpi.dart';

/// Lifecycle statuses for employee KPI listing state.
enum EmployeeKpiListStatus { initial, loading, loaded, failure }

/// State representation for employee KPI listing, search, and filtering.
@immutable
class EmployeeKpiListState {
  final EmployeeKpiListStatus status;
  final List<EmployeeKpi> kpis;
  final List<EmployeeKpi> filteredKpis;
  final String? selectedEmployeeId;
  final String searchQuery;
  final String? selectedMetric;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? errorMessage;

  const EmployeeKpiListState({
    this.status = EmployeeKpiListStatus.initial,
    this.kpis = const [],
    this.filteredKpis = const [],
    this.selectedEmployeeId,
    this.searchQuery = '',
    this.selectedMetric,
    this.startDate,
    this.endDate,
    this.errorMessage,
  });

  /// True when repository returned zero records for the active employee/period scope.
  bool get isEmpty => status == EmployeeKpiListStatus.loaded && kpis.isEmpty;

  /// True when repository has records but none match active search/filters.
  bool get isFilteredEmpty =>
      status == EmployeeKpiListStatus.loaded &&
      kpis.isNotEmpty &&
      filteredKpis.isEmpty;

  /// Creates a copy of this state with specified updates.
  EmployeeKpiListState copyWith({
    EmployeeKpiListStatus? status,
    List<EmployeeKpi>? kpis,
    List<EmployeeKpi>? filteredKpis,
    String? selectedEmployeeId,
    bool clearEmployeeId = false,
    String? searchQuery,
    String? selectedMetric,
    bool clearSelectedMetric = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    final effectiveKpis = kpis != null
        ? List<EmployeeKpi>.unmodifiable(kpis)
        : this.kpis;
    final effectiveFiltered = filteredKpis != null
        ? List<EmployeeKpi>.unmodifiable(filteredKpis)
        : (kpis != null
              ? List<EmployeeKpi>.unmodifiable(kpis)
              : this.filteredKpis);

    return EmployeeKpiListState(
      status: status ?? this.status,
      kpis: effectiveKpis,
      filteredKpis: effectiveFiltered,
      selectedEmployeeId: clearEmployeeId
          ? null
          : (selectedEmployeeId ?? this.selectedEmployeeId),
      searchQuery: searchQuery ?? this.searchQuery,
      selectedMetric: clearSelectedMetric
          ? null
          : (selectedMetric ?? this.selectedMetric),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmployeeKpiListState &&
        other.status == status &&
        listEquals(other.kpis, kpis) &&
        listEquals(other.filteredKpis, filteredKpis) &&
        other.selectedEmployeeId == selectedEmployeeId &&
        other.searchQuery == searchQuery &&
        other.selectedMetric == selectedMetric &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAll(kpis),
    Object.hashAll(filteredKpis),
    selectedEmployeeId,
    searchQuery,
    selectedMetric,
    startDate,
    endDate,
    errorMessage,
  );

  @override
  String toString() =>
      'EmployeeKpiListState(status: $status, rawCount: ${kpis.length}, filteredCount: ${filteredKpis.length}, employeeId: $selectedEmployeeId, search: "$searchQuery", metric: $selectedMetric, error: $errorMessage)';
}
