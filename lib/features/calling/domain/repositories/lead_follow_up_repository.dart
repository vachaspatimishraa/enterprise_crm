import '../entities/follow_up_event.dart';
import '../entities/lead_follow_up.dart';

/// Domain repository contract for managing [LeadFollowUp] lifecycle and events.
abstract interface class LeadFollowUpRepository {
  /// Creates a new pending follow-up originating from a historical call activity.
  ///
  /// Enforces exactly one follow-up per [sourceCallActivityId].
  Future<LeadFollowUp> createFollowUp({
    required String leadId,
    required String sourceCallActivityId,
    required DateTime scheduledAt,
    required String performedByUserId,
  });

  /// Returns all follow-up records belonging to the given [leadIds].
  ///
  /// If [leadIds] is empty, returns an empty list without wildcard interpretation.
  Future<List<LeadFollowUp>> getFollowUpsForLeadIds(
    Set<String> leadIds,
  );

  /// Retrieves a single follow-up by its unique identifier, or null if not found.
  Future<LeadFollowUp?> getFollowUpById(String id);

  /// Transitions a pending follow-up to `completed`.
  ///
  /// Throws [StateError] if the follow-up is not in `pending` state.
  Future<LeadFollowUp> completeFollowUp({
    required String followUpId,
    required String performedByUserId,
  });

  /// Transitions a pending follow-up to `cancelled`.
  ///
  /// Throws [StateError] if the follow-up is not in `pending` state.
  Future<LeadFollowUp> cancelFollowUp({
    required String followUpId,
    required String performedByUserId,
  });

  /// Reschedules a pending follow-up to a new future [scheduledAt].
  ///
  /// The follow-up status remains `pending`.
  /// Throws [StateError] if the follow-up is not in `pending` state.
  /// Throws [ArgumentError] if [scheduledAt] is not in the future.
  Future<LeadFollowUp> rescheduleFollowUp({
    required String followUpId,
    required DateTime scheduledAt,
    required String performedByUserId,
  });

  /// Retrieves all lifecycle events recorded for the given [followUpId], ordered chronological.
  Future<List<FollowUpEvent>> getEventsForFollowUp(
    String followUpId,
  );
}
