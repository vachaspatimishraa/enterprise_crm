import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockLeadRepository repository;

  setUp(() {
    repository = MockLeadRepository(dataSource: MockLeadDataSource());
  });

  group('MockLeadRepository - Retrieval', () {
    test('returns initial dataset in LeadPage', () async {
      final page = await repository.getLeads();
      expect(page.items.length, 8);
      expect(page.totalItems, 8);
      expect(page.currentPage, 1);
      expect(page.hasNext, isFalse);
    });

    test('lookup existing ID returns lead', () async {
      final lead = await repository.getLeadById('mock-lead-1');
      expect(lead, isNotNull);
      expect(lead!.id, 'mock-lead-1');
      expect(lead.name, 'Aarav Sharma');
    });

    test('lookup unknown ID returns null without throwing', () async {
      final lead = await repository.getLeadById('unknown-id');
      expect(lead, isNull);
    });
  });

  group('MockLeadRepository - Search', () {
    test('searches case-insensitively by name', () async {
      final page = await repository.getLeads(
        const LeadQuery(searchText: 'aarav'),
      );
      expect(page.items.length, 1);
      expect(page.items.first.id, 'mock-lead-1');
    });

    test('searches by phone substring', () async {
      final page = await repository.getLeads(
        const LeadQuery(searchText: '98111'),
      );
      expect(page.items.length, 1);
      expect(page.items.first.id, 'mock-lead-2');
    });

    test('searches by email substring', () async {
      final page = await repository.getLeads(
        const LeadQuery(searchText: 'rohan.mehta'),
      );
      expect(page.items.length, 1);
      expect(page.items.first.id, 'mock-lead-3');
    });
  });

  group('MockLeadRepository - Filters', () {
    test('filters by source', () async {
      final manual = await repository.getLeads(
        const LeadQuery(source: LeadSource.manual),
      );
      expect(manual.items.every((l) => l.source == LeadSource.manual), isTrue);

      final excel = await repository.getLeads(
        const LeadQuery(source: LeadSource.excel),
      );
      expect(excel.items.every((l) => l.source == LeadSource.excel), isTrue);

      final csv = await repository.getLeads(
        const LeadQuery(source: LeadSource.csv),
      );
      expect(csv.items.every((l) => l.source == LeadSource.csv), isTrue);
    });

    test('filters by status', () async {
      final page = await repository.getLeads(
        const LeadQuery(status: LeadStatus('Sample New')),
      );
      expect(page.items.length, 3);
      expect(
        page.items.every((l) => l.status == const LeadStatus('Sample New')),
        isTrue,
      );
    });

    test('filters by assigned user', () async {
      final page = await repository.getLeads(
        const LeadQuery(assignedUserId: 'agent-1'),
      );
      expect(page.items.length, 2);
      expect(page.items.every((l) => l.assignedUserId == 'agent-1'), isTrue);
    });

    test('filters assigned only', () async {
      final page = await repository.getLeads(const LeadQuery(isAssigned: true));
      expect(page.items.length, 4);
      expect(page.items.every((l) => l.isAssigned), isTrue);
    });

    test('filters unassigned only', () async {
      final page = await repository.getLeads(
        const LeadQuery(isAssigned: false),
      );
      expect(page.items.length, 4);
      expect(page.items.every((l) => !l.isAssigned), isTrue);
    });
  });

  group('MockLeadRepository - Pagination', () {
    test('paginates results correctly across pages', () async {
      final page1 = await repository.getLeads(
        const LeadQuery(page: 1, pageSize: 3),
      );
      expect(page1.items.length, 3);
      expect(page1.currentPage, 1);
      expect(page1.totalItems, 8);
      expect(page1.hasNext, isTrue);

      final page2 = await repository.getLeads(
        const LeadQuery(page: 2, pageSize: 3),
      );
      expect(page2.items.length, 3);
      expect(page2.currentPage, 2);
      expect(page2.hasNext, isTrue);

      final page3 = await repository.getLeads(
        const LeadQuery(page: 3, pageSize: 3),
      );
      expect(page3.items.length, 2);
      expect(page3.currentPage, 3);
      expect(page3.hasNext, isFalse);

      final pageOut = await repository.getLeads(
        const LeadQuery(page: 10, pageSize: 3),
      );
      expect(pageOut.items, isEmpty);
      expect(pageOut.hasNext, isFalse);
    });
  });

  group('MockLeadRepository - Create & Update', () {
    test('creates lead with unique ID and makes it retrievable', () async {
      final created = await repository.createLead(
        const CreateLeadInput(
          draft: LeadDraft(
            name: 'New Mock Lead',
            phone: '+91 9123456780',
            email: 'new.mock@example.com',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
          ),
        ),
      );

      expect(created.id, startsWith('mock-lead-'));
      expect(created.name, 'New Mock Lead');

      final fetched = await repository.getLeadById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'New Mock Lead');
    });

    test('updates lead and preserves unmodified fields', () async {
      final updated = await repository.updateLead(
        const UpdateLeadInput(
          leadId: 'mock-lead-1',
          draft: LeadDraft(name: 'Aarav Updated'),
        ),
      );

      expect(updated.name, 'Aarav Updated');
      expect(updated.phone, '+91 9876543210');
      expect(updated.email, 'aarav.sharma@example.com');
      expect(updated.assignedUserId, 'agent-1');

      final fetched = await repository.getLeadById('mock-lead-1');
      expect(fetched!.name, 'Aarav Updated');
    });
  });

  group('MockLeadRepository - Assignment & Reassignment', () {
    test('returns assignable users list', () async {
      final users = await repository.getAssignableUsers();
      expect(users.length, 3);
      expect(users.first.displayName, 'Mock Agent One');
    });

    test('assigns single lead', () async {
      await repository.assignLead(leadId: 'mock-lead-2', assigneeId: 'agent-3');
      final lead = await repository.getLeadById('mock-lead-2');
      expect(lead!.assignedUserId, 'agent-3');
      expect(lead.assignedUserName, 'Mock Agent Three');
      expect(lead.isAssigned, isTrue);
    });

    test('assigns multiple leads in bulk', () async {
      await repository.assignLeads(
        const LeadAssignmentRequest(
          leadIds: ['mock-lead-2', 'mock-lead-4'],
          assigneeId: 'agent-2',
        ),
      );

      final lead2 = await repository.getLeadById('mock-lead-2');
      final lead4 = await repository.getLeadById('mock-lead-4');
      expect(lead2!.assignedUserId, 'agent-2');
      expect(lead4!.assignedUserId, 'agent-2');
    });

    test('reassigns lead to new agent', () async {
      await repository.reassignLead(
        const LeadReassignmentRequest(
          leadId: 'mock-lead-1',
          newAssigneeId: 'agent-2',
          reason: 'Workload balancing',
        ),
      );

      final lead = await repository.getLeadById('mock-lead-1');
      expect(lead!.assignedUserId, 'agent-2');
      expect(lead.assignedUserName, 'Mock Agent Two');
    });
  });

  group('MockLeadRepository - Import & Export placeholders', () {
    test('returns deterministic mock import result', () async {
      final result = await repository.importLeads(
        const LeadImportRequest(
          fileReference: 'dummy-ref',
          fileName: 'leads.xlsx',
          fileType: LeadImportFileType.excel,
        ),
      );

      expect(result.totalRows, 10);
      expect(result.importedRows, 8);
      expect(result.duplicateRows, 1);
    });

    test('returns deterministic mock export result', () async {
      final result = await repository.exportLeads(
        const LeadExportRequest(
          query: LeadQuery(),
          format: LeadExportFormat.excel,
        ),
      );

      expect(result.fileName, 'mock_leads_export.xlsx');
      expect(result.fileReference, 'mock-export-ref-excel');
    });
  });
}
