import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignee.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_summary.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a mock implementation can satisfy the Lead repository contract',
    () async {
      final repository = _FakeLeadRepository();

      final page = await repository.getLeads();
      final lead = await repository.createLead(
        const CreateLeadInput(draft: LeadDraft(name: 'Aman')),
      );

      expect(page.items, isEmpty);
      expect(page.hasNext, isFalse);
      expect(lead.id, 'mock-lead');
      expect(lead.name, 'Aman');
    },
  );
}

class _FakeLeadRepository implements LeadRepository {
  @override
  Future<void> assignLead({
    required String leadId,
    required String assigneeId,
  }) async {}

  @override
  Future<void> assignLeads(LeadAssignmentRequest request) async {}

  @override
  Future<Lead> createLead(CreateLeadInput input) async => Lead(
    id: 'mock-lead',
    name: input.draft.name,
    phone: input.draft.phone,
    email: input.draft.email,
    status: input.draft.status,
    source: input.draft.source ?? LeadSource.manual,
  );

  @override
  Future<LeadExportResult> exportLeads(LeadExportRequest request) async =>
      const LeadExportResult(
        fileReference: 'mock-export',
        fileName: 'leads.xlsx',
      );

  @override
  Future<LeadSummary> getLeadSummary() async => const LeadSummary(
    totalLeads: 0,
    assignedLeads: 0,
    unassignedLeads: 0,
    manualLeads: 0,
    excelLeads: 0,
    csvLeads: 0,
  );

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async => const [];

  @override
  Future<Lead?> getLeadById(String leadId) async => null;

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async =>
      const LeadPage(
        items: [],
        currentPage: 1,
        pageSize: 20,
        totalItems: 0,
        hasNext: false,
      );

  @override
  Future<LeadImportResult> importLeads(LeadImportRequest request) async =>
      const LeadImportResult(
        totalRows: 0,
        importedRows: 0,
        skippedRows: 0,
        failedRows: 0,
        duplicateRows: 0,
      );

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) async {}

  @override
  Future<Lead> updateLead(UpdateLeadInput input) async => Lead(
    id: input.leadId,
    name: input.draft.name,
    phone: input.draft.phone,
    email: input.draft.email,
    status: input.draft.status,
    source: input.draft.source ?? LeadSource.manual,
  );
}
