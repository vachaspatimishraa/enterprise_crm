import 'package:flutter/foundation.dart';

import '../../domain/entities/employee_kpi.dart';

/// Statuses for Employee KPI Add / Edit Form operations.
enum EmployeeKpiFormStatus { initial, submitting, success, failure }

/// State representation for KPI Add and Edit forms.
@immutable
class EmployeeKpiFormState {
  final EmployeeKpiFormStatus status;
  final EmployeeKpi? createdOrUpdatedKpi;
  final String? errorMessage;

  const EmployeeKpiFormState({
    this.status = EmployeeKpiFormStatus.initial,
    this.createdOrUpdatedKpi,
    this.errorMessage,
  });

  bool get isSubmitting => status == EmployeeKpiFormStatus.submitting;
  bool get isSuccess => status == EmployeeKpiFormStatus.success;
  bool get isFailure => status == EmployeeKpiFormStatus.failure;

  EmployeeKpiFormState copyWith({
    EmployeeKpiFormStatus? status,
    EmployeeKpi? createdOrUpdatedKpi,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EmployeeKpiFormState(
      status: status ?? this.status,
      createdOrUpdatedKpi: createdOrUpdatedKpi ?? this.createdOrUpdatedKpi,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmployeeKpiFormState &&
        other.status == status &&
        other.createdOrUpdatedKpi == createdOrUpdatedKpi &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(status, createdOrUpdatedKpi, errorMessage);

  @override
  String toString() =>
      'EmployeeKpiFormState(status: $status, kpi: ${createdOrUpdatedKpi?.id}, error: $errorMessage)';
}
