import '../entities/call_outcome.dart';
import '../entities/lead_call_activity.dart';

/// Domain repository contract for lead call activities.
abstract interface class LeadCallActivityRepository {
  /// Returns all call activities recorded for the given [leadId], ordered newest first.
  Future<List<LeadCallActivity>> getActivitiesForLead(String leadId);

  /// Returns all scheduled call activities (where [rescheduleAt] is non-null)
  /// recorded for any of the given [leadIds], ordered earliest rescheduleAt first.
  ///
  /// If [leadIds] is empty, returns an empty list without wildcard interpretation.
  Future<List<LeadCallActivity>> getScheduledActivitiesForLeadIds(
    Set<String> leadIds,
  );

  /// Records a new call activity against the lead.
  Future<LeadCallActivity> recordActivity({
    required String leadId,
    required String performedByUserId,
    required CallOutcome outcome,
    DateTime? rescheduleAt,
  });
}
