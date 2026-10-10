import 'package:enterprise_crm/features/hr/domain/entities/attendance_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendanceRecord Domain Entity Tests', () {
    test('normalizes date to UTC midnight', () {
      final dateWithTime = DateTime(2026, 9, 21, 14, 30, 45);
      final record = AttendanceRecord(
        id: 'att_01',
        employeeId: 'emp_1',
        date: dateWithTime,
        attendanceStatus: 'Present',
      );

      expect(record.date.isUtc, isTrue);
      expect(record.date.year, equals(2026));
      expect(record.date.month, equals(9));
      expect(record.date.day, equals(21));
      expect(record.date.hour, equals(0));
      expect(record.date.minute, equals(0));
      expect(record.date.second, equals(0));
    });

    test('formattedDate returns YYYY-MM-DD string', () {
      final record = AttendanceRecord(
        id: 'att_01',
        employeeId: 'emp_1',
        date: DateTime.utc(2026, 9, 5),
        attendanceStatus: 'Present',
      );

      expect(record.formattedDate, equals('2026-09-05'));
    });

    test('formattedCheckIn and formattedCheckOut format properly', () {
      final record = AttendanceRecord(
        id: 'att_01',
        employeeId: 'emp_1',
        date: DateTime.utc(2026, 9, 21),
        attendanceStatus: 'Present',
        checkIn: DateTime.utc(2026, 9, 21, 9, 5),
        checkOut: DateTime.utc(2026, 9, 21, 18, 30),
      );

      expect(record.formattedCheckIn, equals('09:05'));
      expect(record.formattedCheckOut, equals('18:30'));
    });

    test('isSameDay matches correct calendar day', () {
      final record = AttendanceRecord(
        id: 'att_01',
        employeeId: 'emp_1',
        date: DateTime.utc(2026, 9, 21),
        attendanceStatus: 'Present',
      );

      expect(record.isSameDay(DateTime(2026, 9, 21, 10, 0)), isTrue);
      expect(record.isSameDay(DateTime(2026, 9, 22)), isFalse);
    });

    test('copyWith preserves fields when null and overrides when provided', () {
      final record = AttendanceRecord(
        id: 'att_01',
        employeeId: 'emp_1',
        date: DateTime.utc(2026, 9, 21),
        attendanceStatus: 'Present',
        remarks: 'Original remark',
      );

      final updated = record.copyWith(
        attendanceStatus: 'Half-day',
        remarks: 'Updated remark',
      );

      expect(updated.id, equals('att_01'));
      expect(updated.employeeId, equals('emp_1'));
      expect(updated.attendanceStatus, equals('Half-day'));
      expect(updated.remarks, equals('Updated remark'));
    });
  });
}
