import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
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

  @override
  Future<LeadSummary> getLeadSummary() async {
    if (shouldThrow) throw Exception('Network error');
    int assigned = 0;
    int unassigned = 0;
    int manual = 0;
    int excel = 0;
    int csv = 0;
    for (final l in leads) {
      if (l.isAssigned) {
        assigned++;
      } else {
        unassigned++;
      }
      switch (l.source) {
        case LeadSource.manual:
          manual++;
          break;
        case LeadSource.excel:
          excel++;
          break;
        case LeadSource.csv:
          csv++;
          break;
      }
    }
    return LeadSummary(
      totalLeads: leads.length,
      assignedLeads: assigned,
      unassignedLeads: unassigned,
      manualLeads: manual,
      excelLeads: excel,
      csvLeads: csv,
    );
  }
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

    test(
      'regression: dashboard metrics aggregate all leads when total > page size',
      () async {
        // Dataset of 25 leads, where default LeadQuery.pageSize is 20:
        // Page 1 (first 20): 12 assigned (agent-1), 8 unassigned
        //                     8 manual, 7 excel, 5 csv
        // Page 2 (items 21..25): 3 assigned (agent-2), 2 unassigned
        //                        2 manual, 2 excel, 1 csv
        // Full dataset totals:
        // total: 25
        // assigned: 15 (12 + 3)
        // unassigned: 10 (8 + 2)
        // manual: 10 (8 + 2)
        // excel: 9 (7 + 2)
        // csv: 6 (5 + 1)
        final testLeads = <Lead>[
          ...List.generate(
            8,
            (i) => Lead(
              id: 'cubit-p1-man-asg-$i',
              source: LeadSource.manual,
              assignedUserId: 'agent-1',
            ),
          ),
          ...List.generate(
            4,
            (i) => Lead(
              id: 'cubit-p1-exc-asg-$i',
              source: LeadSource.excel,
              assignedUserId: 'agent-1',
            ),
          ),
          ...List.generate(
            3,
            (i) => Lead(
              id: 'cubit-p1-exc-unasg-$i',
              source: LeadSource.excel,
              assignedUserId: null,
            ),
          ),
          ...List.generate(
            5,
            (i) => Lead(
              id: 'cubit-p1-csv-unasg-$i',
              source: LeadSource.csv,
              assignedUserId: null,
            ),
          ),
          // Beyond page 1 (items 21..25):
          ...List.generate(
            2,
            (i) => Lead(
              id: 'cubit-p2-man-asg-$i',
              source: LeadSource.manual,
              assignedUserId: 'agent-2',
            ),
          ),
          ...List.generate(
            1,
            (i) => Lead(
              id: 'cubit-p2-exc-asg-$i',
              source: LeadSource.excel,
              assignedUserId: 'agent-2',
            ),
          ),
          ...List.generate(
            1,
            (i) => Lead(
              id: 'cubit-p2-exc-unasg-$i',
              source: LeadSource.excel,
              assignedUserId: null,
            ),
          ),
          ...List.generate(
            1,
            (i) => Lead(
              id: 'cubit-p2-csv-unasg-$i',
              source: LeadSource.csv,
              assignedUserId: null,
            ),
          ),
        ];

        final mockRepo = MockLeadRepository(
          dataSource: MockLeadDataSource(initialLeads: testLeads),
        );
        final cubit = LeadDashboardCubit(mockRepo);

        // Verify that default getLeads returns only first 20 items
        final firstPage = await mockRepo.getLeads();
        expect(firstPage.items.length, 20);
        expect(firstPage.totalItems, 25);
        expect(firstPage.hasNext, isTrue);

        await cubit.loadDashboard();
        await pumpEventQueue();

        expect(cubit.state, isA<LeadDashboardLoaded>());
        final loaded = cubit.state as LeadDashboardLoaded;

        // Verify that dashboard metrics include the 5 records beyond page 1
        expect(loaded.metrics.totalLeads, 25);
        expect(loaded.metrics.assignedLeads, 15);
        expect(loaded.metrics.unassignedLeads, 10);
        expect(loaded.metrics.manualLeads, 10);
        expect(loaded.metrics.excelLeads, 9);
        expect(loaded.metrics.csvLeads, 6);
      },
    );
  });
}
