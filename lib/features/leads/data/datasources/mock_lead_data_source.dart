import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_assignee.dart';
import '../../domain/entities/lead_assignment_request.dart';
import '../../domain/entities/lead_draft.dart';
import '../../domain/entities/lead_export.dart';
import '../../domain/entities/lead_import.dart';
import '../../domain/entities/lead_ingestion_result.dart';
import '../../domain/entities/lead_page.dart';
import '../../domain/entities/lead_query.dart';
import '../../domain/entities/lead_sort.dart';
import '../../domain/entities/lead_source.dart';
import '../../domain/entities/lead_status.dart';
import '../../domain/entities/lead_summary.dart';
import '../../domain/entities/meta_leadgen_payload.dart';
import '../../domain/entities/portal_lead_payload.dart';
import '../services/lead_export_serializer.dart';

class MockLeadDataSource {
  MockLeadDataSource({
    List<Lead>? initialLeads,
    List<LeadAssignee>? initialAssignees,
    List<LeadAssignee> Function()? assignableUsersProvider,
    LeadExportSerializer? exportSerializer,
  }) : _assignableUsersProvider = assignableUsersProvider,
       _exportSerializer =
           exportSerializer ?? const DefaultLeadExportSerializer() {
    _leads = initialLeads != null
        ? List<Lead>.from(initialLeads)
        : _defaultLeads();
    _assignees = initialAssignees != null
        ? List<LeadAssignee>.from(initialAssignees)
        : _defaultAssignees();
  }

  final List<LeadAssignee> Function()? _assignableUsersProvider;
  final LeadExportSerializer _exportSerializer;
  late final List<Lead> _leads;
  late final List<LeadAssignee> _assignees;
  int _idCounter = 100;

  static List<LeadAssignee> _defaultAssignees() => const [
    LeadAssignee(id: 'agent-1', displayName: 'Mock Agent One'),
    LeadAssignee(id: 'agent-2', displayName: 'Mock Agent Two'),
    LeadAssignee(id: 'agent-3', displayName: 'Mock Agent Three'),
  ];

  static List<Lead> _defaultLeads() => [
    Lead(
      id: 'mock-lead-1',
      name: 'Aarav Sharma',
      phone: '+91 9876543210',
      email: 'aarav.sharma@example.com',
      status: const LeadStatus('Sample New'),
      source: LeadSource.manual,
      assignedUserId: 'agent-1',
      assignedUserName: 'Mock Agent One',
      createdAt: DateTime.parse('2026-09-01T10:00:00Z'),
      updatedAt: DateTime.parse('2026-09-01T10:00:00Z'),
    ),
    Lead(
      id: 'mock-lead-2',
      name: 'Pooja Verma',
      phone: '+91 9811122233',
      email: null,
      status: const LeadStatus('Sample Follow-up'),
      source: LeadSource.excel,
      assignedUserId: null,
      assignedUserName: null,
      createdAt: DateTime.parse('2026-09-02T11:30:00Z'),
      updatedAt: DateTime.parse('2026-09-02T11:30:00Z'),
    ),
    Lead(
      id: 'mock-lead-3',
      name: 'Rohan Mehta',
      phone: null,
      email: 'rohan.mehta@example.com',
      status: const LeadStatus('Sample Review'),
      source: LeadSource.csv,
      assignedUserId: 'agent-2',
      assignedUserName: 'Mock Agent Two',
      createdAt: DateTime.parse('2026-09-03T14:15:00Z'),
      updatedAt: DateTime.parse('2026-09-03T14:15:00Z'),
    ),
    Lead(
      id: 'mock-lead-4',
      name: 'Sneha Patel',
      phone: '+91 9922334455',
      email: 'sneha.patel@example.com',
      status: const LeadStatus('Sample Qualified'),
      source: LeadSource.manual,
      assignedUserId: null,
      assignedUserName: null,
      createdAt: DateTime.parse('2026-09-04T09:00:00Z'),
      updatedAt: DateTime.parse('2026-09-04T09:00:00Z'),
    ),
    Lead(
      id: 'mock-lead-5',
      name: 'Vikram Joshi',
      phone: '+91 9733445566',
      email: 'vikram.joshi@example.com',
      status: const LeadStatus('Sample New'),
      source: LeadSource.excel,
      assignedUserId: 'agent-1',
      assignedUserName: 'Mock Agent One',
      createdAt: DateTime.parse('2026-09-05T16:45:00Z'),
      updatedAt: DateTime.parse('2026-09-05T16:45:00Z'),
    ),
    Lead(
      id: 'mock-lead-6',
      name: null,
      phone: '+91 9655667788',
      email: null,
      status: const LeadStatus('Sample Review'),
      source: LeadSource.csv,
      assignedUserId: null,
      assignedUserName: null,
      createdAt: DateTime.parse('2026-09-06T12:00:00Z'),
      updatedAt: DateTime.parse('2026-09-06T12:00:00Z'),
    ),
    Lead(
      id: 'mock-lead-7',
      name: 'Ananya Gupta',
      phone: '+91 9544556677',
      email: 'ananya.gupta@example.com',
      status: const LeadStatus('Sample Follow-up'),
      source: LeadSource.manual,
      assignedUserId: 'agent-3',
      assignedUserName: 'Mock Agent Three',
      createdAt: DateTime.parse('2026-09-07T13:20:00Z'),
      updatedAt: DateTime.parse('2026-09-07T13:20:00Z'),
    ),
    Lead(
      id: 'mock-lead-8',
      name: 'Karan Malhotra',
      phone: '+91 9433221100',
      email: 'karan.m@example.com',
      status: const LeadStatus('Sample New'),
      source: LeadSource.excel,
      assignedUserId: null,
      assignedUserName: null,
      createdAt: DateTime.parse('2026-09-08T15:10:00Z'),
      updatedAt: DateTime.parse('2026-09-08T15:10:00Z'),
    ),
  ];

  List<Lead> _resolveMatchingLeads(LeadQuery query) {
    var filtered = List<Lead>.from(_leads);

    // 1. Search (case-insensitive across name, phone, email)
    if (query.searchText != null && query.searchText!.trim().isNotEmpty) {
      final searchLower = query.searchText!.trim().toLowerCase();
      filtered = filtered.where((lead) {
        final nameMatch =
            lead.name?.toLowerCase().contains(searchLower) ?? false;
        final phoneMatch =
            lead.phone?.toLowerCase().contains(searchLower) ?? false;
        final emailMatch =
            lead.email?.toLowerCase().contains(searchLower) ?? false;
        return nameMatch || phoneMatch || emailMatch;
      }).toList();
    }

    // 2. Filters
    if (query.status != null) {
      filtered = filtered.where((lead) => lead.status == query.status).toList();
    }

    if (query.source != null) {
      filtered = filtered.where((lead) => lead.source == query.source).toList();
    }

    if (query.assignedUserId != null) {
      filtered = filtered
          .where((lead) => lead.assignedUserId == query.assignedUserId)
          .toList();
    }

    if (query.isAssigned != null) {
      filtered = filtered
          .where((lead) => lead.isAssigned == query.isAssigned)
          .toList();
    }

    // 3. Sort
    if (query.sort != null) {
      final sort = query.sort!;
      filtered.sort((a, b) {
        int comparison = 0;
        switch (sort.field) {
          case LeadSortField.name:
            final aName = a.name?.trim();
            final bName = b.name?.trim();
            final aEmpty = aName == null || aName.isEmpty;
            final bEmpty = bName == null || bName.isEmpty;

            if (aEmpty && bEmpty) {
              comparison = 0;
            } else if (aEmpty) {
              return 1;
            } else if (bEmpty) {
              return -1;
            } else {
              final comp = aName.toLowerCase().compareTo(bName.toLowerCase());
              comparison = sort.direction == LeadSortDirection.ascending
                  ? comp
                  : -comp;
            }
            break;

          case LeadSortField.createdAt:
            final aDate = a.createdAt;
            final bDate = b.createdAt;
            final aNull = aDate == null;
            final bNull = bDate == null;

            if (aNull && bNull) {
              comparison = 0;
            } else if (aNull) {
              return 1;
            } else if (bNull) {
              return -1;
            } else {
              final comp = aDate.compareTo(bDate);
              comparison = sort.direction == LeadSortDirection.ascending
                  ? comp
                  : -comp;
            }
            break;
        }

        if (comparison != 0) {
          return comparison;
        }
        return a.id.compareTo(b.id);
      });
    }

    return filtered;
  }

  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async {
    final filtered = _resolveMatchingLeads(query);

    // 4. Pagination
    final totalItems = filtered.length;
    final page = query.page < 1 ? 1 : query.page;
    final pageSize = query.pageSize < 1 ? 20 : query.pageSize;
    final startIndex = (page - 1) * pageSize;

    if (startIndex >= totalItems) {
      return LeadPage(
        items: const [],
        currentPage: page,
        pageSize: pageSize,
        totalItems: totalItems,
        hasNext: false,
      );
    }

    final endIndex = (startIndex + pageSize) > totalItems
        ? totalItems
        : (startIndex + pageSize);
    final items = filtered.sublist(startIndex, endIndex);
    final hasNext = endIndex < totalItems;

    return LeadPage(
      items: items,
      currentPage: page,
      pageSize: pageSize,
      totalItems: totalItems,
      hasNext: hasNext,
    );
  }

  Future<LeadSummary> getLeadSummary() async {
    if (_leads.isEmpty) {
      return const LeadSummary(
        totalLeads: 0,
        assignedLeads: 0,
        unassignedLeads: 0,
        manualLeads: 0,
        excelLeads: 0,
        csvLeads: 0,
      );
    }

    int assigned = 0;
    int unassigned = 0;
    int manual = 0;
    int excel = 0;
    int csv = 0;
    int portal = 0;
    int metaCampaign = 0;

    for (final lead in _leads) {
      if (lead.isAssigned) {
        assigned++;
      } else {
        unassigned++;
      }

      switch (lead.source) {
        case LeadSource.manual:
          manual++;
          break;
        case LeadSource.excel:
          excel++;
          break;
        case LeadSource.csv:
          csv++;
          break;
        case LeadSource.portal:
          portal++;
          break;
        case LeadSource.metaCampaign:
          metaCampaign++;
          break;
      }
    }

    return LeadSummary(
      totalLeads: _leads.length,
      assignedLeads: assigned,
      unassignedLeads: unassigned,
      manualLeads: manual,
      excelLeads: excel,
      csvLeads: csv,
      portalLeads: portal,
      metaCampaignLeads: metaCampaign,
    );
  }

  Future<Lead?> getLeadById(String leadId) async {
    for (final lead in _leads) {
      if (lead.id == leadId) {
        return lead;
      }
    }
    return null;
  }

  Future<Lead> createLead(CreateLeadInput input) async {
    final now = DateTime.now();
    _idCounter++;
    final newId = 'LEAD-$_idCounter';

    final created = Lead(
      id: newId,
      name: input.draft.name,
      businessName: input.draft.businessName,
      phone: input.draft.phone,
      email: input.draft.email,
      city: input.draft.city,
      state: input.draft.state,
      status: input.draft.status,
      source: input.draft.source ?? LeadSource.manual,
      createdAt: now,
      updatedAt: now,
      metadata: input.draft.metadata,
    );

    _leads.add(created);
    return created;
  }

  Future<LeadIngestionResult> ingestPortalLead(PortalLeadPayload payload) async {
    if (!payload.isValid) {
      return const LeadIngestionResult.failure(
        source: LeadSource.portal,
        errorMessage:
            'Invalid portal lead: At least one contact field (name, phone, email, or business name) is required.',
      );
    }

    try {
      final draft = payload.toLeadDraft();
      final created = await createLead(CreateLeadInput(draft: draft));
      return LeadIngestionResult.success(
        lead: created,
        externalReferenceId: payload.formId,
      );
    } catch (e) {
      return LeadIngestionResult.failure(
        source: LeadSource.portal,
        errorMessage: 'Portal ingestion failed: $e',
        externalReferenceId: payload.formId,
      );
    }
  }

  Future<LeadIngestionResult> ingestMetaLead(MetaLeadgenPayload payload) async {
    if (!payload.isValid) {
      return LeadIngestionResult.failure(
        source: LeadSource.metaCampaign,
        errorMessage:
            'Invalid Meta lead: leadgen_id and at least one contact field are required.',
        externalReferenceId: payload.leadgenId,
      );
    }

    // Deduplication guard: check if lead with same leadgenId already exists
    final isDuplicate = _leads.any(
      (l) => l.metadata?['leadgenId'] == payload.leadgenId.trim(),
    );
    if (isDuplicate) {
      return LeadIngestionResult.failure(
        source: LeadSource.metaCampaign,
        errorMessage:
            'Duplicate Meta Lead: Lead with leadgen_id ${payload.leadgenId} has already been ingested.',
        externalReferenceId: payload.leadgenId,
      );
    }

    try {
      final draft = payload.toLeadDraft();
      final created = await createLead(CreateLeadInput(draft: draft));
      return LeadIngestionResult.success(
        lead: created,
        externalReferenceId: payload.leadgenId,
      );
    } catch (e) {
      return LeadIngestionResult.failure(
        source: LeadSource.metaCampaign,
        errorMessage: 'Meta lead ingestion failed: $e',
        externalReferenceId: payload.leadgenId,
      );
    }
  }

  Future<Lead> updateLead(UpdateLeadInput input) async {
    final index = _leads.indexWhere((lead) => lead.id == input.leadId);
    if (index == -1) {
      throw StateError('Lead not found: ${input.leadId}');
    }

    final existing = _leads[index];
    final updated = existing.copyWith(
      name: input.draft.name ?? existing.name,
      businessName: input.draft.businessName ?? existing.businessName,
      phone: input.draft.phone ?? existing.phone,
      email: input.draft.email ?? existing.email,
      city: input.draft.city ?? existing.city,
      state: input.draft.state ?? existing.state,
      status: input.draft.status ?? existing.status,
      source: input.draft.source ?? existing.source,
      updatedAt: DateTime.now(),
    );

    _leads[index] = updated;
    return updated;
  }

  List<LeadAssignee> _resolveAssignees() {
    final provider = _assignableUsersProvider;
    if (provider != null) {
      final provided = provider();
      if (provided.isNotEmpty) {
        return List<LeadAssignee>.unmodifiable(provided);
      }
    }
    return List<LeadAssignee>.unmodifiable(_assignees);
  }

  Future<List<LeadAssignee>> getAssignableUsers() async {
    return _resolveAssignees();
  }

  Future<void> assignLead({
    required String leadId,
    required String assigneeId,
  }) async {
    final assignee = _resolveAssignees().firstWhere(
      (a) => a.id == assigneeId,
      orElse: () =>
          LeadAssignee(id: assigneeId, displayName: 'Agent $assigneeId'),
    );

    final index = _leads.indexWhere((lead) => lead.id == leadId);
    if (index != -1) {
      _leads[index] = _leads[index].copyWith(
        assignedUserId: assignee.id,
        assignedUserName: assignee.displayName,
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<void> assignLeads(LeadAssignmentRequest request) async {
    final assignee = _resolveAssignees().firstWhere(
      (a) => a.id == request.assigneeId,
      orElse: () => LeadAssignee(
        id: request.assigneeId,
        displayName: 'Agent ${request.assigneeId}',
      ),
    );

    for (final leadId in request.leadIds) {
      final index = _leads.indexWhere((lead) => lead.id == leadId);
      if (index != -1) {
        _leads[index] = _leads[index].copyWith(
          assignedUserId: assignee.id,
          assignedUserName: assignee.displayName,
          updatedAt: DateTime.now(),
        );
      }
    }
  }

  Future<void> reassignLead(LeadReassignmentRequest request) async {
    await assignLead(leadId: request.leadId, assigneeId: request.newAssigneeId);
  }

  Future<LeadImportResult> importLeads(LeadImportRequest request) async {
    if (request.hasDraftPayload) {
      final defaultSource = request.fileType == LeadImportFileType.csv
          ? LeadSource.csv
          : LeadSource.excel;

      for (final draft in request.drafts) {
        final effectiveDraft = draft.source == null
            ? LeadDraft(
                name: draft.name,
                businessName: draft.businessName,
                phone: draft.phone,
                email: draft.email,
                city: draft.city,
                state: draft.state,
                status: draft.status,
                source: defaultSource,
                metadata: draft.metadata,
              )
            : draft;
        await createLead(CreateLeadInput(draft: effectiveDraft));
      }
      return LeadImportResult(
        totalRows: request.drafts.length,
        importedRows: request.drafts.length,
        skippedRows: 0,
        failedRows: 0,
        duplicateRows: 0,
      );
    }

    return const LeadImportResult(
      totalRows: 10,
      importedRows: 8,
      skippedRows: 1,
      failedRows: 0,
      duplicateRows: 1,
    );
  }

  Future<LeadExportResult> exportLeads(LeadExportRequest request) async {
    final matching = _resolveMatchingLeads(request.query);
    final content = _exportSerializer.serialize(
      leads: matching,
      format: request.format,
    );
    final extension = switch (request.format) {
      LeadExportFormat.excel => 'xlsx',
      LeadExportFormat.csv => 'csv',
      LeadExportFormat.pdf => 'pdf',
    };
    return LeadExportResult(
      fileReference: content,
      fileName: 'leads_export.$extension',
    );
  }
}
