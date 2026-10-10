import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/employee.dart';
import '../../domain/policies/hr_access_policy.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../bloc/attendance_list_cubit.dart';
import '../bloc/attendance_list_state.dart';
import '../widgets/attendance_status_badge.dart';
import 'attendance_details_dialog.dart';

/// Screen presenting the dedicated attendance history for a single [Employee].
class EmployeeAttendanceHistoryScreen extends StatelessWidget {
  final CurrentUser user;
  final Employee employee;
  final AttendanceRepository repository;

  const EmployeeAttendanceHistoryScreen({
    super.key,
    required this.user,
    required this.employee,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    if (!HrAccessPolicy.canViewHrRecords(user)) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider(
      create: (_) =>
          AttendanceListCubit(repository, initialEmployeeId: employee.id)
            ..loadAttendance(),
      child: _EmployeeAttendanceHistoryView(user: user, employee: employee),
    );
  }
}

class _EmployeeAttendanceHistoryView extends StatelessWidget {
  final CurrentUser user;
  final Employee employee;

  const _EmployeeAttendanceHistoryView({
    required this.user,
    required this.employee,
  });

  void _openDetails(BuildContext context, AttendanceRecord record) {
    AttendanceDetailsDialog.show(context, record);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<AttendanceListCubit, AttendanceListState>(
      builder: (context, state) {
        final records = state.records;
        final totalDays = records.length;
        final presentCount = records
            .where((r) => r.attendanceStatus.toLowerCase() == 'present')
            .length;
        final halfDayCount = records
            .where((r) => r.attendanceStatus.toLowerCase() == 'half-day')
            .length;
        final absentCount = records
            .where((r) => r.attendanceStatus.toLowerCase() == 'absent')
            .length;
        final leaveCount = records
            .where((r) => r.attendanceStatus.toLowerCase() == 'on leave')
            .length;

        return Scaffold(
          key: const Key('employee_attendance_history_scaffold'),
          appBar: AppBar(
            title: Text('${employee.fullName} — Attendance'),
            actions: [
              IconButton(
                key: const Key('attendance_history_refresh_button'),
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => context.read<AttendanceListCubit>().refresh(),
              ),
            ],
          ),
          body: Column(
            children: [
              // Summary Metrics Card
              Card(
                margin: const EdgeInsets.all(16.0),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Employee: ${employee.fullName} (${employee.employeeCode ?? employee.id})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatChip(
                              'Total Days',
                              '$totalDays',
                              colorScheme.primaryContainer,
                              colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            _buildStatChip(
                              'Present',
                              '$presentCount',
                              Colors.green.shade100,
                              Colors.green.shade900,
                            ),
                            const SizedBox(width: 8),
                            _buildStatChip(
                              'Half-day',
                              '$halfDayCount',
                              Colors.amber.shade100,
                              Colors.amber.shade900,
                            ),
                            const SizedBox(width: 8),
                            _buildStatChip(
                              'Absent',
                              '$absentCount',
                              Colors.red.shade100,
                              Colors.red.shade900,
                            ),
                            const SizedBox(width: 8),
                            _buildStatChip(
                              'Leave',
                              '$leaveCount',
                              Colors.blue.shade100,
                              Colors.blue.shade900,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Attendance Records Body
              Expanded(
                child: _buildRecordsList(context, state, theme, colorScheme),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip(String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: fg)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList(
    BuildContext context,
    AttendanceListState state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.isFailure) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(state.errorMessage ?? 'Error loading history.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<AttendanceListCubit>().refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.filteredRecords.isEmpty) {
      return const Center(
        child: Text(
          'No attendance records found for this employee.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      key: const Key('employee_attendance_history_list'),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: state.filteredRecords.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final r = state.filteredRecords[index];
        return Card(
          key: Key('employee_history_card_${r.id}'),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: InkWell(
            onTap: () => _openDetails(context, r),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.formattedDate,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'In: ${r.formattedCheckIn ?? '—'}  |  Out: ${r.formattedCheckOut ?? '—'}',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        if (r.remarks != null && r.remarks!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            r.remarks!,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AttendanceStatusBadge(status: r.attendanceStatus),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
