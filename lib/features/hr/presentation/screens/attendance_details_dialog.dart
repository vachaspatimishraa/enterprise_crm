import 'package:flutter/material.dart';

import '../../domain/entities/attendance_record.dart';
import '../widgets/attendance_status_badge.dart';

/// Modal dialog displaying full metadata for an [AttendanceRecord].
class AttendanceDetailsDialog extends StatelessWidget {
  final AttendanceRecord record;

  const AttendanceDetailsDialog({super.key, required this.record});

  static Future<void> show(BuildContext context, AttendanceRecord record) {
    return showDialog(
      context: context,
      builder: (_) => AttendanceDetailsDialog(record: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      key: const Key('attendance_details_dialog'),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Attendance Details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          AttendanceStatusBadge(status: record.attendanceStatus),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRow(context, 'Record ID', record.id),
              _buildRow(context, 'Employee ID', record.employeeId),
              _buildRow(context, 'Date', record.formattedDate),
              _buildRow(context, 'Check In', record.formattedCheckIn ?? '—'),
              _buildRow(context, 'Check Out', record.formattedCheckOut ?? '—'),
              _buildRow(context, 'Remarks', record.remarks ?? '—'),
              if (record.recordedBy != null)
                _buildRow(context, 'Recorded By', record.recordedBy!),
              if (record.createdAt != null)
                _buildRow(
                  context,
                  'Created At',
                  '${record.createdAt!.year}-${record.createdAt!.month.toString().padLeft(2, '0')}-${record.createdAt!.day.toString().padLeft(2, '0')}',
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('attendance_details_close_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
