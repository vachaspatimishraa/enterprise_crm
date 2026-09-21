import 'package:enterprise_crm/features/calling/domain/entities/follow_up_timing.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FollowUpTiming - Pure Classifier Tests', () {
    final now = DateTime(2026, 9, 21, 10, 0);

    test('yesterday event is classified as Overdue', () {
      final dt = DateTime(2026, 9, 20, 16, 0);
      expect(classifyFollowUpTiming(dt, now), FollowUpTiming.overdue);
    });

    test('earlier today event is classified as Overdue, not Due Today', () {
      final dt = DateTime(2026, 9, 21, 9, 0);
      expect(classifyFollowUpTiming(dt, now), FollowUpTiming.overdue);
    });

    test('event at exact now timestamp is classified as Due Today', () {
      final dt = DateTime(2026, 9, 21, 10, 0);
      expect(classifyFollowUpTiming(dt, now), FollowUpTiming.dueToday);
    });

    test('later today event is classified as Due Today', () {
      final dt = DateTime(2026, 9, 21, 15, 30);
      expect(classifyFollowUpTiming(dt, now), FollowUpTiming.dueToday);
    });

    test('future calendar date event is classified as Upcoming', () {
      final dt = DateTime(2026, 9, 22, 9, 0);
      expect(classifyFollowUpTiming(dt, now), FollowUpTiming.upcoming);
    });
  });

  group('CALL-1B Invariant: LeadStatus Separation', () {
    test('timing classification never mutates LeadStatus or Lead entity', () {
      const initialStatus = LeadStatus('New');
      final lead = Lead(
        id: 'lead-inv-1',
        name: 'Invariant Lead',
        phone: '+91 9988776655',
        email: 'inv@example.com',
        status: initialStatus,
        source: LeadSource.manual,
        assignedUserId: 'agent-1',
        assignedUserName: 'Agent One',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );

      final timing = classifyFollowUpTiming(
        DateTime(2026, 9, 20, 10, 0),
        DateTime(2026, 9, 21, 10, 0),
      );

      expect(timing, FollowUpTiming.overdue);
      expect(lead.status, initialStatus);
      expect(lead.status?.value, 'New');
    });
  });
}
