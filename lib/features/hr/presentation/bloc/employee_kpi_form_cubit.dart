import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/employee_kpi_repository.dart';
import 'employee_kpi_form_state.dart';

/// Cubit managing validation, submission, and mutation state for KPI creation and updates.
class EmployeeKpiFormCubit extends Cubit<EmployeeKpiFormState> {
  final EmployeeKpiRepository _repository;

  EmployeeKpiFormCubit({required EmployeeKpiRepository repository})
    : _repository = repository,
      super(const EmployeeKpiFormState());

  /// Submits creation of a new KPI record.
  Future<void> submitCreate({
    required String employeeId,
    required String metricName,
    required DateTime periodStart,
    required DateTime periodEnd,
    required double targetValue,
    required double actualValue,
    double? score,
    String? remarks,
  }) async {
    if (state.isSubmitting) return;

    if (employeeId.trim().isEmpty) {
      emit(
        state.copyWith(
          status: EmployeeKpiFormStatus.failure,
          errorMessage: 'An employee must be selected.',
        ),
      );
      return;
    }

    if (metricName.trim().isEmpty) {
      emit(
        state.copyWith(
          status: EmployeeKpiFormStatus.failure,
          errorMessage: 'Metric name is required.',
        ),
      );
      return;
    }

    final normalizedStart = DateTime.utc(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    );
    final normalizedEnd = DateTime.utc(
      periodEnd.year,
      periodEnd.month,
      periodEnd.day,
    );

    if (normalizedEnd.isBefore(normalizedStart)) {
      emit(
        state.copyWith(
          status: EmployeeKpiFormStatus.failure,
          errorMessage: 'Period end date cannot precede start date.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: EmployeeKpiFormStatus.submitting,
        clearError: true,
      ),
    );

    try {
      final kpi = await _repository.createKpi(
        employeeId: employeeId.trim(),
        metricName: metricName.trim(),
        periodStart: normalizedStart,
        periodEnd: normalizedEnd,
        targetValue: targetValue,
        actualValue: actualValue,
        score: score,
        remarks: remarks?.trim(),
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EmployeeKpiFormStatus.success,
          createdOrUpdatedKpi: kpi,
        ),
      );
    } on EmployeeKpiException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EmployeeKpiFormStatus.failure,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EmployeeKpiFormStatus.failure,
          errorMessage: 'Failed to create KPI. Please try again.',
        ),
      );
    }
  }

  /// Submits update of an existing KPI record.
  Future<void> submitUpdate({
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
  }) async {
    if (state.isSubmitting) return;

    if (metricName.trim().isEmpty) {
      emit(
        state.copyWith(
          status: EmployeeKpiFormStatus.failure,
          errorMessage: 'Metric name is required.',
        ),
      );
      return;
    }

    final normalizedStart = DateTime.utc(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    );
    final normalizedEnd = DateTime.utc(
      periodEnd.year,
      periodEnd.month,
      periodEnd.day,
    );

    if (normalizedEnd.isBefore(normalizedStart)) {
      emit(
        state.copyWith(
          status: EmployeeKpiFormStatus.failure,
          errorMessage: 'Period end date cannot precede start date.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: EmployeeKpiFormStatus.submitting,
        clearError: true,
      ),
    );

    try {
      final kpi = await _repository.updateKpi(
        id: id,
        metricName: metricName.trim(),
        periodStart: normalizedStart,
        periodEnd: normalizedEnd,
        targetValue: targetValue,
        actualValue: actualValue,
        score: score,
        clearScore: clearScore,
        remarks: remarks?.trim(),
        clearRemarks: clearRemarks,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EmployeeKpiFormStatus.success,
          createdOrUpdatedKpi: kpi,
        ),
      );
    } on EmployeeKpiException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EmployeeKpiFormStatus.failure,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EmployeeKpiFormStatus.failure,
          errorMessage: 'Failed to update KPI. Please try again.',
        ),
      );
    }
  }
}
