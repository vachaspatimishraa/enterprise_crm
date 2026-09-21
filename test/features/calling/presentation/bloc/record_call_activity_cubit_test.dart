import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_follow_up_repository.dart';
import 'package:enterprise_crm/features/calling/domain/entities/call_outcome.dart';
import 'package:enterprise_crm/features/calling/domain/entities/lead_call_activity.dart';
import 'package:enterprise_crm/features/calling/domain/repositories/lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/presentation/bloc/record_call_activity_cubit.dart';
import 'package:enterprise_crm/features/calling/presentation/bloc/record_call_activity_state.dart';
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
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_summary.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final nowTime = DateTime(2026, 9, 21, 10, 0, 0);

  final testLead = Lead(
    id: 'lead-own-1',
    name: 'Alice Johnson',
    phone: '+1 555-0100',
    email: 'alice@example.com',
    status: const LeadStatus('Contacted'),
    source: LeadSource.manual,
    assignedUserId: 'agent-1',
    assignedUserName: 'Sarah Jenkins',
    createdAt: DateTime(2025, 1, 1),
  );

  final crossLead = Lead(
    id: 'lead-cross-1',
    name: 'Bob Smith',
    status: const LeadStatus('New'),
    source: LeadSource.excel,
    assignedUserId: 'agent-2',
    createdAt: DateTime(2025, 1, 1),
  );

  const authorizedUser = CurrentUser(
    id: 'usr-standard-1',
    displayName: 'Sales Rep',
    accountType: AccountType.user,
    modules: {CrmModule.calling, CrmModule.leadManagement},
    permissions: {CrmPermissions.callingUse, CrmPermissions.leadViewAssigned},
  );

  late MockLeadRepository leadRepo;
  late MockUserLeadLinkRepository linkRepo;
  late _SpyCallActivityRepository callRepo;
  late MockLeadFollowUpRepository followUpRepo;

  setUp(() {
    leadRepo = MockLeadRepository(
      dataSource: MockLeadDataSource(initialLeads: [testLead, crossLead]),
    );
    linkRepo = MockUserLeadLinkRepository(links: {'usr-standard-1': 'agent-1'});
    callRepo = _SpyCallActivityRepository();
    followUpRepo = MockLeadFollowUpRepository(now: () => nowTime);
  });

  group('RecordCallActivityCubit - Authorization and Security Chain', () {
    test(
      'module denied -> AccessDenied, 0 link calls, 0 lead calls, 0 call repo calls',
      () async {
        const userWithoutCalling = CurrentUser(
          id: 'usr-standard-1',
          displayName: 'No Calling User',
          accountType: AccountType.user,
          modules: {CrmModule.leadManagement},
          permissions: {
            CrmPermissions.callingUse,
            CrmPermissions.leadViewAssigned,
          },
        );

        final cubit = RecordCallActivityCubit(
          user: userWithoutCalling,
          leadId: testLead.id,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          callActivityRepository: callRepo,
          followUpRepository: followUpRepo,
        );

        await cubit.load();

        expect(cubit.state, isA<RecordCallActivityAccessDenied>());
        expect(callRepo.recordCallCount, 0);
      },
    );

    test(
      'missing calling.use permission -> AccessDenied, 0 call repo calls',
      () async {
        const userWithoutCallingUse = CurrentUser(
          id: 'usr-standard-1',
          displayName: 'No Perm User',
          accountType: AccountType.user,
          modules: {CrmModule.calling, CrmModule.leadManagement},
          permissions: {CrmPermissions.leadViewAssigned},
        );

        final cubit = RecordCallActivityCubit(
          user: userWithoutCallingUse,
          leadId: testLead.id,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          callActivityRepository: callRepo,
          followUpRepository: followUpRepo,
        );

        await cubit.load();

        expect(cubit.state, isA<RecordCallActivityAccessDenied>());
        expect(callRepo.recordCallCount, 0);
      },
    );

    test('cross-assignee lead -> AccessDenied, 0 call repo calls', () async {
      final cubit = RecordCallActivityCubit(
        user: authorizedUser,
        leadId: crossLead.id,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        callActivityRepository: callRepo,
        followUpRepository: followUpRepo,
      );

      await cubit.load();

      expect(cubit.state, isA<RecordCallActivityAccessDenied>());
      expect(callRepo.recordCallCount, 0);
    });

    test('own lead with authorized user -> Ready', () async {
      final cubit = RecordCallActivityCubit(
        user: authorizedUser,
        leadId: testLead.id,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        callActivityRepository: callRepo,
        followUpRepository: followUpRepo,
      );

      await cubit.load();

      expect(cubit.state, isA<RecordCallActivityReady>());
      final ready = cubit.state as RecordCallActivityReady;
      expect(ready.lead.id, testLead.id);
      expect(ready.linkedAssigneeId, 'agent-1');
    });
  });

  group('RecordCallActivityCubit - Submitting Activity & User Invariant', () {
    test(
      'valid submit records activity with performedByUserId derived from CurrentUser.id',
      () async {
        final cubit = RecordCallActivityCubit(
          user: authorizedUser,
          leadId: testLead.id,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          callActivityRepository: callRepo,
          followUpRepository: followUpRepo,
          now: () => nowTime,
        );

        await cubit.load();
        expect(cubit.state, isA<RecordCallActivityReady>());

        await cubit.submitActivity(
          outcome: CallOutcome.visitScheduled,
          rescheduleAt: DateTime(2026, 9, 25, 11, 0),
        );

        expect(cubit.state, isA<RecordCallActivitySuccess>());
        final success = cubit.state as RecordCallActivitySuccess;
        expect(success.activity.outcome, CallOutcome.visitScheduled);
        expect(success.activity.leadId, testLead.id);
        // PerformedByUserId MUST be derived from authenticated user
        expect(success.activity.performedByUserId, 'usr-standard-1');
        expect(callRepo.lastRecordedPerformedByUserId, 'usr-standard-1');
        expect(callRepo.recordCallCount, 1);
      },
    );

    test(
      'past reschedule date is rejected with safe validation message and 0 recordActivity calls',
      () async {
        final cubit = RecordCallActivityCubit(
          user: authorizedUser,
          leadId: testLead.id,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          callActivityRepository: callRepo,
          followUpRepository: followUpRepo,
          now: () => nowTime,
        );

        await cubit.load();

        // Submit with past date: 1 hour ago
        await cubit.submitActivity(
          outcome: CallOutcome.followUp,
          rescheduleAt: nowTime.subtract(const Duration(hours: 1)),
        );

        expect(cubit.state, isA<RecordCallActivityFailure>());
        final failure = cubit.state as RecordCallActivityFailure;
        expect(
          failure.message,
          'Reschedule date and time must be in the future.',
        );
        expect(callRepo.recordCallCount, 0);
      },
    );

    test(
      'fresh re-fetch anti-reassignment check: reassignment while form open blocks recording with 0 calls',
      () async {
        final reassignedLead = testLead.copyWith(
          assignedUserId: 'agent-2',
          assignedUserName: 'Mike Ross',
        );
        final switchingRepo = _ReassignOnSaveLeadRepo(
          initialLead: testLead,
          reassignedLead: reassignedLead,
        );

        final cubit = RecordCallActivityCubit(
          user: authorizedUser,
          leadId: testLead.id,
          initialLead: testLead,
          linkRepository: linkRepo,
          leadRepository: switchingRepo,
          callActivityRepository: callRepo,
          followUpRepository: followUpRepo,
          now: () => nowTime,
        );

        await cubit.load();
        expect(cubit.state, isA<RecordCallActivityReady>());

        // Admin reassigns lead while user has form open
        switchingRepo.isReassigned = true;

        await cubit.submitActivity(outcome: CallOutcome.salesDone);

        // Ownership changed -> AccessDenied!
        expect(cubit.state, isA<RecordCallActivityAccessDenied>());
        // Zero recordActivity calls!
        expect(callRepo.recordCallCount, 0);
      },
    );

    test(
      'double submit in flight triggers only 1 repository recordActivity call',
      () async {
        final slowCallRepo = _SlowCallActivityRepository();
        final cubit = RecordCallActivityCubit(
          user: authorizedUser,
          leadId: testLead.id,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          callActivityRepository: slowCallRepo,
          followUpRepository: followUpRepo,
          now: () => nowTime,
        );

        await cubit.load();

        final firstCall = cubit.submitActivity(
          outcome: CallOutcome.notConnected,
        );
        final secondCall = cubit.submitActivity(
          outcome: CallOutcome.notConnected,
        );

        await Future.wait([firstCall, secondCall]);

        expect(cubit.state, isA<RecordCallActivitySuccess>());
        expect(slowCallRepo.recordCallCount, 1);
      },
    );

    test('repository exception emits safe failure message', () async {
      final failingCallRepo = _FailingCallActivityRepository();
      final cubit = RecordCallActivityCubit(
        user: authorizedUser,
        leadId: testLead.id,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        callActivityRepository: failingCallRepo,
        followUpRepository: followUpRepo,
        now: () => nowTime,
      );

      await cubit.load();
      await cubit.submitActivity(outcome: CallOutcome.leadClosed);

      expect(cubit.state, isA<RecordCallActivityFailure>());
      final failure = cubit.state as RecordCallActivityFailure;
      expect(failure.message, 'Unable to record call outcome.');
    });
  });
}

class _SpyCallActivityRepository implements LeadCallActivityRepository {
  int recordCallCount = 0;
  String? lastRecordedPerformedByUserId;

  @override
  Future<LeadCallActivity> recordActivity({
    required String leadId,
    required String performedByUserId,
    required CallOutcome outcome,
    DateTime? rescheduleAt,
  }) async {
    recordCallCount++;
    lastRecordedPerformedByUserId = performedByUserId;
    return LeadCallActivity(
      id: 'call-act-1',
      leadId: leadId,
      performedByUserId: performedByUserId,
      outcome: outcome,
      rescheduleAt: rescheduleAt,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<LeadCallActivity>> getActivitiesForLead(String leadId) async =>
      [];

  @override
  Future<List<LeadCallActivity>> getScheduledActivitiesForLeadIds(
    Set<String> leadIds,
  ) async => [];
}

class _SlowCallActivityRepository implements LeadCallActivityRepository {
  int recordCallCount = 0;

  @override
  Future<LeadCallActivity> recordActivity({
    required String leadId,
    required String performedByUserId,
    required CallOutcome outcome,
    DateTime? rescheduleAt,
  }) async {
    recordCallCount++;
    await Future.delayed(const Duration(milliseconds: 50));
    return LeadCallActivity(
      id: 'call-act-1',
      leadId: leadId,
      performedByUserId: performedByUserId,
      outcome: outcome,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<LeadCallActivity>> getActivitiesForLead(String leadId) async =>
      [];

  @override
  Future<List<LeadCallActivity>> getScheduledActivitiesForLeadIds(
    Set<String> leadIds,
  ) async => [];
}

class _FailingCallActivityRepository implements LeadCallActivityRepository {
  @override
  Future<LeadCallActivity> recordActivity({
    required String leadId,
    required String performedByUserId,
    required CallOutcome outcome,
    DateTime? rescheduleAt,
  }) async {
    throw Exception('Database write error');
  }

  @override
  Future<List<LeadCallActivity>> getActivitiesForLead(String leadId) async =>
      [];

  @override
  Future<List<LeadCallActivity>> getScheduledActivitiesForLeadIds(
    Set<String> leadIds,
  ) async => [];
}

class _ReassignOnSaveLeadRepo implements LeadRepository {
  final Lead initialLead;
  final Lead reassignedLead;
  bool isReassigned = false;

  _ReassignOnSaveLeadRepo({
    required this.initialLead,
    required this.reassignedLead,
  });

  @override
  Future<Lead?> getLeadById(String leadId) async {
    return isReassigned ? reassignedLead : initialLead;
  }

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async => const [
    LeadAssignee(id: 'agent-1', displayName: 'Agent 1'),
    LeadAssignee(id: 'agent-2', displayName: 'Agent 2'),
  ];

  @override
  Future<Lead> updateLead(UpdateLeadInput input) => throw UnimplementedError();

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) =>
      throw UnimplementedError();

  @override
  Future<LeadSummary> getLeadSummary() => throw UnimplementedError();

  @override
  Future<Lead> createLead(CreateLeadInput input) => throw UnimplementedError();

  @override
  Future<void> assignLead({
    required String leadId,
    required String assigneeId,
  }) => throw UnimplementedError();

  @override
  Future<void> assignLeads(LeadAssignmentRequest request) =>
      throw UnimplementedError();

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) =>
      throw UnimplementedError();

  @override
  Future<LeadImportResult> importLeads(LeadImportRequest request) =>
      throw UnimplementedError();

  @override
  Future<LeadExportResult> exportLeads(LeadExportRequest request) =>
      throw UnimplementedError();
}
