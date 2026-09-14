import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignee.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_dashboard_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_dashboard_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadRepository implements LeadRepository {
  List<Lead> leads = [];
  bool shouldThrow = false;

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async {
    if (shouldThrow) throw Exception('Network error');
    return LeadPage(
      items: leads,
      currentPage: 1,
      pageSize: query.pageSize,
      totalItems: leads.length,
      hasNext: false,
    );
  }

  @override
  Future<Lead?> getLeadById(String leadId) async => null;

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
}

void main() {
  late _FakeLeadRepository repository;

  setUp(() {
    repository = _FakeLeadRepository();
  });

  group('LeadDashboardCubit', () {
    test('initial state is LeadDashboardInitial', () {
      final cubit = LeadDashboardCubit(repository);
      expect(cubit.state, isA<LeadDashboardInitial>());
    });

    test('emits [Loading, Loaded] with correctly calculated metrics', () async {
      repository.leads = [
        const Lead(
          id: '1',
          source: LeadSource.manual,
          assignedUserId: 'u1',
          assignedUserName: 'Agent 1',
        ),
        const Lead(id: '2', source: LeadSource.excel, assignedUserId: null),
        const Lead(
          id: '3',
          source: LeadSource.csv,
          assignedUserId: 'u2',
          assignedUserName: 'Agent 2',
        ),
      ];

      final cubit = LeadDashboardCubit(repository);
      final states = <LeadDashboardState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadDashboard();
      await pumpEventQueue();

      expect(states, [
        isA<LeadDashboardLoading>(),
        isA<LeadDashboardLoaded>().having(
          (s) => s.metrics.totalLeads,
          'total',
          3,
        ),
      ]);

      final loaded = states[1] as LeadDashboardLoaded;
      expect(loaded.metrics.assignedLeads, 2);
      expect(loaded.metrics.unassignedLeads, 1);
      expect(loaded.metrics.manualLeads, 1);
      expect(loaded.metrics.excelLeads, 1);
      expect(loaded.metrics.csvLeads, 1);

      await sub.cancel();
    });

    test('emits [Loading, Empty] when 0 leads exist', () async {
      repository.leads = [];

      final cubit = LeadDashboardCubit(repository);
      final states = <LeadDashboardState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadDashboard();
      await pumpEventQueue();

      expect(states, [isA<LeadDashboardLoading>(), isA<LeadDashboardEmpty>()]);

      await sub.cancel();
    });

    test('emits [Loading, Failure] when repository throws error', () async {
      repository.shouldThrow = true;

      final cubit = LeadDashboardCubit(repository);
      final states = <LeadDashboardState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadDashboard();
      await pumpEventQueue();

      expect(states, [
        isA<LeadDashboardLoading>(),
        isA<LeadDashboardFailure>().having(
          (s) => s.message,
          'message',
          'Network error',
        ),
      ]);

      await sub.cancel();
    });
  });
}
