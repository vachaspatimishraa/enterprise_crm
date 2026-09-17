import 'dart:async';

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
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_assignment_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_assignment_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadRepository implements LeadRepository {
  List<LeadAssignee> assignees = const [];
  bool shouldThrowOnGetAssignees = false;
  bool shouldThrowOnAssignLead = false;
  bool shouldThrowOnAssignLeads = false;

  int getAssignableUsersCallCount = 0;
  int assignLeadCallCount = 0;
  int assignLeadsCallCount = 0;

  String? lastAssignedLeadId;
  String? lastAssignedAssigneeId;
  LeadAssignmentRequest? lastAssignmentRequest;

  Completer<void>? assignLeadCompleter;

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async {
    getAssignableUsersCallCount++;
    if (shouldThrowOnGetAssignees) {
      throw Exception('Failed to fetch assignable users');
    }
    return assignees;
  }

  @override
  Future<void> assignLead({
    required String leadId,
    required String assigneeId,
  }) async {
    assignLeadCallCount++;
    lastAssignedLeadId = leadId;
    lastAssignedAssigneeId = assigneeId;

    if (assignLeadCompleter != null) {
      await assignLeadCompleter!.future;
    }

    if (shouldThrowOnAssignLead) {
      throw Exception('Failed to assign single lead');
    }
  }

  @override
  Future<void> assignLeads(LeadAssignmentRequest request) async {
    assignLeadsCallCount++;
    lastAssignmentRequest = request;

    if (shouldThrowOnAssignLeads) {
      throw Exception('Failed to assign leads in bulk');
    }
  }

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) async {}

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
  Future<LeadSummary> getLeadSummary() async => const LeadSummary(
    totalLeads: 0,
    assignedLeads: 0,
    unassignedLeads: 0,
    manualLeads: 0,
    excelLeads: 0,
    csvLeads: 0,
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
  Future<LeadExportResult> exportLeads(LeadExportRequest request) async =>
      const LeadExportResult(fileReference: 'dummy', fileName: 'export.csv');
}

void main() {
  late _FakeLeadRepository repository;
  late LeadAssignmentCubit cubit;

  const agent1 = LeadAssignee(id: 'agent-1', displayName: 'Mock Agent One');
  const agent2 = LeadAssignee(id: 'agent-2', displayName: 'Mock Agent Two');

  setUp(() {
    repository = _FakeLeadRepository();
    cubit = LeadAssignmentCubit(repository);
  });

  tearDown(() {
    cubit.close();
  });

  group('LeadAssignmentCubit - Load Assignable Users', () {
    test(
      'initial state has unloaded assignees, no selection, and idle submission',
      () {
        expect(cubit.state.loadStatus, equals(AssigneeLoadStatus.initial));
        expect(
          cubit.state.submissionStatus,
          equals(AssignmentSubmissionStatus.idle),
        );
        expect(cubit.state.assignees, isEmpty);
        expect(cubit.state.selectedAssignee, isNull);
        expect(cubit.state.loadErrorMessage, isNull);
        expect(cubit.state.submissionErrorMessage, isNull);
        expect(cubit.state.isLoadingAssignees, isFalse);
        expect(cubit.state.isSubmitting, isFalse);
      },
    );

    test(
      'loading -> success emits loading then ready with assignees returned intact',
      () async {
        repository.assignees = [agent1, agent2];

        final states = <LeadAssignmentState>[];
        cubit.stream.listen(states.add);

        await cubit.loadAssignableUsers();
        await pumpEventQueue();

        expect(states.length, 2);
        expect(states[0].loadStatus, equals(AssigneeLoadStatus.loading));
        expect(states[0].isLoadingAssignees, isTrue);

        expect(states[1].loadStatus, equals(AssigneeLoadStatus.success));
        expect(states[1].assignees, equals([agent1, agent2]));
        expect(states[1].loadErrorMessage, isNull);
        expect(repository.getAssignableUsersCallCount, equals(1));
      },
    );

    test('loading -> failure emits safe failure message', () async {
      repository.shouldThrowOnGetAssignees = true;

      final states = <LeadAssignmentState>[];
      cubit.stream.listen(states.add);

      await cubit.loadAssignableUsers();
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0].loadStatus, equals(AssigneeLoadStatus.loading));
      expect(states[1].loadStatus, equals(AssigneeLoadStatus.failure));
      expect(states[1].hasLoadError, isTrue);
      expect(
        states[1].loadErrorMessage,
        equals('Unable to load assignable users.'),
      );
    });

    test(
      'retry works and preserves cached assignees when re-loading',
      () async {
        repository.assignees = [agent1];
        await cubit.loadAssignableUsers();
        expect(cubit.state.assignees, equals([agent1]));

        // Subsequent failure preserves previous assignees
        repository.shouldThrowOnGetAssignees = true;
        await cubit.loadAssignableUsers();

        expect(cubit.state.loadStatus, equals(AssigneeLoadStatus.failure));
        expect(cubit.state.assignees, equals([agent1]));
        expect(
          cubit.state.loadErrorMessage,
          equals('Unable to load assignable users.'),
        );

        // Retry recovers
        repository.shouldThrowOnGetAssignees = false;
        repository.assignees = [agent1, agent2];
        await cubit.loadAssignableUsers();

        expect(cubit.state.loadStatus, equals(AssigneeLoadStatus.success));
        expect(cubit.state.assignees, equals([agent1, agent2]));
      },
    );

    test('empty assignee list works truthfully', () async {
      repository.assignees = const [];
      await cubit.loadAssignableUsers();

      expect(cubit.state.loadStatus, equals(AssigneeLoadStatus.success));
      expect(cubit.state.assignees, isEmpty);
      expect(cubit.state.selectedAssignee, isNull);
    });
  });

  group('LeadAssignmentCubit - Assignee Selection', () {
    test('selects known assignee from loaded list', () async {
      repository.assignees = [agent1, agent2];
      await cubit.loadAssignableUsers();

      cubit.selectAssignee(agent1);
      expect(cubit.state.selectedAssignee, equals(agent1));

      cubit.selectAssignee(agent2);
      expect(cubit.state.selectedAssignee, equals(agent2));
    });

    test('clears selection via clearSelectedAssignee', () async {
      repository.assignees = [agent1];
      await cubit.loadAssignableUsers();

      cubit.selectAssignee(agent1);
      expect(cubit.state.selectedAssignee, equals(agent1));

      cubit.clearSelectedAssignee();
      expect(cubit.state.selectedAssignee, isNull);
    });

    test('rejects/ignores unknown assignee not in loaded list', () async {
      repository.assignees = [agent1];
      await cubit.loadAssignableUsers();

      const unknownAgent = LeadAssignee(id: 'fake-99', displayName: 'Imposter');
      cubit.selectAssignee(unknownAgent);

      // Selection was not applied
      expect(cubit.state.selectedAssignee, isNull);
    });
  });

  group('LeadAssignmentCubit - Single Assignment', () {
    const unassignedLead = Lead(
      id: 'lead-1',
      name: 'John Doe',
      source: LeadSource.manual,
    );

    const alreadyAssignedLead = Lead(
      id: 'lead-2',
      name: 'Jane Smith',
      source: LeadSource.manual,
      assignedUserId: 'agent-1',
      assignedUserName: 'Mock Agent One',
    );

    test(
      'no selection -> no repository call and safe failure message',
      () async {
        await cubit.assignLead(lead: unassignedLead);

        expect(repository.assignLeadCallCount, equals(0));
        expect(cubit.state.hasSubmissionError, isTrue);
        expect(
          cubit.state.submissionErrorMessage,
          equals('Select an assignee first.'),
        );
      },
    );

    test(
      'valid unassigned Lead -> calls assignLead with selected assignee',
      () async {
        repository.assignees = [agent1];
        await cubit.loadAssignableUsers();
        cubit.selectAssignee(agent1);

        await cubit.assignLead(lead: unassignedLead);

        expect(repository.assignLeadCallCount, equals(1));
        expect(repository.lastAssignedLeadId, equals('lead-1'));
        expect(repository.lastAssignedAssigneeId, equals('agent-1'));
        expect(cubit.state.isSubmissionSuccess, isTrue);
      },
    );

    test(
      'repository failure -> emits safe failure and preserves selected assignee',
      () async {
        repository.assignees = [agent1];
        await cubit.loadAssignableUsers();
        cubit.selectAssignee(agent1);
        repository.shouldThrowOnAssignLead = true;

        await cubit.assignLead(lead: unassignedLead);

        expect(repository.assignLeadCallCount, equals(1));
        expect(cubit.state.hasSubmissionError, isTrue);
        expect(
          cubit.state.submissionErrorMessage,
          equals('Unable to assign the Lead.'),
        );
        expect(cubit.state.selectedAssignee, equals(agent1));
      },
    );

    test(
      'already-assigned Lead is rejected and not submitted (L5/L6 boundary)',
      () async {
        repository.assignees = [agent1];
        await cubit.loadAssignableUsers();
        cubit.selectAssignee(agent1);

        await cubit.assignLead(lead: alreadyAssignedLead);

        expect(repository.assignLeadCallCount, equals(0));
        expect(cubit.state.hasSubmissionError, isTrue);
        expect(
          cubit.state.submissionErrorMessage,
          equals('Lead is already assigned.'),
        );
      },
    );
  });

  group('LeadAssignmentCubit - Bulk Assignment', () {
    const leadA = Lead(id: 'lead-1', name: 'Lead A', source: LeadSource.manual);
    const leadB = Lead(id: 'lead-2', name: 'Lead B', source: LeadSource.manual);
    const leadAssigned = Lead(
      id: 'lead-3',
      name: 'Lead C',
      source: LeadSource.manual,
      assignedUserId: 'agent-1',
    );

    test('empty leads list -> no repository call', () async {
      repository.assignees = [agent1];
      await cubit.loadAssignableUsers();
      cubit.selectAssignee(agent1);

      await cubit.assignLeads(leads: const []);

      expect(repository.assignLeadsCallCount, equals(0));
      expect(cubit.state.hasSubmissionError, isTrue);
      expect(
        cubit.state.submissionErrorMessage,
        equals('Select at least one Lead to assign.'),
      );
    });

    test('no selection -> no repository call', () async {
      await cubit.assignLeads(leads: [leadA, leadB]);

      expect(repository.assignLeadsCallCount, equals(0));
      expect(cubit.state.hasSubmissionError, isTrue);
      expect(
        cubit.state.submissionErrorMessage,
        equals('Select an assignee first.'),
      );
    });

    test(
      'valid unassigned leads -> constructs correct LeadAssignmentRequest and preserves order',
      () async {
        repository.assignees = [agent1];
        await cubit.loadAssignableUsers();
        cubit.selectAssignee(agent1);

        await cubit.assignLeads(leads: [leadA, leadB]);

        expect(repository.assignLeadsCallCount, equals(1));
        expect(repository.lastAssignmentRequest, isNotNull);
        expect(
          repository.lastAssignmentRequest!.leadIds,
          equals(['lead-1', 'lead-2']),
        );
        expect(repository.lastAssignmentRequest!.assigneeId, equals('agent-1'));
        expect(cubit.state.isSubmissionSuccess, isTrue);
      },
    );

    test(
      'already-assigned Lead in batch -> whole submission rejected safely without repository call',
      () async {
        repository.assignees = [agent1];
        await cubit.loadAssignableUsers();
        cubit.selectAssignee(agent1);

        await cubit.assignLeads(leads: [leadA, leadAssigned, leadB]);

        expect(repository.assignLeadsCallCount, equals(0));
        expect(cubit.state.hasSubmissionError, isTrue);
        expect(
          cubit.state.submissionErrorMessage,
          equals('Cannot assign already-assigned Leads.'),
        );
      },
    );

    test(
      'repository failure on bulk assign -> emits safe failure and preserves selected assignee',
      () async {
        repository.assignees = [agent1];
        await cubit.loadAssignableUsers();
        cubit.selectAssignee(agent1);
        repository.shouldThrowOnAssignLeads = true;

        await cubit.assignLeads(leads: [leadA, leadB]);

        expect(repository.assignLeadsCallCount, equals(1));
        expect(cubit.state.hasSubmissionError, isTrue);
        expect(
          cubit.state.submissionErrorMessage,
          equals('Unable to assign the selected Leads.'),
        );
        expect(cubit.state.selectedAssignee, equals(agent1));
      },
    );
  });

  group('LeadAssignmentCubit - Concurrency Protection', () {
    test(
      'second submit while first pending causes only one repository call',
      () async {
        repository.assignees = [agent1];
        await cubit.loadAssignableUsers();
        cubit.selectAssignee(agent1);

        final completer = Completer<void>();
        repository.assignLeadCompleter = completer;

        const lead = Lead(
          id: 'lead-1',
          name: 'John Doe',
          source: LeadSource.manual,
        );

        // Start first submission (will hang on completer)
        final future1 = cubit.assignLead(lead: lead);
        expect(cubit.state.isSubmitting, isTrue);

        // Attempt second submission concurrently
        final future2 = cubit.assignLead(lead: lead);

        // Finish first call
        completer.complete();
        await Future.wait([future1, future2]);

        expect(repository.assignLeadCallCount, equals(1));
        expect(cubit.state.isSubmissionSuccess, isTrue);
      },
    );
  });
}
