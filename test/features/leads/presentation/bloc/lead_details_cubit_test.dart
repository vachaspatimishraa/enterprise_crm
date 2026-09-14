import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignee.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_summary.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_details_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_details_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadRepository implements LeadRepository {
  List<Lead> leads = [];
  bool shouldThrow = false;
  String? lastRequestedId;

  @override
  Future<Lead?> getLeadById(String leadId) async {
    lastRequestedId = leadId;
    if (shouldThrow) throw Exception('Network timeout');
    return leads.cast<Lead?>().firstWhere(
      (l) => l?.id == leadId,
      orElse: () => null,
    );
  }

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
  Future<Lead> createLead(CreateLeadInput input) async =>
      const Lead(id: 'dummy');

  @override
  Future<Lead> updateLead(UpdateLeadInput input) async =>
      const Lead(id: 'dummy');

  @override
  Future<void> assignLead({
    required String leadId,
    required String assigneeId,
  }) async {}

  @override
  Future<void> assignLeads(LeadAssignmentRequest request) async {}

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) async {}

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async => const [];

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
  Future<LeadExportResult> exportLeads(LeadExportRequest request) async =>
      const LeadExportResult(fileReference: '', fileName: '');

  @override
  Future<LeadSummary> getLeadSummary() async => const LeadSummary(
    totalLeads: 0,
    assignedLeads: 0,
    unassignedLeads: 0,
    manualLeads: 0,
    excelLeads: 0,
    csvLeads: 0,
  );
}

void main() {
  late _FakeLeadRepository repository;

  setUp(() {
    repository = _FakeLeadRepository();
  });

  group('LeadDetailsCubit', () {
    test('initial state is LeadDetailsInitial', () {
      final cubit = LeadDetailsCubit(repository);
      expect(cubit.state, isA<LeadDetailsInitial>());
    });

    test('emits [Loading, Loaded] when lead is found', () async {
      final lead = Lead(
        id: 'lead-123',
        name: 'Aarav Sharma',
        phone: '+91 9876543210',
        email: 'aarav@example.com',
        source: LeadSource.manual,
        status: const LeadStatus('Sample New'),
        assignedUserId: 'agent-1',
        assignedUserName: 'Mock Agent One',
      );
      repository.leads = [lead];

      final cubit = LeadDetailsCubit(repository);
      final states = <LeadDetailsState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadLead('lead-123');
      await pumpEventQueue();

      expect(states, [
        isA<LeadDetailsLoading>(),
        isA<LeadDetailsLoaded>().having(
          (s) => s.lead.id,
          'lead id',
          'lead-123',
        ),
      ]);

      final loaded = states[1] as LeadDetailsLoaded;
      expect(loaded.lead.name, 'Aarav Sharma');
      expect(loaded.lead.source, LeadSource.manual);
      expect(loaded.lead.isAssigned, isTrue);

      await sub.cancel();
    });

    test('emits [Loading, NotFound] when lead does not exist', () async {
      repository.leads = [];

      final cubit = LeadDetailsCubit(repository);
      final states = <LeadDetailsState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadLead('unknown-id');
      await pumpEventQueue();

      expect(states, [
        isA<LeadDetailsLoading>(),
        isA<LeadDetailsNotFound>().having(
          (s) => s.leadId,
          'leadId',
          'unknown-id',
        ),
      ]);

      await sub.cancel();
    });

    test('emits [Loading, Failure] when repository throws error', () async {
      repository.shouldThrow = true;

      final cubit = LeadDetailsCubit(repository);
      final states = <LeadDetailsState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadLead('lead-error');
      await pumpEventQueue();

      expect(states, [
        isA<LeadDetailsLoading>(),
        isA<LeadDetailsFailure>()
            .having((s) => s.message, 'message', 'Network timeout')
            .having((s) => s.leadId, 'leadId', 'lead-error'),
      ]);

      await sub.cancel();
    });

    test('retry reloads with lastRequestedId', () async {
      repository.shouldThrow = true;

      final cubit = LeadDetailsCubit(repository);
      await cubit.loadLead('lead-retry-id');
      expect(cubit.state, isA<LeadDetailsFailure>());

      // Recover repository and call retry
      repository.shouldThrow = false;
      repository.leads = [
        const Lead(id: 'lead-retry-id', name: 'Recovered Lead'),
      ];

      await cubit.retry();
      expect(cubit.state, isA<LeadDetailsLoaded>());
      final loaded = cubit.state as LeadDetailsLoaded;
      expect(loaded.lead.id, 'lead-retry-id');
      expect(loaded.lead.name, 'Recovered Lead');
    });
  });
}
