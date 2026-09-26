import '../entities/call_outcome.dart';
import '../entities/lead_call_activity.dart';
import '../entities/lead_follow_up.dart';

/// Result container for a recorded calling workflow outcome.
class RecordedCallingWorkflow {
  /// The immutable historical call activity recorded.
  final LeadCallActivity activity;

  /// The scheduled follow-up created if [activity.rescheduleAt] was non-null.
  final LeadFollowUp? followUp;

  const RecordedCallingWorkflow({required this.activity, this.followUp});
}

/// Domain abstraction coordinating call activity recording and follow-up creation.
///
/// Encapsulates mock/backend atomicity so the presentation layer does not coordinate
/// multiple repositories or expose rollback/compensation logic.
abstract interface class CallingWorkflowService {
  Future<RecordedCallingWorkflow> recordOutcome({
    required String leadId,
    required String performedByUserId,
    required CallOutcome outcome,
    DateTime? rescheduleAt,
  });
}
