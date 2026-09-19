import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_assignee.dart';
import '../../domain/entities/lead_assignment_request.dart';
import '../../domain/entities/lead_draft.dart';
import '../../domain/entities/lead_export.dart';
import '../../domain/entities/lead_import.dart';
import '../../domain/entities/lead_page.dart';
import '../../domain/entities/lead_query.dart';
import '../../domain/entities/lead_summary.dart';
import '../../domain/repositories/lead_repository.dart';
import '../datasources/mock_lead_data_source.dart';
import '../services/lead_export_serializer.dart';

class MockLeadRepository implements LeadRepository {
  MockLeadRepository({
    MockLeadDataSource? dataSource,
    LeadExportSerializer? exportSerializer,
  }) : _dataSource =
           dataSource ?? MockLeadDataSource(exportSerializer: exportSerializer);

  final MockLeadDataSource _dataSource;

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) {
    return _dataSource.getLeads(query);
  }

  @override
  Future<LeadSummary> getLeadSummary() {
    return _dataSource.getLeadSummary();
  }

  @override
  Future<Lead?> getLeadById(String leadId) {
    return _dataSource.getLeadById(leadId);
  }

  @override
  Future<Lead> createLead(CreateLeadInput input) {
    return _dataSource.createLead(input);
  }

  @override
  Future<Lead> updateLead(UpdateLeadInput input) {
    return _dataSource.updateLead(input);
  }

  @override
  Future<void> assignLead({
    required String leadId,
    required String assigneeId,
  }) {
    return _dataSource.assignLead(leadId: leadId, assigneeId: assigneeId);
  }

  @override
  Future<void> assignLeads(LeadAssignmentRequest request) {
    return _dataSource.assignLeads(request);
  }

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) {
    return _dataSource.reassignLead(request);
  }

  @override
  Future<List<LeadAssignee>> getAssignableUsers() {
    return _dataSource.getAssignableUsers();
  }

  @override
  Future<LeadImportResult> importLeads(LeadImportRequest request) {
    return _dataSource.importLeads(request);
  }

  @override
  Future<LeadExportResult> exportLeads(LeadExportRequest request) {
    return _dataSource.exportLeads(request);
  }
}
