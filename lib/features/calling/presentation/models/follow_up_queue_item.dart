import '../../../leads/domain/entities/lead.dart';
import '../../domain/entities/follow_up_timing.dart';
import '../../domain/entities/lead_call_activity.dart';

/// Presentation model combining an authorized [Lead] with a scheduled [LeadCallActivity].
class FollowUpQueueItem {
  final Lead lead;
  final LeadCallActivity activity;
  final FollowUpTiming timing;

  const FollowUpQueueItem({
    required this.lead,
    required this.activity,
    required this.timing,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowUpQueueItem &&
          runtimeType == other.runtimeType &&
          lead.id == other.lead.id &&
          activity.id == other.activity.id &&
          timing == other.timing;

  @override
  int get hashCode => Object.hash(lead.id, activity.id, timing);
}

/// Filter options for timing classification in the calling follow-up queue.
enum FollowUpTimingFilter { all, overdue, dueToday, upcoming }
