import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_follow_up_repository.dart';
import 'package:enterprise_crm/features/calling/data/services/mock_calling_workflow_service.dart';
import 'package:enterprise_crm/features/calling/domain/entities/call_outcome.dart';
import 'package:enterprise_crm/features/calling/domain/entities/follow_up_status.dart';
import 'package:enterprise_crm/features/calling/domain/entities/lead_follow_up.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingFollowUpRepository extends MockLeadFollowUpRepository {
  _FailingFollowUpRepository({super.now});

  @override
  Future<LeadFollowUp> createFollowUp({
    required String leadId,
    required String sourceCallActivityId,
    required DateTime scheduledAt,
    required String performedByUserId,
  }) async {
    throw Exception('Simulated follow-up storage failure');
  }
}

void main() {
  final fixedClock = DateTime(2026, 9, 21, 10, 0, 0);

  group('MockCallingWorkflowService', () {
    test(
      'records historical activity only when rescheduleAt is null',
      () async {
        final callActivityRepo = MockLeadCallActivityRepository(now: () => fixedClock);
        final followUpRepo = MockLeadFollowUpRepository(now: () => fixedClock);
        final service = MockCallingWorkflowService(
          callActivityRepository: callActivityRepo,
          followUpRepository: followUpRepo,
        );

        final result = await service.recordOutcome(
          leadId: 'lead-1',
          performedByUserId: 'usr-agent-1',
          outcome: CallOutcome.notConnected,
          rescheduleAt: null,
        );

        expect(result.activity.id, 'call-act-1');
        expect(result.activity.outcome, CallOutcome.notConnected);
        expect(result.activity.rescheduleAt, isNull);
        expect(result.followUp, isNull);

        // Verify follow up repository is empty
        final followUps = await followUpRepo.getFollowUpsForLeadIds({'lead-1'});
        expect(followUps, isEmpty);
      },
    );

    test(
      'creates both historical activity and pending follow-up when rescheduleAt is provided',
      () async {
        final callActivityRepo = MockLeadCallActivityRepository(now: () => fixedClock);
        final followUpRepo = MockLeadFollowUpRepository(now: () => fixedClock);
        final service = MockCallingWorkflowService(
          callActivityRepository: callActivityRepo,
          followUpRepository: followUpRepo,
        );

        final rescheduleTime = DateTime(2026, 9, 22, 14, 30);
        final result = await service.recordOutcome(
          leadId: 'lead-1',
          performedByUserId: 'usr-agent-1',
          outcome: CallOutcome.followUp,
          rescheduleAt: rescheduleTime,
        );

        expect(result.activity.id, 'call-act-1');
        expect(result.activity.outcome, CallOutcome.followUp);
        expect(result.activity.rescheduleAt, rescheduleTime);

        expect(result.followUp, isNotNull);
        expect(result.followUp!.id, 'follow-up-1');
        expect(result.followUp!.sourceCallActivityId, 'call-act-1');
        expect(result.followUp!.scheduledAt, rescheduleTime);
        expect(result.followUp!.status, FollowUpStatus.pending);

        // Verify follow-up repository contains the created follow-up
        final followUps = await followUpRepo.getFollowUpsForLeadIds({'lead-1'});
        expect(followUps.length, 1);
        expect(followUps.first.id, 'follow-up-1');
      },
    );

    test(
      'mock atomicity: rolls back recorded activity if follow-up creation fails',
      () async {
        final callActivityRepo = MockLeadCallActivityRepository(now: () => fixedClock);
        final failingFollowUpRepo = _FailingFollowUpRepository(now: () => fixedClock);
        final service = MockCallingWorkflowService(
          callActivityRepository: callActivityRepo,
          followUpRepository: failingFollowUpRepo,
        );

        final rescheduleTime = DateTime(2026, 9, 22, 14, 30);

        await expectLater(
          service.recordOutcome(
            leadId: 'lead-1',
            performedByUserId: 'usr-agent-1',
            outcome: CallOutcome.followUp,
            rescheduleAt: rescheduleTime,
          ),
          throwsException,
        );

        // CRITICAL: Call activity repository must NOT contain the failed activity!
        final activities = await callActivityRepo.getActivitiesForLead('lead-1');
        expect(activities, isEmpty, reason: 'Activity must be rolled back on follow-up failure');
      },
    );

    test(
      'HISTORICAL IMMUTABILITY: completing or cancelling a follow-up NEVER alters the historical CallActivity',
      () async {
        final callActivityRepo = MockLeadCallActivityRepository(now: () => fixedClock);
        final followUpRepo = MockLeadFollowUpRepository(now: () => fixedClock);
        final service = MockCallingWorkflowService(
          callActivityRepository: callActivityRepo,
          followUpRepository: followUpRepo,
        );

        final rescheduleTime = DateTime(2026, 9, 22, 14, 30);
        final result = await service.recordOutcome(
          leadId: 'lead-1',
          performedByUserId: 'usr-agent-1',
          outcome: CallOutcome.followUp,
          rescheduleAt: rescheduleTime,
        );

        final activityId = result.activity.id;
        final followUpId = result.followUp!.id;

        // Later, user completes the follow-up
        await followUpRepo.completeFollowUp(
          followUpId: followUpId,
          performedByUserId: 'usr-agent-1',
        );

        // Verify the original activity is 100% UNCHANGED
        final activities = await callActivityRepo.getActivitiesForLead('lead-1');
        expect(activities.length, 1);
        expect(activities.first.id, activityId);
        expect(activities.first.rescheduleAt, rescheduleTime);
        expect(activities.first.outcome, CallOutcome.followUp);
        expect(activities.first.createdAt, fixedClock);
      },
    );
  });
}
