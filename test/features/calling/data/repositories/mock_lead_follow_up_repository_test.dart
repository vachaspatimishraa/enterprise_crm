import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_follow_up_repository.dart';
import 'package:enterprise_crm/features/calling/domain/entities/follow_up_event.dart';
import 'package:enterprise_crm/features/calling/domain/entities/follow_up_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedClock = DateTime(2026, 9, 21, 10, 0, 0);

  group('MockLeadFollowUpRepository', () {
    test(
      'creates follow-up with deterministic sequential IDs and created event',
      () async {
        final repo = MockLeadFollowUpRepository(now: () => fixedClock);

        final scheduledDate = DateTime(2026, 9, 22, 14, 0);
        final followUp1 = await repo.createFollowUp(
          leadId: 'lead-1',
          sourceCallActivityId: 'call-act-1',
          scheduledAt: scheduledDate,
          performedByUserId: 'usr-agent-1',
        );

        expect(followUp1.id, 'follow-up-1');
        expect(followUp1.leadId, 'lead-1');
        expect(followUp1.sourceCallActivityId, 'call-act-1');
        expect(followUp1.scheduledAt, scheduledDate);
        expect(followUp1.status, FollowUpStatus.pending);
        expect(followUp1.createdAt, fixedClock);
        expect(followUp1.updatedAt, fixedClock);

        // Verify created event was appended
        final events = await repo.getEventsForFollowUp('follow-up-1');
        expect(events.length, 1);
        expect(events.first.id, 'follow-up-event-1');
        expect(events.first.followUpId, 'follow-up-1');
        expect(events.first.type, FollowUpEventType.created);
        expect(events.first.newScheduledAt, scheduledDate);
        expect(events.first.performedByUserId, 'usr-agent-1');
        expect(events.first.createdAt, fixedClock);
      },
    );

    test(
      'createFollowUp allows past date to support overdue follow-up tracking and migration',
      () async {
        final repo = MockLeadFollowUpRepository(now: () => fixedClock);

        final pastDate = fixedClock.subtract(const Duration(hours: 2));
        final followUp = await repo.createFollowUp(
          leadId: 'lead-1',
          sourceCallActivityId: 'call-act-1',
          scheduledAt: pastDate,
          performedByUserId: 'usr-agent-1',
        );

        expect(followUp.scheduledAt, pastDate);
        expect(followUp.status, FollowUpStatus.pending);
      },
    );

    test('rescheduleFollowUp rejects past date', () async {
      final repo = MockLeadFollowUpRepository(now: () => fixedClock);

      final followUp = await repo.createFollowUp(
        leadId: 'lead-1',
        sourceCallActivityId: 'call-act-1',
        scheduledAt: DateTime(2026, 9, 22, 10, 0),
        performedByUserId: 'usr-agent-1',
      );

      expect(
        () => repo.rescheduleFollowUp(
          followUpId: followUp.id,
          scheduledAt: fixedClock.subtract(const Duration(seconds: 1)),
          performedByUserId: 'usr-agent-1',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'rejects duplicate sourceCallActivityId (uniqueness invariant)',
      () async {
        final repo = MockLeadFollowUpRepository(now: () => fixedClock);

        await repo.createFollowUp(
          leadId: 'lead-1',
          sourceCallActivityId: 'call-act-1',
          scheduledAt: DateTime(2026, 9, 22, 10, 0),
          performedByUserId: 'usr-agent-1',
        );

        expect(
          () => repo.createFollowUp(
            leadId: 'lead-1',
            sourceCallActivityId: 'call-act-1',
            scheduledAt: DateTime(2026, 9, 23, 10, 0),
            performedByUserId: 'usr-agent-1',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'completeFollowUp transitions status from pending to completed and appends event',
      () async {
        var currentTime = fixedClock;
        final repo = MockLeadFollowUpRepository(now: () => currentTime);

        final followUp = await repo.createFollowUp(
          leadId: 'lead-1',
          sourceCallActivityId: 'call-act-1',
          scheduledAt: DateTime(2026, 9, 22, 10, 0),
          performedByUserId: 'usr-agent-1',
        );

        currentTime = DateTime(2026, 9, 21, 11, 0, 0);
        final completed = await repo.completeFollowUp(
          followUpId: followUp.id,
          performedByUserId: 'usr-agent-1',
        );

        expect(completed.status, FollowUpStatus.completed);
        expect(completed.updatedAt, currentTime);

        final events = await repo.getEventsForFollowUp(followUp.id);
        expect(events.length, 2);
        expect(events[1].type, FollowUpEventType.completed);
        expect(events[1].performedByUserId, 'usr-agent-1');
        expect(events[1].createdAt, currentTime);
      },
    );

    test(
      'cancelFollowUp transitions status from pending to cancelled and appends event',
      () async {
        var currentTime = fixedClock;
        final repo = MockLeadFollowUpRepository(now: () => currentTime);

        final followUp = await repo.createFollowUp(
          leadId: 'lead-1',
          sourceCallActivityId: 'call-act-1',
          scheduledAt: DateTime(2026, 9, 22, 10, 0),
          performedByUserId: 'usr-agent-1',
        );

        currentTime = DateTime(2026, 9, 21, 11, 0, 0);
        final cancelled = await repo.cancelFollowUp(
          followUpId: followUp.id,
          performedByUserId: 'usr-agent-1',
        );

        expect(cancelled.status, FollowUpStatus.cancelled);
        expect(cancelled.updatedAt, currentTime);

        final events = await repo.getEventsForFollowUp(followUp.id);
        expect(events.length, 2);
        expect(events[1].type, FollowUpEventType.cancelled);
        expect(events[1].performedByUserId, 'usr-agent-1');
        expect(events[1].createdAt, currentTime);
      },
    );

    test(
      'rescheduleFollowUp updates scheduledAt, appends rescheduled event, and STATUS REMAINS PENDING',
      () async {
        var currentTime = fixedClock;
        final repo = MockLeadFollowUpRepository(now: () => currentTime);

        final initialSchedule = DateTime(2026, 9, 22, 10, 0);
        final followUp = await repo.createFollowUp(
          leadId: 'lead-1',
          sourceCallActivityId: 'call-act-1',
          scheduledAt: initialSchedule,
          performedByUserId: 'usr-agent-1',
        );

        currentTime = DateTime(2026, 9, 21, 11, 0, 0);
        final newSchedule = DateTime(2026, 9, 25, 15, 0);

        final rescheduled = await repo.rescheduleFollowUp(
          followUpId: followUp.id,
          scheduledAt: newSchedule,
          performedByUserId: 'usr-agent-1',
        );

        // CRITICAL INVARIANT: Status remains pending, NEVER becomes FollowUpStatus.rescheduled
        expect(rescheduled.status, FollowUpStatus.pending);
        expect(rescheduled.scheduledAt, newSchedule);
        expect(rescheduled.updatedAt, currentTime);

        final events = await repo.getEventsForFollowUp(followUp.id);
        expect(events.length, 2);
        expect(events[1].type, FollowUpEventType.rescheduled);
        expect(events[1].previousScheduledAt, initialSchedule);
        expect(events[1].newScheduledAt, newSchedule);
        expect(events[1].performedByUserId, 'usr-agent-1');
        expect(events[1].createdAt, currentTime);
      },
    );

    test(
      'terminal state protection: cannot complete, cancel, or reschedule completed follow-up',
      () async {
        final repo = MockLeadFollowUpRepository(now: () => fixedClock);

        final followUp = await repo.createFollowUp(
          leadId: 'lead-1',
          sourceCallActivityId: 'call-act-1',
          scheduledAt: DateTime(2026, 9, 22, 10, 0),
          performedByUserId: 'usr-agent-1',
        );

        await repo.completeFollowUp(
          followUpId: followUp.id,
          performedByUserId: 'usr-agent-1',
        );

        // Subsequent complete throws
        expect(
          () => repo.completeFollowUp(
            followUpId: followUp.id,
            performedByUserId: 'usr-agent-1',
          ),
          throwsA(isA<StateError>()),
        );

        // Subsequent cancel throws
        expect(
          () => repo.cancelFollowUp(
            followUpId: followUp.id,
            performedByUserId: 'usr-agent-1',
          ),
          throwsA(isA<StateError>()),
        );

        // Subsequent reschedule throws
        expect(
          () => repo.rescheduleFollowUp(
            followUpId: followUp.id,
            scheduledAt: DateTime(2026, 9, 25, 10, 0),
            performedByUserId: 'usr-agent-1',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'terminal state protection: cannot complete, cancel, or reschedule cancelled follow-up',
      () async {
        final repo = MockLeadFollowUpRepository(now: () => fixedClock);

        final followUp = await repo.createFollowUp(
          leadId: 'lead-1',
          sourceCallActivityId: 'call-act-1',
          scheduledAt: DateTime(2026, 9, 22, 10, 0),
          performedByUserId: 'usr-agent-1',
        );

        await repo.cancelFollowUp(
          followUpId: followUp.id,
          performedByUserId: 'usr-agent-1',
        );

        // Subsequent complete throws
        expect(
          () => repo.completeFollowUp(
            followUpId: followUp.id,
            performedByUserId: 'usr-agent-1',
          ),
          throwsA(isA<StateError>()),
        );

        // Subsequent cancel throws
        expect(
          () => repo.cancelFollowUp(
            followUpId: followUp.id,
            performedByUserId: 'usr-agent-1',
          ),
          throwsA(isA<StateError>()),
        );

        // Subsequent reschedule throws
        expect(
          () => repo.rescheduleFollowUp(
            followUpId: followUp.id,
            scheduledAt: DateTime(2026, 9, 25, 10, 0),
            performedByUserId: 'usr-agent-1',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('getFollowUpsForLeadIds filters strictly by authorized IDs', () async {
      final repo = MockLeadFollowUpRepository(now: () => fixedClock);

      // Lead 1: follow-up 1 (22 Sep)
      await repo.createFollowUp(
        leadId: 'lead-1',
        sourceCallActivityId: 'call-act-1',
        scheduledAt: DateTime(2026, 9, 22, 10, 0),
        performedByUserId: 'usr-agent-1',
      );

      // Lead 1: follow-up 2 (23 Sep)
      final fu2 = await repo.createFollowUp(
        leadId: 'lead-1',
        sourceCallActivityId: 'call-act-2',
        scheduledAt: DateTime(2026, 9, 23, 10, 0),
        performedByUserId: 'usr-agent-1',
      );
      await repo.completeFollowUp(
        followUpId: fu2.id,
        performedByUserId: 'usr-1',
      );

      // Lead 2: follow-up 3 (21 Sep 15:00)
      await repo.createFollowUp(
        leadId: 'lead-2',
        sourceCallActivityId: 'call-act-3',
        scheduledAt: DateTime(2026, 9, 21, 15, 0),
        performedByUserId: 'usr-agent-1',
      );

      // Lead 3 (unauthorized): follow-up 4 (21 Sep 12:00)
      await repo.createFollowUp(
        leadId: 'lead-3',
        sourceCallActivityId: 'call-act-4',
        scheduledAt: DateTime(2026, 9, 21, 12, 0),
        performedByUserId: 'usr-agent-1',
      );

      // Query only for lead-1 and lead-2
      final followUps = await repo.getFollowUpsForLeadIds({'lead-1', 'lead-2'});

      expect(followUps.length, 3);
      expect(followUps.map((f) => f.id).toSet(), {
        'follow-up-1',
        'follow-up-2',
        'follow-up-3',
      });
      expect(followUps.any((f) => f.leadId == 'lead-3'), isFalse);
    });
  });
}
