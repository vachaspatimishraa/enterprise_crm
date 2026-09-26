import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import 'attendance_list_state.dart';

/// Cubit managing attendance listing, calendar view, filtering, and search.
class AttendanceListCubit extends Cubit<AttendanceListState> {
  final AttendanceRepository _repository;
  final String? initialEmployeeId;

  AttendanceListCubit(this._repository, {this.initialEmployeeId})
    : super(AttendanceListState(selectedEmployeeId: initialEmployeeId));

  /// Loads attendance records from the repository.
  Future<void> loadAttendance() async {
    emit(state.copyWith(status: AttendanceListStatus.loading));
    try {
      final records = await _repository.getAttendanceRecords(
        employeeId: state.selectedEmployeeId,
      );

      final filtered = _applyFilters(
        records,
        state.searchQuery,
        state.selectedStatus,
        state.selectedDate,
        state.selectedEmployeeId,
      );

      emit(
        state.copyWith(
          status: AttendanceListStatus.loaded,
          records: records,
          filteredRecords: filtered,
          errorMessage: () => null,
        ),
      );
    } on AttendanceException catch (e) {
      emit(
        state.copyWith(
          status: AttendanceListStatus.failure,
          errorMessage: () => e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: AttendanceListStatus.failure,
          errorMessage: () =>
              'Failed to load attendance records. Please try again.',
        ),
      );
    }
  }

  /// Sets the search query and filters records locally.
  void setSearchQuery(String query) {
    final filtered = _applyFilters(
      state.records,
      query,
      state.selectedStatus,
      state.selectedDate,
      state.selectedEmployeeId,
    );
    emit(state.copyWith(searchQuery: query, filteredRecords: filtered));
  }

  /// Sets the status filter (e.g. 'Present', 'Absent', 'Half-day', 'On Leave').
  void setStatusFilter(String? status) {
    final filtered = _applyFilters(
      state.records,
      state.searchQuery,
      status,
      state.selectedDate,
      state.selectedEmployeeId,
    );
    emit(
      state.copyWith(selectedStatus: () => status, filteredRecords: filtered),
    );
  }

  /// Sets the selected calendar/filter date.
  void setSelectedDate(DateTime? date) {
    final normalized = date != null
        ? DateTime.utc(date.year, date.month, date.day)
        : null;
    final filtered = _applyFilters(
      state.records,
      state.searchQuery,
      state.selectedStatus,
      normalized,
      state.selectedEmployeeId,
    );
    emit(
      state.copyWith(selectedDate: () => normalized, filteredRecords: filtered),
    );
  }

  /// Sets employee filter.
  void setSelectedEmployeeId(String? employeeId) {
    final filtered = _applyFilters(
      state.records,
      state.searchQuery,
      state.selectedStatus,
      state.selectedDate,
      employeeId,
    );
    emit(
      state.copyWith(
        selectedEmployeeId: () => employeeId,
        filteredRecords: filtered,
      ),
    );
  }

  /// Switches between list and calendar views.
  void setViewMode(AttendanceViewMode mode) {
    emit(state.copyWith(viewMode: mode));
  }

  /// Clears active search and filter constraints.
  void resetFilters() {
    final filtered = _applyFilters(
      state.records,
      '',
      null,
      null,
      initialEmployeeId,
    );
    emit(
      state.copyWith(
        searchQuery: '',
        selectedStatus: () => null,
        selectedDate: () => null,
        selectedEmployeeId: () => initialEmployeeId,
        filteredRecords: filtered,
      ),
    );
  }

  /// Refreshes attendance from repository while preserving current filters.
  Future<void> refresh() async {
    await loadAttendance();
  }

  List<AttendanceRecord> _applyFilters(
    List<AttendanceRecord> all,
    String query,
    String? status,
    DateTime? date,
    String? employeeId,
  ) {
    return all.where((r) {
      if (employeeId != null && employeeId.trim().isNotEmpty) {
        if (r.employeeId != employeeId.trim()) return false;
      }

      if (status != null && status.trim().isNotEmpty) {
        if (r.attendanceStatus.trim().toLowerCase() !=
            status.trim().toLowerCase()) {
          return false;
        }
      }

      if (date != null) {
        if (!r.isSameDay(date)) return false;
      }

      if (query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchesEmployee = r.employeeId.toLowerCase().contains(q);
        final matchesStatus = r.attendanceStatus.toLowerCase().contains(q);
        final matchesRemarks = r.remarks?.toLowerCase().contains(q) ?? false;
        final matchesDate = r.formattedDate.contains(q);

        if (!matchesEmployee &&
            !matchesStatus &&
            !matchesRemarks &&
            !matchesDate) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}
