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
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_reassignment_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_reassignment_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadRepository implements LeadRepository {
  List<LeadAssignee> assignees = const [];
  bool shouldThrowOnGetAssignees = false;
  bool shouldThrowOnReassignLead = false;

  int getAssignableUsersCallCount = 0;
  int reassignLeadCallCount = 0;

  LeadReassignmentRequest? lastReassignmentRequest;
  Completer<void>? reassignLeadCompleter;

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async {
    getAssignableUsersCallCount++;
    if (shouldThrowOnGetAssignees) {
      throw Exception('Failed to fetch assignable users');
    }
    return assignees;
  }

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) async {
    reassignLeadCallCount++;
    lastReassignmentRequest = request;

    if (reassignLeadCompleter != null) {
      await reassignLeadCompleter!.future;
    }

    if (shouldThrowOnReassignLead) {
      throw Exception('Failed to reassign lead');
    }
  }

  @override
  Future<void> assignLead({
    required String leadId,
    required String assigneeId,
  }) async {}

  @override
  Future<void> assignLeads(LeadAssignmentRequest request) async {}

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
  group('LeadReassignmentCubit', () {
    late _FakeLeadRepository repository;
    late LeadReassignmentCubit cubit;

    const agent1 = LeadAssignee(id: 'agent-1', displayName: 'Agent One');
    const agent2 = LeadAssignee(id: 'agent-2', displayName: 'Agent Two');
    const agent3 = LeadAssignee(id: 'agent-3', displayName: 'Agent Three');

    const assignedLead = Lead(
      id: 'lead-100',
      name: 'Test Customer',
      source: LeadSource.manual,
      assignedUserId: 'agent-1',
      assignedUserName: 'Agent One',
    );

    const unassignedLead = Lead(
      id: 'lead-200',
      name: 'Unassigned Customer',
      source: LeadSource.manual,
      assignedUserId: null,
      assignedUserName: null,
    );

    setUp(() {
      repository = _FakeLeadRepository();
      repository.assignees = [agent1, agent2, agent3];
      cubit = LeadReassignmentCubit(repository);
    });

    tearDown(() {
      cubit.close();
    });

    group('Initial State & Assignee Loading', () {
      test('has correct initial state values', () {
        expect(cubit.state.loadStatus, AssigneeLoadStatus.initial);
        expect(cubit.state.submissionStatus, ReassignmentSubmissionStatus.idle);
        expect(cubit.state.assignees, isEmpty);
        expect(cubit.state.selectedAssignee, isNull);
        expect(cubit.state.reason, isNull);
        expect(cubit.state.loadErrorMessage, isNull);
        expect(cubit.state.submissionErrorMessage, isNull);
        expect(cubit.state.canSubmit, isFalse);
        expect(cubit.state.isSubmitting, isFalse);
      });

      test('loadAssignableUsers loads assignees successfully', () async {
        final future = cubit.loadAssignableUsers();
        expect(cubit.state.isLoadingAssignees, isTrue);
        await future;

        expect(cubit.state.loadStatus, AssigneeLoadStatus.success);
        expect(cubit.state.assignees.length, 3);
        expect(cubit.state.assignees[0].id, 'agent-1');
        expect(cubit.state.hasLoadError, isFalse);
        expect(cubit.state.loadErrorMessage, isNull);
        expect(repository.getAssignableUsersCallCount, 1);
      });

      test(
        'loadAssignableUsers emits safe failure on repository error',
        () async {
          repository.shouldThrowOnGetAssignees = true;

          await cubit.loadAssignableUsers();

          expect(cubit.state.loadStatus, AssigneeLoadStatus.failure);
          expect(cubit.state.hasLoadError, isTrue);
          expect(
            cubit.state.loadErrorMessage,
            'Unable to load assignable users.',
          );
          expect(cubit.state.loadErrorMessage, isNot(contains('Exception')));
        },
      );

      test('retry works after load failure', () async {
        repository.shouldThrowOnGetAssignees = true;
        await cubit.loadAssignableUsers();
        expect(cubit.state.hasLoadError, isTrue);

        repository.shouldThrowOnGetAssignees = false;
        await cubit.loadAssignableUsers();

        expect(cubit.state.loadStatus, AssigneeLoadStatus.success);
        expect(cubit.state.assignees.length, 3);
        expect(cubit.state.loadErrorMessage, isNull);
      });

      test('empty assignee list is loaded truthfully without error', () async {
        repository.assignees = [];

        await cubit.loadAssignableUsers();

        expect(cubit.state.loadStatus, AssigneeLoadStatus.success);
        expect(cubit.state.assignees, isEmpty);
        expect(cubit.state.hasLoadError, isFalse);
      });

      test(
        'preserves previously loaded assignees if later reload fails',
        () async {
          await cubit.loadAssignableUsers();
          expect(cubit.state.assignees.length, 3);

          repository.shouldThrowOnGetAssignees = true;
          await cubit.loadAssignableUsers();

          expect(cubit.state.loadStatus, AssigneeLoadStatus.failure);
          expect(cubit.state.assignees.length, 3);
          expect(
            cubit.state.loadErrorMessage,
            'Unable to load assignable users.',
          );
        },
      );
    });

    group('Selection Handling', () {
      setUp(() async {
        await cubit.loadAssignableUsers();
      });

      test('selects valid repository assignee and clears submission error', () {
        cubit.selectAssignee(agent2);

        expect(cubit.state.selectedAssignee, agent2);
        expect(cubit.state.canSubmit, isTrue);
      });

      test(
        'clearSelectedAssignee clears replacement selection without unassigning',
        () {
          cubit.selectAssignee(agent2);
          expect(cubit.state.selectedAssignee, agent2);

          cubit.clearSelectedAssignee();

          expect(cubit.state.selectedAssignee, isNull);
          expect(cubit.state.canSubmit, isFalse);
        },
      );

      test(
        'rejects / ignores unknown assignee not in loaded repository list',
        () {
          const unknown = LeadAssignee(
            id: 'rogue-99',
            displayName: 'Rogue User',
          );

          cubit.selectAssignee(unknown);

          expect(cubit.state.selectedAssignee, isNull);
          expect(cubit.state.canSubmit, isFalse);
        },
      );

      test(
        'current assignee can be selected in UI list but cannot be submitted',
        () async {
          cubit.selectAssignee(
            agent1,
          ); // current assignee for assignedLead is agent-1
          expect(cubit.state.selectedAssignee, agent1);

          await cubit.reassignLead(lead: assignedLead);

          expect(
            cubit.state.submissionStatus,
            ReassignmentSubmissionStatus.failure,
          );
          expect(
            cubit.state.submissionErrorMessage,
            'Select a different assignee.',
          );
          expect(repository.reassignLeadCallCount, 0);
        },
      );
    });

    group('Eligibility Guard', () {
      setUp(() async {
        await cubit.loadAssignableUsers();
        cubit.selectAssignee(agent2);
      });

      test(
        'unassigned Lead is rejected and repository is not called',
        () async {
          await cubit.reassignLead(lead: unassignedLead);

          expect(
            cubit.state.submissionStatus,
            ReassignmentSubmissionStatus.failure,
          );
          expect(
            cubit.state.submissionErrorMessage,
            'This Lead is not currently assigned.',
          );
          expect(repository.reassignLeadCallCount, 0);
        },
      );

      test('assigned Lead is permitted to reassign', () async {
        await cubit.reassignLead(lead: assignedLead);

        expect(
          cubit.state.submissionStatus,
          ReassignmentSubmissionStatus.success,
        );
        expect(repository.reassignLeadCallCount, 1);
        expect(repository.lastReassignmentRequest!.leadId, 'lead-100');
        expect(repository.lastReassignmentRequest!.newAssigneeId, 'agent-2');
      });
    });

    group('Reason Normalization & Handling', () {
      setUp(() async {
        await cubit.loadAssignableUsers();
        cubit.selectAssignee(agent2);
      });

      test('updateReason updates state reason', () {
        cubit.updateReason('Workload balancing');
        expect(cubit.state.reason, 'Workload balancing');

        cubit.updateReason(null);
        expect(cubit.state.reason, isNull);
      });

      test('null reason results in null request reason', () async {
        await cubit.reassignLead(lead: assignedLead, reason: null);

        expect(repository.reassignLeadCallCount, 1);
        expect(repository.lastReassignmentRequest!.reason, isNull);
      });

      test('blank whitespace-only reason normalizes to null', () async {
        await cubit.reassignLead(lead: assignedLead, reason: '   \t  \n  ');

        expect(repository.reassignLeadCallCount, 1);
        expect(repository.lastReassignmentRequest!.reason, isNull);
      });

      test('whitespace-trimmed reason is passed to repository', () async {
        await cubit.reassignLead(
          lead: assignedLead,
          reason: '  Territory rebalancing   ',
        );

        expect(repository.reassignLeadCallCount, 1);
        expect(
          repository.lastReassignmentRequest!.reason,
          'Territory rebalancing',
        );
      });

      test(
        'state reason is used as fallback when argument reason is not supplied',
        () async {
          cubit.updateReason('Agent on leave');

          await cubit.reassignLead(lead: assignedLead);

          expect(repository.reassignLeadCallCount, 1);
          expect(repository.lastReassignmentRequest!.reason, 'Agent on leave');
        },
      );
    });

    group('Submission Preconditions & Failure Recovery', () {
      setUp(() async {
        await cubit.loadAssignableUsers();
      });

      test(
        'reassignment without selecting replacement fails without repository call',
        () async {
          expect(cubit.state.selectedAssignee, isNull);

          await cubit.reassignLead(lead: assignedLead);

          expect(
            cubit.state.submissionStatus,
            ReassignmentSubmissionStatus.failure,
          );
          expect(
            cubit.state.submissionErrorMessage,
            'Select a replacement assignee first.',
          );
          expect(repository.reassignLeadCallCount, 0);
        },
      );

      test(
        'repository error emits safe failure and preserves selected assignee and reason',
        () async {
          repository.shouldThrowOnReassignLead = true;
          cubit.selectAssignee(agent3);
          cubit.updateReason('Customer request');

          await cubit.reassignLead(lead: assignedLead);

          expect(
            cubit.state.submissionStatus,
            ReassignmentSubmissionStatus.failure,
          );
          expect(
            cubit.state.submissionErrorMessage,
            'Unable to reassign the Lead.',
          );
          expect(
            cubit.state.submissionErrorMessage,
            isNot(contains('Exception')),
          );
          // Retained for user retry
          expect(cubit.state.selectedAssignee, agent3);
          expect(cubit.state.reason, 'Customer request');
          expect(cubit.state.assignees.length, 3);
        },
      );

      test('resetSubmission clears submission status back to idle', () async {
        repository.shouldThrowOnReassignLead = true;
        cubit.selectAssignee(agent3);
        await cubit.reassignLead(lead: assignedLead);
        expect(cubit.state.hasSubmissionError, isTrue);

        cubit.resetSubmission();

        expect(cubit.state.submissionStatus, ReassignmentSubmissionStatus.idle);
        expect(cubit.state.submissionErrorMessage, isNull);
        expect(cubit.state.selectedAssignee, agent3); // selection preserved
      });
    });

    group('Concurrency Protection', () {
      setUp(() async {
        await cubit.loadAssignableUsers();
        cubit.selectAssignee(agent2);
      });

      test(
        'blocks second submission while first reassignment is in-flight',
        () async {
          final completer = Completer<void>();
          repository.reassignLeadCompleter = completer;

          // Start first submission
          final firstFuture = cubit.reassignLead(lead: assignedLead);
          expect(cubit.state.isSubmitting, isTrue);

          // Attempt second submission concurrently
          final secondFuture = cubit.reassignLead(lead: assignedLead);

          // Complete the in-flight future
          completer.complete();
          await firstFuture;
          await secondFuture;

          expect(
            cubit.state.submissionStatus,
            ReassignmentSubmissionStatus.success,
          );
          expect(repository.reassignLeadCallCount, 1);
        },
      );
    });

    group('Reload Selection Preservation & Invalidation', () {
      test('preserves selected assignee on reload if still in list', () async {
        await cubit.loadAssignableUsers();
        cubit.selectAssignee(agent2);
        expect(cubit.state.selectedAssignee, agent2);

        await cubit.loadAssignableUsers();
        expect(cubit.state.selectedAssignee, agent2);
      });

      test('clears selected assignee on reload if dropped from list', () async {
        await cubit.loadAssignableUsers();
        cubit.selectAssignee(agent2);
        expect(cubit.state.selectedAssignee, agent2);

        repository.assignees = [agent1, agent3];
        await cubit.loadAssignableUsers();
        expect(cubit.state.selectedAssignee, isNull);
      });
    });

    group('LeadReassignmentState Equality & copyWith', () {
      test('supports value equality and copyWith overrides', () {
        const s1 = LeadReassignmentState();
        const s2 = LeadReassignmentState();
        expect(s1, equals(s2));
        expect(s1.hashCode, equals(s2.hashCode));

        final s3 = s1.copyWith(
          loadStatus: AssigneeLoadStatus.success,
          submissionStatus: ReassignmentSubmissionStatus.submitting,
          assignees: [agent1],
          selectedAssignee: agent1,
          reason: 'Reason A',
          loadErrorMessage: 'Load err',
          submissionErrorMessage: 'Sub err',
        );

        expect(s3.isLoadingAssignees, isFalse);
        expect(s3.isSubmitting, isTrue);
        expect(s3.assignees, [agent1]);
        expect(s3.selectedAssignee, agent1);
        expect(s3.reason, 'Reason A');

        final s4 = s3.copyWith(
          clearSelectedAssignee: true,
          clearReason: true,
          clearLoadErrorMessage: true,
          clearSubmissionErrorMessage: true,
        );

        expect(s4.selectedAssignee, isNull);
        expect(s4.reason, isNull);
        expect(s4.loadErrorMessage, isNull);
        expect(s4.submissionErrorMessage, isNull);
      });
    });
  });
}
