import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignee.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_summary.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_filter_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_filter_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadRepository implements LeadRepository {
  List<LeadAssignee> assignees = const [];
  bool shouldThrow = false;
  int getAssignableUsersCallCount = 0;

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async {
    getAssignableUsersCallCount++;
    if (shouldThrow) {
      throw Exception('Failed to fetch assignable users');
    }
    return assignees;
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
  late LeadFilterCubit cubit;

  setUp(() {
    repository = _FakeLeadRepository();
    cubit = LeadFilterCubit(repository);
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state is LeadFilterInitial', () {
    expect(cubit.state, equals(const LeadFilterInitial()));
  });

  test('loadAssignableUsers emits [Loading, Ready] on success', () async {
    final expectedAssignees = [
      const LeadAssignee(id: 'u1', displayName: 'Mock Agent One'),
      const LeadAssignee(id: 'u2', displayName: 'Mock Agent Two'),
    ];
    repository.assignees = expectedAssignees;

    final states = <LeadFilterState>[];
    cubit.stream.listen(states.add);

    await cubit.loadAssignableUsers();
    await pumpEventQueue();

    expect(states, [
      const LeadFilterLoading(),
      LeadFilterReady(expectedAssignees),
    ]);
    expect(repository.getAssignableUsersCallCount, equals(1));
  });

  test('loadAssignableUsers emits [Loading, Failure] on error', () async {
    repository.shouldThrow = true;

    final states = <LeadFilterState>[];
    cubit.stream.listen(states.add);

    await cubit.loadAssignableUsers();
    await pumpEventQueue();

    expect(states, [
      const LeadFilterLoading(),
      const LeadFilterFailure('Failed to fetch assignable users'),
    ]);
  });

  test('retryAssignableUsers reloads and recovers from error', () async {
    repository.shouldThrow = true;
    await cubit.loadAssignableUsers();
    expect(cubit.state, isA<LeadFilterFailure>());

    repository.shouldThrow = false;
    repository.assignees = [
      const LeadAssignee(id: 'u1', displayName: 'Agent 1'),
    ];

    await cubit.retryAssignableUsers();
    expect(
      cubit.state,
      equals(
        const LeadFilterReady([LeadAssignee(id: 'u1', displayName: 'Agent 1')]),
      ),
    );
    expect(repository.getAssignableUsersCallCount, equals(2));
  });
}
