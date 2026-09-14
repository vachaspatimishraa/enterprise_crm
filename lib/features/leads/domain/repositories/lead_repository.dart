import '../entities/lead.dart';
import '../entities/lead_assignee.dart';
import '../entities/lead_assignment_request.dart';
import '../entities/lead_draft.dart';
import '../entities/lead_export.dart';
import '../entities/lead_import.dart';
import '../entities/lead_page.dart';
import '../entities/lead_query.dart';
import '../entities/lead_summary.dart';

abstract class LeadRepository {
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]);

  Future<LeadSummary> getLeadSummary();

  Future<Lead?> getLeadById(String leadId);

  Future<Lead> createLead(CreateLeadInput input);

  Future<Lead> updateLead(UpdateLeadInput input);

  Future<void> assignLead({required String leadId, required String assigneeId});

  Future<void> assignLeads(LeadAssignmentRequest request);

  Future<void> reassignLead(LeadReassignmentRequest request);

  Future<List<LeadAssignee>> getAssignableUsers();

  Future<LeadImportResult> importLeads(LeadImportRequest request);

  Future<LeadExportResult> exportLeads(LeadExportRequest request);
}
