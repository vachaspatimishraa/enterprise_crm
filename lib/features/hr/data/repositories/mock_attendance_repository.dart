import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../mock/mock_attendance_store.dart';

/// Mock implementation of [AttendanceRepository] backed by [MockAttendanceStore].
///
/// Follows project architecture and patterns from [MockEmployeeRepository] and
/// [MockEmployeeDocumentRepository].
class MockAttendanceRepository implements AttendanceRepository {
  final MockAttendanceStore _store;

  MockAttendanceRepository({MockAttendanceStore? store})
    : _store = store ?? MockAttendanceStore();

  @override
  Future<List<AttendanceRecord>> getAttendanceRecords({
    String? employeeId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    return _store.getAttendanceRecords(
      employeeId: employeeId,
      startDate: startDate,
      endDate: endDate,
      status: status,
    );
  }

  @override
  Future<AttendanceRecord?> getAttendanceById(String id) async {
    return _store.getAttendanceById(id);
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceForEmployee(
    String employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _store.getAttendanceForEmployee(
      employeeId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceForDate(DateTime date) async {
    return _store.getAttendanceForDate(date);
  }

  @override
  Future<AttendanceRecord> recordAttendance(AttendanceRecord record) async {
    return _store.recordAttendance(record);
  }
}
