/// Represents an attendance record for an employee on a specific calendar date.
///
/// Follows HR-4 frozen business requirements:
/// - Stably associated with an [employeeId].
/// - [date] is normalized to UTC calendar date (midnight UTC).
/// - [attendanceStatus] is a flexible value-object string (e.g. 'Present', 'Absent', 'Half-day', 'On Leave').
/// - Working hours and payroll calculations are strictly excluded.
class AttendanceRecord {
  final String id;
  final String employeeId;
  final DateTime date;
  final String attendanceStatus;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String? remarks;
  final String? recordedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required DateTime date,
    required this.attendanceStatus,
    this.checkIn,
    this.checkOut,
    this.remarks,
    this.recordedBy,
    this.createdAt,
    this.updatedAt,
  }) : date = DateTime.utc(date.year, date.month, date.day);

  /// Returns true if this record matches the given calendar date (year, month, day).
  bool isSameDay(DateTime other) {
    return date.year == other.year &&
        date.month == other.month &&
        date.day == other.day;
  }

  /// Formatted date string in YYYY-MM-DD format.
  String get formattedDate {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Formatted check-in time string (HH:mm) if present.
  String? get formattedCheckIn {
    if (checkIn == null) return null;
    final h = checkIn!.hour.toString().padLeft(2, '0');
    final m = checkIn!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Formatted check-out time string (HH:mm) if present.
  String? get formattedCheckOut {
    if (checkOut == null) return null;
    final h = checkOut!.hour.toString().padLeft(2, '0');
    final m = checkOut!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  AttendanceRecord copyWith({
    String? id,
    String? employeeId,
    DateTime? date,
    String? attendanceStatus,
    DateTime? checkIn,
    DateTime? checkOut,
    String? remarks,
    String? recordedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      remarks: remarks ?? this.remarks,
      recordedBy: recordedBy ?? this.recordedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendanceRecord &&
        other.id == id &&
        other.employeeId == employeeId &&
        other.date == date &&
        other.attendanceStatus == attendanceStatus &&
        other.checkIn == checkIn &&
        other.checkOut == checkOut &&
        other.remarks == remarks &&
        other.recordedBy == recordedBy;
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    date,
    attendanceStatus,
    checkIn,
    checkOut,
    remarks,
    recordedBy,
  );
}
