import '../../domain/entities/call_outcome.dart';
import '../../domain/entities/follow_up_timing.dart';

/// Formats a [FollowUpTiming] into its human-readable presentation label.
String formatFollowUpTiming(FollowUpTiming timing) {
  return switch (timing) {
    FollowUpTiming.overdue => 'Overdue',
    FollowUpTiming.dueToday => 'Due Today',
    FollowUpTiming.upcoming => 'Upcoming',
  };
}

/// Formats a [CallOutcome] into its frozen human-readable presentation label.
String formatCallOutcome(CallOutcome outcome) {
  return switch (outcome) {
    CallOutcome.followUp => 'Follow up',
    CallOutcome.notConnected => 'Not connected',
    CallOutcome.visitScheduled => 'Visit scheduled',
    CallOutcome.irrelevant => 'Irrelevant',
    CallOutcome.notInterested => 'Not interested',
    CallOutcome.leadClosed => 'Lead closed',
    CallOutcome.salesDone => 'Sales done',
    CallOutcome.dispatched => 'Dispatched',
  };
}

/// Formats a [DateTime] into a clean presentation string (e.g. `21 Sep 2026, 10:45 AM`).
String formatActivityDateTime(DateTime? dt) {
  if (dt == null) return '—';

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final day = dt.day.toString().padLeft(2, '0');
  final month = months[dt.month - 1];
  final year = dt.year;

  var hour = dt.hour;
  final period = hour >= 12 ? 'PM' : 'AM';
  if (hour == 0) {
    hour = 12;
  } else if (hour > 12) {
    hour -= 12;
  }

  final minute = dt.minute.toString().padLeft(2, '0');

  return '$day $month $year, $hour:$minute $period';
}
