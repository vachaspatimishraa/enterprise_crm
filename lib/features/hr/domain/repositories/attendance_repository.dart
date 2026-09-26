import '../entities/attendance_record.dart';

/// Contract for managing employee attendance records.
///
/// Follows repository patterns established across the Enterprise CRM.
abstract interface class AttendanceRepository {
  /// Retrieves attendance records, optionally filtered by [employeeId],
  /// [startDate], [endDate], and [status].
  Future<List<AttendanceRecord>> getAttendanceRecords({
    String? employeeId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  });

  /// Retrieves an individual attendance record by its unique [id].
  Future<AttendanceRecord?> getAttendanceById(String id);

  /// Retrieves all attendance records for a specific [employeeId],
  /// optionally bounded by [startDate] and [endDate].
  Future<List<AttendanceRecord>> getAttendanceForEmployee(
    String employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Retrieves all attendance records for a specific calendar [date].
  Future<List<AttendanceRecord>> getAttendanceForDate(DateTime date);

  /// Records or updates an attendance entry.
  Future<AttendanceRecord> recordAttendance(AttendanceRecord record);
}

/// Domain exception thrown when an attendance repository operation fails.
class AttendanceException implements Exception {
  final String message;
  final String? code;

  const AttendanceException(this.message, {this.code});

  @override
  String toString() =>
      'AttendanceException: $message${code != null ? ' (code: $code)' : ''}';
}
