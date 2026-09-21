import '../../../leads/domain/entities/lead.dart';
import '../../domain/entities/follow_up_status.dart';
import '../../domain/entities/follow_up_timing.dart';
import '../../domain/entities/lead_call_activity.dart';
import '../../domain/entities/lead_follow_up.dart';

/// Presentation model combining an authorized [Lead] with a scheduled [LeadFollowUp].
class FollowUpQueueItem {
  final Lead lead;
  final LeadFollowUp followUp;
  final LeadCallActivity? activity;
  final FollowUpTiming timing;

  FollowUpQueueItem({
    required this.lead,
    LeadFollowUp? followUp,
    this.activity,
    required this.timing,
  }) : followUp = followUp ??
            LeadFollowUp(
              id: activity?.id ?? 'follow-up-legacy',
              leadId: lead.id,
              sourceCallActivityId: activity?.id ?? '',
              scheduledAt: activity?.rescheduleAt ?? DateTime.now(),
              status: FollowUpStatus.pending,
              createdAt: activity?.createdAt ?? DateTime.now(),
              updatedAt: activity?.createdAt ?? DateTime.now(),
            );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowUpQueueItem &&
          runtimeType == other.runtimeType &&
          lead.id == other.lead.id &&
          followUp.id == other.followUp.id &&
          activity?.id == other.activity?.id &&
          timing == other.timing;

  @override
  int get hashCode => Object.hash(lead.id, followUp.id, activity?.id, timing);
}

/// Filter options for timing classification in the calling follow-up queue.
enum FollowUpTimingFilter { all, overdue, dueToday, upcoming }
