import 'package:flutter/foundation.dart';

import '../../domain/entities/employee_kpi.dart';

/// Statuses for individual KPI details state.
enum EmployeeKpiDetailsStatus { initial, loading, loaded, notFound, failure }

/// State representation for viewing an individual Employee KPI record.
@immutable
class EmployeeKpiDetailsState {
  final EmployeeKpiDetailsStatus status;
  final EmployeeKpi? kpi;
  final String? searchedId;
  final String? errorMessage;

  const EmployeeKpiDetailsState({
    this.status = EmployeeKpiDetailsStatus.initial,
    this.kpi,
    this.searchedId,
    this.errorMessage,
  });

  EmployeeKpiDetailsState copyWith({
    EmployeeKpiDetailsStatus? status,
    EmployeeKpi? kpi,
    bool clearKpi = false,
    String? searchedId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EmployeeKpiDetailsState(
      status: status ?? this.status,
      kpi: clearKpi ? null : (kpi ?? this.kpi),
      searchedId: searchedId ?? this.searchedId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmployeeKpiDetailsState &&
        other.status == status &&
        other.kpi == kpi &&
        other.searchedId == searchedId &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(status, kpi, searchedId, errorMessage);

  @override
  String toString() =>
      'EmployeeKpiDetailsState(status: $status, kpi: ${kpi?.id}, searchedId: $searchedId, error: $errorMessage)';
}
