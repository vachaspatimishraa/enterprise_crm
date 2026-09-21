import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/domain/entities/call_outcome.dart';
import 'package:enterprise_crm/features/calling/domain/entities/lead_call_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedClock = DateTime(2026, 9, 21, 10, 0, 0);

  group('MockLeadCallActivityRepository', () {
    test(
      'records activity with deterministic sequential IDs and injected clock',
      () async {
        final repo = MockLeadCallActivityRepository(now: () => fixedClock);

        final act1 = await repo.recordActivity(
          leadId: 'lead-1',
          performedByUserId: 'usr-1',
          outcome: CallOutcome.notConnected,
        );

        final act2 = await repo.recordActivity(
          leadId: 'lead-1',
          performedByUserId: 'usr-1',
          outcome: CallOutcome.followUp,
          rescheduleAt: DateTime(2026, 9, 22, 14, 0),
        );

        expect(act1.id, 'call-act-1');
        expect(act1.leadId, 'lead-1');
        expect(act1.performedByUserId, 'usr-1');
        expect(act1.outcome, CallOutcome.notConnected);
        expect(act1.rescheduleAt, isNull);
        expect(act1.createdAt, fixedClock);

        expect(act2.id, 'call-act-2');
        expect(act2.leadId, 'lead-1');
        expect(act2.outcome, CallOutcome.followUp);
        expect(act2.rescheduleAt, DateTime(2026, 9, 22, 14, 0));
        expect(act2.createdAt, fixedClock);
      },
    );

    test(
      'getActivitiesForLead filters by leadId and isolates histories',
      () async {
        final repo = MockLeadCallActivityRepository(now: () => fixedClock);

        await repo.recordActivity(
          leadId: 'lead-A',
          performedByUserId: 'usr-1',
          outcome: CallOutcome.notConnected,
        );
        await repo.recordActivity(
          leadId: 'lead-B',
          performedByUserId: 'usr-2',
          outcome: CallOutcome.salesDone,
        );

        final leadAActivities = await repo.getActivitiesForLead('lead-A');
        final leadBActivities = await repo.getActivitiesForLead('lead-B');
        final leadCActivities = await repo.getActivitiesForLead('lead-C');

        expect(leadAActivities.length, 1);
        expect(leadAActivities.first.outcome, CallOutcome.notConnected);

        expect(leadBActivities.length, 1);
        expect(leadBActivities.first.outcome, CallOutcome.salesDone);

        expect(leadCActivities, isEmpty);
      },
    );

    test('getActivitiesForLead sorts newest-first with ID tie-break', () async {
      var currentTime = DateTime(2026, 9, 21, 10, 0, 0);
      final repo = MockLeadCallActivityRepository(now: () => currentTime);

      // Record at 10:00
      await repo.recordActivity(
        leadId: 'lead-1',
        performedByUserId: 'usr-1',
        outcome: CallOutcome.notConnected,
      );

      // Advance clock to 10:30
      currentTime = DateTime(2026, 9, 21, 10, 30, 0);
      await repo.recordActivity(
        leadId: 'lead-1',
        performedByUserId: 'usr-1',
        outcome: CallOutcome.followUp,
      );

      // Advance clock to 11:00
      currentTime = DateTime(2026, 9, 21, 11, 0, 0);
      await repo.recordActivity(
        leadId: 'lead-1',
        performedByUserId: 'usr-1',
        outcome: CallOutcome.visitScheduled,
      );

      final activities = await repo.getActivitiesForLead('lead-1');
      expect(activities.length, 3);
      // Newest first
      expect(activities[0].outcome, CallOutcome.visitScheduled);
      expect(activities[1].outcome, CallOutcome.followUp);
      expect(activities[2].outcome, CallOutcome.notConnected);
    });

    test(
      'getActivitiesForLead returns defensively unmodifiable list',
      () async {
        final repo = MockLeadCallActivityRepository(now: () => fixedClock);
        await repo.recordActivity(
          leadId: 'lead-1',
          performedByUserId: 'usr-1',
          outcome: CallOutcome.dispatched,
        );

        final list = await repo.getActivitiesForLead('lead-1');
        expect(
          () => list.add(
            LeadCallActivity(
              id: 'fake',
              leadId: 'lead-1',
              performedByUserId: 'usr',
              outcome: CallOutcome.leadClosed,
              createdAt: fixedClock,
            ),
          ),
          throwsUnsupportedError,
        );
      },
    );

    test('throws ArgumentError on empty leadId', () async {
      final repo = MockLeadCallActivityRepository(now: () => fixedClock);
      expect(
        () => repo.recordActivity(
          leadId: '',
          performedByUserId: 'usr-1',
          outcome: CallOutcome.notInterested,
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.recordActivity(
          leadId: '   ',
          performedByUserId: 'usr-1',
          outcome: CallOutcome.notInterested,
        ),
        throwsArgumentError,
      );
    });

    group('getScheduledActivitiesForLeadIds (CALL-1B)', () {
      test(
        'empty leadIds returns empty list with zero wildcard leakage',
        () async {
          final repo = MockLeadCallActivityRepository(now: () => fixedClock);
          await repo.recordActivity(
            leadId: 'lead-1',
            performedByUserId: 'usr-1',
            outcome: CallOutcome.followUp,
            rescheduleAt: DateTime(2026, 9, 22, 10, 0),
          );

          final result = await repo.getScheduledActivitiesForLeadIds({});
          expect(result, isEmpty);
        },
      );

      test(
        'only returns activities where rescheduleAt != null for matching leads',
        () async {
          final repo = MockLeadCallActivityRepository(now: () => fixedClock);

          // Lead 1: unscheduled activity (rescheduleAt == null)
          await repo.recordActivity(
            leadId: 'lead-1',
            performedByUserId: 'usr-1',
            outcome: CallOutcome.notConnected,
            rescheduleAt: null,
          );

          // Lead 1: scheduled activity
          final act1 = await repo.recordActivity(
            leadId: 'lead-1',
            performedByUserId: 'usr-1',
            outcome: CallOutcome.followUp,
            rescheduleAt: DateTime(2026, 9, 22, 10, 0),
          );

          // Lead 2: scheduled activity
          final act2 = await repo.recordActivity(
            leadId: 'lead-2',
            performedByUserId: 'usr-1',
            outcome: CallOutcome.visitScheduled,
            rescheduleAt: DateTime(2026, 9, 23, 14, 0),
          );

          // Lead 3: scheduled activity (not in queried set)
          await repo.recordActivity(
            leadId: 'lead-3',
            performedByUserId: 'usr-2',
            outcome: CallOutcome.followUp,
            rescheduleAt: DateTime(2026, 9, 24, 11, 0),
          );

          final result = await repo.getScheduledActivitiesForLeadIds({
            'lead-1',
            'lead-2',
          });

          expect(result.length, 2);
          expect(result.map((a) => a.id), containsAll([act1.id, act2.id]));
          expect(result.any((a) => a.leadId == 'lead-3'), isFalse);
          expect(result.any((a) => a.rescheduleAt == null), isFalse);
        },
      );

      test(
        'sorts chronological ascending (earliest first) with ID tie-break',
        () async {
          final repo = MockLeadCallActivityRepository(now: () => fixedClock);

          final a3 = await repo.recordActivity(
            leadId: 'lead-1',
            performedByUserId: 'usr-1',
            outcome: CallOutcome.followUp,
            rescheduleAt: DateTime(2026, 9, 25, 10, 0),
          );

          final a1 = await repo.recordActivity(
            leadId: 'lead-2',
            performedByUserId: 'usr-1',
            outcome: CallOutcome.followUp,
            rescheduleAt: DateTime(2026, 9, 20, 12, 0),
          );

          final a2 = await repo.recordActivity(
            leadId: 'lead-1',
            performedByUserId: 'usr-1',
            outcome: CallOutcome.visitScheduled,
            rescheduleAt: DateTime(2026, 9, 21, 14, 0),
          );

          final result = await repo.getScheduledActivitiesForLeadIds({
            'lead-1',
            'lead-2',
          });

          expect(result.length, 3);
          expect(result[0].id, a1.id); // 20 Sep
          expect(result[1].id, a2.id); // 21 Sep
          expect(result[2].id, a3.id); // 25 Sep
        },
      );

      test('returns defensively unmodifiable list', () async {
        final repo = MockLeadCallActivityRepository(now: () => fixedClock);
        await repo.recordActivity(
          leadId: 'lead-1',
          performedByUserId: 'usr-1',
          outcome: CallOutcome.followUp,
          rescheduleAt: DateTime(2026, 9, 22, 10, 0),
        );

        final result = await repo.getScheduledActivitiesForLeadIds({'lead-1'});
        expect(() => result.clear(), throwsUnsupportedError);
      });
    });
  });
}
