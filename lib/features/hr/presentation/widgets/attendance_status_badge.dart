import 'package:flutter/material.dart';

/// Reusable badge widget for displaying attendance status.
class AttendanceStatusBadge extends StatelessWidget {
  final String status;

  const AttendanceStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (Color bg, Color fg, IconData icon) = _styleForStatus(colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            status,
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

  (Color, Color, IconData) _styleForStatus(ColorScheme scheme) {
    switch (status.trim().toLowerCase()) {
      case 'present':
        return (
          Colors.green.shade100,
          Colors.green.shade900,
          Icons.check_circle_outline,
        );
      case 'absent':
        return (
          Colors.red.shade100,
          Colors.red.shade900,
          Icons.cancel_outlined,
        );
      case 'half-day':
        return (
          Colors.amber.shade100,
          Colors.amber.shade900,
          Icons.timelapse_outlined,
        );
      case 'on leave':
        return (
          Colors.blue.shade100,
          Colors.blue.shade900,
          Icons.event_busy_outlined,
        );
      default:
        return (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          Icons.help_outline,
        );
    }
  }
}
