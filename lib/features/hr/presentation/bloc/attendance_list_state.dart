import '../../domain/entities/attendance_record.dart';

enum AttendanceListStatus { initial, loading, loaded, failure }

enum AttendanceViewMode { list, calendar }

/// Immutable state for the Attendance Management workflow.
class AttendanceListState {
  final AttendanceListStatus status;
  final List<AttendanceRecord> records;
  final List<AttendanceRecord> filteredRecords;
  final String searchQuery;
  final String? selectedStatus;
  final DateTime? selectedDate;
  final String? selectedEmployeeId;
  final AttendanceViewMode viewMode;
  final String? errorMessage;

  const AttendanceListState({
    this.status = AttendanceListStatus.initial,
    this.records = const [],
    this.filteredRecords = const [],
    this.searchQuery = '',
    this.selectedStatus,
    this.selectedDate,
    this.selectedEmployeeId,
    this.viewMode = AttendanceViewMode.list,
    this.errorMessage,
  });

  bool get isInitial => status == AttendanceListStatus.initial;
  bool get isLoading => status == AttendanceListStatus.loading;
  bool get isLoaded => status == AttendanceListStatus.loaded;
  bool get isFailure => status == AttendanceListStatus.failure;
  bool get isEmpty => isLoaded && filteredRecords.isEmpty;

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      selectedStatus != null ||
      selectedDate != null ||
      selectedEmployeeId != null;

  /// Returns all records matching a specific calendar [day] (year, month, day).
  List<AttendanceRecord> recordsForDay(DateTime day) {
    return records.where((r) => r.isSameDay(day)).toList();
  }

  /// Returns true if there is at least one attendance record for [day].
  bool hasRecordsOnDay(DateTime day) {
    return records.any((r) => r.isSameDay(day));
  }

  AttendanceListState copyWith({
    AttendanceListStatus? status,
    List<AttendanceRecord>? records,
    List<AttendanceRecord>? filteredRecords,
    String? searchQuery,
    String? Function()? selectedStatus,
    DateTime? Function()? selectedDate,
    String? Function()? selectedEmployeeId,
    AttendanceViewMode? viewMode,
    String? Function()? errorMessage,
  }) {
    return AttendanceListState(
      status: status ?? this.status,
      records: records ?? this.records,
      filteredRecords: filteredRecords ?? this.filteredRecords,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedStatus: selectedStatus != null
          ? selectedStatus()
          : this.selectedStatus,
      selectedDate: selectedDate != null ? selectedDate() : this.selectedDate,
      selectedEmployeeId: selectedEmployeeId != null
          ? selectedEmployeeId()
          : this.selectedEmployeeId,
      viewMode: viewMode ?? this.viewMode,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendanceListState &&
        other.status == status &&
        other.searchQuery == searchQuery &&
        other.selectedStatus == selectedStatus &&
        other.selectedDate == selectedDate &&
        other.selectedEmployeeId == selectedEmployeeId &&
        other.viewMode == viewMode &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
    status,
    searchQuery,
    selectedStatus,
    selectedDate,
    selectedEmployeeId,
    viewMode,
    errorMessage,
  );
}
