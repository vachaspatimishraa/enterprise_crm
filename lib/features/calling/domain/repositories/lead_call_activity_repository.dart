import '../entities/call_outcome.dart';
import '../entities/lead_call_activity.dart';

/// Domain repository contract for lead call activities.
abstract interface class LeadCallActivityRepository {
  /// Returns all call activities recorded for the given [leadId], ordered newest first.
  Future<List<LeadCallActivity>> getActivitiesForLead(String leadId);

  /// Records a new call activity against the lead.
  Future<LeadCallActivity> recordActivity({
    required String leadId,
    required String performedByUserId,
    required CallOutcome outcome,
    DateTime? rescheduleAt,
  });
}
