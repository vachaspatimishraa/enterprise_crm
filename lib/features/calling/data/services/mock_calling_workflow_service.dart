import '../../domain/entities/call_outcome.dart';
import '../../domain/repositories/lead_call_activity_repository.dart';
import '../../domain/repositories/lead_follow_up_repository.dart';
import '../../domain/services/calling_workflow_service.dart';
import '../repositories/mock_lead_call_activity_repository.dart';

/// In-memory transactional implementation of [CallingWorkflowService].
///
/// Orchestrates historical call activity recording and actionable follow-up creation.
/// If follow-up creation fails after recording an activity, rolls back the activity in mock
/// to guarantee all-or-failure atomicity from the user's perspective.
class MockCallingWorkflowService implements CallingWorkflowService {
  final LeadCallActivityRepository callActivityRepository;
  final LeadFollowUpRepository followUpRepository;

  MockCallingWorkflowService({
    required this.callActivityRepository,
    required this.followUpRepository,
  });

  @override
  Future<RecordedCallingWorkflow> recordOutcome({
    required String leadId,
    required String performedByUserId,
    required CallOutcome outcome,
    DateTime? rescheduleAt,
  }) async {
    final activity = await callActivityRepository.recordActivity(
      leadId: leadId,
      performedByUserId: performedByUserId,
      outcome: outcome,
      rescheduleAt: rescheduleAt,
    );

    if (rescheduleAt == null) {
      return RecordedCallingWorkflow(activity: activity, followUp: null);
    }

    try {
      final followUp = await followUpRepository.createFollowUp(
        leadId: leadId,
        sourceCallActivityId: activity.id,
        scheduledAt: rescheduleAt,
        performedByUserId: performedByUserId,
      );
      return RecordedCallingWorkflow(activity: activity, followUp: followUp);
    } catch (e) {
      // Mock-only compensation to prevent orphaned activity when follow-up fails
      if (callActivityRepository is MockLeadCallActivityRepository) {
        (callActivityRepository as MockLeadCallActivityRepository)
            .rollbackActivityForMockAtomicity(activity.id);
      }
      rethrow;
    }
  }
}
