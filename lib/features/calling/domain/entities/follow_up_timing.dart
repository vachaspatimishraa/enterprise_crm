/// Timing classification for scheduled call follow-up activities.
///
/// In CALL-1B, scheduled follow-ups are history-derived without a completion
/// lifecycle: past scheduled activities are classified as [overdue].
enum FollowUpTiming {
  /// The reschedule timestamp is strictly before the reference timestamp [now].
  overdue,

  /// The reschedule timestamp is on or after [now] and shares the same local
  /// calendar date as [now].
  dueToday,

  /// The reschedule timestamp is on a future calendar date strictly after today.
  upcoming,
}

/// Pure deterministic classifier for scheduled follow-up timing against [now].
///
/// Rules:
/// - `rescheduleAt < now` -> [FollowUpTiming.overdue] (past events from earlier
///   today are overdue, never due today).
/// - `rescheduleAt >= now` AND same calendar day -> [FollowUpTiming.dueToday].
/// - `rescheduleAt` calendar date strictly after today -> [FollowUpTiming.upcoming].
FollowUpTiming classifyFollowUpTiming(DateTime rescheduleAt, DateTime now) {
  if (rescheduleAt.isBefore(now)) {
    return FollowUpTiming.overdue;
  }

  final isSameDay =
      rescheduleAt.year == now.year &&
      rescheduleAt.month == now.month &&
      rescheduleAt.day == now.day;

  if (isSameDay) {
    return FollowUpTiming.dueToday;
  }

  return FollowUpTiming.upcoming;
}
