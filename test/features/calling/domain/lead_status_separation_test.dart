import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/domain/entities/call_outcome.dart';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadStatus Separation Invariant (CALL-1A Section 3 & 40)', () {
    test(
      'recording each CallOutcome NEVER mutates Lead.status or any Lead attribute',
      () async {
        const initialStatus = LeadStatus('Contacted');

        final initialLead = Lead(
          id: 'lead-status-test',
          name: 'Unchanged Lead',
          phone: '+91 9999988888',
          email: 'unchanged@example.com',
          status: initialStatus,
          source: LeadSource.manual,
          assignedUserId: 'agent-1',
          assignedUserName: 'Sarah Jenkins',
          createdAt: DateTime(2026, 9, 1, 10, 0),
          updatedAt: DateTime(2026, 9, 1, 10, 0),
        );

        final leadRepo = MockLeadRepository(
          dataSource: MockLeadDataSource(initialLeads: [initialLead]),
        );
        final callRepo = MockLeadCallActivityRepository();

        // Test every single one of the 8 CallOutcomes
        for (final outcome in CallOutcome.values) {
          // Record call activity
          final activity = await callRepo.recordActivity(
            leadId: initialLead.id,
            performedByUserId: 'usr-1',
            outcome: outcome,
            rescheduleAt: outcome == CallOutcome.followUp
                ? DateTime(2026, 9, 25, 15, 0)
                : null,
          );

          expect(activity.outcome, outcome);

          // Fetch lead again from repository to ensure zero mutation
          final freshLead = await leadRepo.getLeadById(initialLead.id);
          expect(freshLead, isNotNull);

          // Lead.status MUST remain identical
          expect(freshLead!.status, initialStatus);
          expect(freshLead.status?.value, 'Contacted');

          // All other lead attributes MUST remain untouched
          expect(freshLead.id, initialLead.id);
          expect(freshLead.name, initialLead.name);
          expect(freshLead.phone, initialLead.phone);
          expect(freshLead.email, initialLead.email);
          expect(freshLead.source, initialLead.source);
          expect(freshLead.assignedUserId, initialLead.assignedUserId);
          expect(freshLead.assignedUserName, initialLead.assignedUserName);
          expect(freshLead.createdAt, initialLead.createdAt);
          expect(freshLead.updatedAt, initialLead.updatedAt);
        }

        // Verify all 8 activities were recorded in the call activity repository
        final recordedActivities = await callRepo.getActivitiesForLead(
          initialLead.id,
        );
        expect(recordedActivities.length, 8);
      },
    );
  });
}
