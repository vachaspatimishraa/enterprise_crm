import 'package:enterprise_crm/features/hr/data/repositories/mock_attendance_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/attendance_list_cubit.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/attendance_list_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockAttendanceRepository repository;
  late AttendanceListCubit cubit;

  setUp(() {
    repository = MockAttendanceRepository();
    cubit = AttendanceListCubit(repository);
  });

  tearDown(() {
    cubit.close();
  });

  group('AttendanceListCubit Tests', () {
    test('initial state has initial status and empty records', () {
      expect(cubit.state.status, equals(AttendanceListStatus.initial));
      expect(cubit.state.records, isEmpty);
      expect(cubit.state.viewMode, equals(AttendanceViewMode.list));
    });

    test(
      'loadAttendance emits loading then loaded with seeded records',
      () async {
        await cubit.loadAttendance();

        expect(cubit.state.status, equals(AttendanceListStatus.loaded));
        expect(cubit.state.records.length, equals(12));
        expect(cubit.state.filteredRecords.length, equals(12));
      },
    );

    test('setSearchQuery filters records by query string', () async {
      await cubit.loadAttendance();

      cubit.setSearchQuery('casual leave');
      expect(cubit.state.filteredRecords.length, equals(1));
      expect(
        cubit.state.filteredRecords.first.attendanceStatus,
        equals('On Leave'),
      );
    });

    test('setStatusFilter filters records by attendance status', () async {
      await cubit.loadAttendance();

      cubit.setStatusFilter('Absent');
      expect(cubit.state.filteredRecords.length, equals(1));
      expect(cubit.state.filteredRecords.first.employeeId, equals('emp_2'));
    });

    test('setSelectedDate filters records to specific calendar date', () async {
      await cubit.loadAttendance();

      cubit.setSelectedDate(DateTime.utc(2026, 9, 21));
      expect(cubit.state.filteredRecords.length, equals(3));
      expect(
        cubit.state.filteredRecords.every(
          (r) => r.isSameDay(DateTime.utc(2026, 9, 21)),
        ),
        isTrue,
      );
    });

    test('setSelectedEmployeeId filters records to target employee', () async {
      await cubit.loadAttendance();

      cubit.setSelectedEmployeeId('emp_3');
      expect(cubit.state.filteredRecords.length, equals(2));
      expect(
        cubit.state.filteredRecords.every((r) => r.employeeId == 'emp_3'),
        isTrue,
      );
    });

    test('setViewMode switches view mode between list and calendar', () {
      expect(cubit.state.viewMode, equals(AttendanceViewMode.list));

      cubit.setViewMode(AttendanceViewMode.calendar);
      expect(cubit.state.viewMode, equals(AttendanceViewMode.calendar));

      cubit.setViewMode(AttendanceViewMode.list);
      expect(cubit.state.viewMode, equals(AttendanceViewMode.list));
    });

    test('resetFilters clears query, status, and date filters', () async {
      await cubit.loadAttendance();

      cubit.setSearchQuery('emp_1');
      cubit.setStatusFilter('Present');
      cubit.setSelectedDate(DateTime.utc(2026, 9, 21));
      expect(cubit.state.filteredRecords.length, equals(1));

      cubit.resetFilters();
      expect(cubit.state.searchQuery, isEmpty);
      expect(cubit.state.selectedStatus, isNull);
      expect(cubit.state.selectedDate, isNull);
      expect(cubit.state.filteredRecords.length, equals(12));
    });
  });
}
