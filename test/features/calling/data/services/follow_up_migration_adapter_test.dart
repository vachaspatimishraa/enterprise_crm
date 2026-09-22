import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_follow_up_repository.dart';
import 'package:enterprise_crm/features/calling/data/services/follow_up_migration_adapter.dart';
import 'package:enterprise_crm/features/calling/domain/entities/call_outcome.dart';
import 'package:enterprise_crm/features/calling/domain/entities/follow_up_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedClock = DateTime(2026, 9, 21, 10, 0, 0);

  group('FollowUpMigrationAdapter', () {
    test('returns 0 when authorizedLeadIds is empty', () async {
      final callActivityRepo = MockLeadCallActivityRepository(
        now: () => fixedClock,
      );
      final followUpRepo = MockLeadFollowUpRepository(now: () => fixedClock);
      final adapter = FollowUpMigrationAdapter(
        callActivityRepository: callActivityRepo,
        followUpRepository: followUpRepo,
      );

      final count = await adapter.ensureMigratedForLeadIds({});
      expect(count, 0);
    });

    test(
      'migrates scheduled activities for authorized lead IDs into pending follow-ups',
      () async {
        final callActivityRepo = MockLeadCallActivityRepository(
          now: () => fixedClock,
        );
        final followUpRepo = MockLeadFollowUpRepository(now: () => fixedClock);
        final adapter = FollowUpMigrationAdapter(
          callActivityRepository: callActivityRepo,
          followUpRepository: followUpRepo,
        );

        final scheduledTime1 = DateTime(2026, 9, 22, 14, 0);
        final act1 = await callActivityRepo.recordActivity(
          leadId: 'lead-1',
          performedByUserId: 'usr-agent-1',
          outcome: CallOutcome.followUp,
          rescheduleAt: scheduledTime1,
        );

        // Activity without rescheduleAt (should not migrate)
        await callActivityRepo.recordActivity(
          leadId: 'lead-1',
          performedByUserId: 'usr-agent-1',
          outcome: CallOutcome.notConnected,
          rescheduleAt: null,
        );

        final count = await adapter.ensureMigratedForLeadIds({'lead-1'});
        expect(count, 1);

        final followUps = await followUpRepo.getFollowUpsForLeadIds({'lead-1'});
        expect(followUps.length, 1);
        expect(followUps.first.leadId, 'lead-1');
        expect(followUps.first.sourceCallActivityId, act1.id);
        expect(followUps.first.scheduledAt, scheduledTime1);
        expect(followUps.first.status, FollowUpStatus.pending);
      },
    );

    test(
      'IDEMPOTENCY: running twice results in 0 on second run with 0 duplicate follow-ups',
      () async {
        final callActivityRepo = MockLeadCallActivityRepository(
          now: () => fixedClock,
        );
        final followUpRepo = MockLeadFollowUpRepository(now: () => fixedClock);
        final adapter = FollowUpMigrationAdapter(
          callActivityRepository: callActivityRepo,
          followUpRepository: followUpRepo,
        );

        await callActivityRepo.recordActivity(
          leadId: 'lead-1',
          performedByUserId: 'usr-agent-1',
          outcome: CallOutcome.followUp,
          rescheduleAt: DateTime(2026, 9, 22, 14, 0),
        );

        // First run
        final firstCount = await adapter.ensureMigratedForLeadIds({'lead-1'});
        expect(firstCount, 1);

        // Second run
        final secondCount = await adapter.ensureMigratedForLeadIds({'lead-1'});
        expect(secondCount, 0);

        final followUps = await followUpRepo.getFollowUpsForLeadIds({'lead-1'});
        expect(
          followUps.length,
          1,
          reason: 'Must not create duplicate follow-up',
        );
      },
    );

    test(
      'SCOPE ISOLATION: does not migrate activities for unauthorized leads',
      () async {
        final callActivityRepo = MockLeadCallActivityRepository(
          now: () => fixedClock,
        );
        final followUpRepo = MockLeadFollowUpRepository(now: () => fixedClock);
        final adapter = FollowUpMigrationAdapter(
          callActivityRepository: callActivityRepo,
          followUpRepository: followUpRepo,
        );

        // Lead 1 (authorized)
        await callActivityRepo.recordActivity(
          leadId: 'lead-1',
          performedByUserId: 'usr-agent-1',
          outcome: CallOutcome.followUp,
          rescheduleAt: DateTime(2026, 9, 22, 14, 0),
        );

        // Lead 2 (unauthorized)
        await callActivityRepo.recordActivity(
          leadId: 'lead-2',
          performedByUserId: 'usr-agent-2',
          outcome: CallOutcome.followUp,
          rescheduleAt: DateTime(2026, 9, 23, 10, 0),
        );

        // Migrate only for lead-1
        final count = await adapter.ensureMigratedForLeadIds({'lead-1'});
        expect(count, 1);

        // Lead 2 must have 0 follow-ups
        final lead2FollowUps = await followUpRepo.getFollowUpsForLeadIds({
          'lead-2',
        });
        expect(lead2FollowUps, isEmpty);
      },
    );
  });
}
