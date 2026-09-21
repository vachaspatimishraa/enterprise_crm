import '../../domain/repositories/lead_call_activity_repository.dart';
import '../../domain/repositories/lead_follow_up_repository.dart';

/// Adapter ensuring historical pre-CALL-1C scheduled call activities are idempotently migrated
/// into pending [LeadFollowUp] records for authorized leads.
class FollowUpMigrationAdapter {
  final LeadCallActivityRepository callActivityRepository;
  final LeadFollowUpRepository followUpRepository;

  const FollowUpMigrationAdapter({
    required this.callActivityRepository,
    required this.followUpRepository,
  });

  /// Migrates scheduled activities for [authorizedLeadIds] that do not yet have a Follow-Up.
  ///
  /// Scoped strictly to the provided [authorizedLeadIds].
  /// Idempotent: safe to run multiple times with 0 duplicate follow-ups.
  /// Returns the count of newly migrated follow-ups.
  Future<int> ensureMigratedForLeadIds(Set<String> authorizedLeadIds) async {
    if (authorizedLeadIds.isEmpty) {
      return 0;
    }

    final activities = await callActivityRepository
        .getScheduledActivitiesForLeadIds(authorizedLeadIds);
    final existingFollowUps =
        await followUpRepository.getFollowUpsForLeadIds(authorizedLeadIds);
    final existingSourceActivityIds =
        existingFollowUps.map((f) => f.sourceCallActivityId).toSet();

    var count = 0;
    for (final activity in activities) {
      if (activity.rescheduleAt != null &&
          !existingSourceActivityIds.contains(activity.id)) {
        await followUpRepository.createFollowUp(
          leadId: activity.leadId,
          sourceCallActivityId: activity.id,
          scheduledAt: activity.rescheduleAt!,
          performedByUserId: activity.performedByUserId,
        );
        existingSourceActivityIds.add(activity.id);
        count++;
      }
    }

    return count;
  }
}
