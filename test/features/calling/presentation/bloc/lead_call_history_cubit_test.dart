import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/calling/domain/entities/call_outcome.dart';
import 'package:enterprise_crm/features/calling/domain/entities/lead_call_activity.dart';
import 'package:enterprise_crm/features/calling/domain/repositories/lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/presentation/bloc/lead_call_history_cubit.dart';
import 'package:enterprise_crm/features/calling/presentation/bloc/lead_call_history_state.dart';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testLead = Lead(
    id: 'lead-own-1',
    name: 'Alice Johnson',
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
  late _SpyCallHistoryRepository callRepo;

  setUp(() {
    leadRepo = MockLeadRepository(
      dataSource: MockLeadDataSource(initialLeads: [testLead, crossLead]),
    );
    linkRepo = MockUserLeadLinkRepository(links: {'usr-standard-1': 'agent-1'});
    callRepo = _SpyCallHistoryRepository();
  });

  group('LeadCallHistoryCubit - Authorization & 0 Call Invariants', () {
    test(
      'missing Calling module -> AccessDenied, 0 getActivities calls',
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

        final cubit = LeadCallHistoryCubit(
          user: userWithoutCalling,
          leadId: testLead.id,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          callActivityRepository: callRepo,
        );

        await cubit.loadHistory();

        expect(cubit.state, isA<LeadCallHistoryAccessDenied>());
        expect(callRepo.getActivitiesCallCount, 0);
      },
    );

    test(
      'missing calling.use permission -> AccessDenied, 0 getActivities calls',
      () async {
        const userWithoutCallingUse = CurrentUser(
          id: 'usr-standard-1',
          displayName: 'No Perm User',
          accountType: AccountType.user,
          modules: {CrmModule.calling, CrmModule.leadManagement},
          permissions: {CrmPermissions.leadViewAssigned},
        );

        final cubit = LeadCallHistoryCubit(
          user: userWithoutCallingUse,
          leadId: testLead.id,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          callActivityRepository: callRepo,
        );

        await cubit.loadHistory();

        expect(cubit.state, isA<LeadCallHistoryAccessDenied>());
        expect(callRepo.getActivitiesCallCount, 0);
      },
    );

    test(
      'missing Lead Management module -> AccessDenied, 0 getActivities calls',
      () async {
        const userWithoutLeadMod = CurrentUser(
          id: 'usr-standard-1',
          displayName: 'No Lead Mod User',
          accountType: AccountType.user,
          modules: {CrmModule.calling},
          permissions: {
            CrmPermissions.callingUse,
            CrmPermissions.leadViewAssigned,
          },
        );

        final cubit = LeadCallHistoryCubit(
          user: userWithoutLeadMod,
          leadId: testLead.id,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          callActivityRepository: callRepo,
        );

        await cubit.loadHistory();

        expect(cubit.state, isA<LeadCallHistoryAccessDenied>());
        expect(callRepo.getActivitiesCallCount, 0);
      },
    );

    test(
      'missing lead.view_assigned permission -> AccessDenied, 0 getActivities calls',
      () async {
        const userWithoutViewPerm = CurrentUser(
          id: 'usr-standard-1',
          displayName: 'No View Perm User',
          accountType: AccountType.user,
          modules: {CrmModule.calling, CrmModule.leadManagement},
          permissions: {CrmPermissions.callingUse, CrmPermissions.leadUpdate},
        );

        final cubit = LeadCallHistoryCubit(
          user: userWithoutViewPerm,
          leadId: testLead.id,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          callActivityRepository: callRepo,
        );

        await cubit.loadHistory();

        expect(cubit.state, isA<LeadCallHistoryAccessDenied>());
        expect(callRepo.getActivitiesCallCount, 0);
      },
    );

    test(
      'cross-assignee lead -> AccessDenied, 0 getActivities calls',
      () async {
        final cubit = LeadCallHistoryCubit(
          user: authorizedUser,
          leadId: crossLead.id,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          callActivityRepository: callRepo,
        );

        await cubit.loadHistory();

        expect(cubit.state, isA<LeadCallHistoryAccessDenied>());
        expect(callRepo.getActivitiesCallCount, 0);
      },
    );

    test('missing user link -> AccessDenied, 0 getActivities calls', () async {
      final emptyLinkRepo = MockUserLeadLinkRepository(links: {});
      final cubit = LeadCallHistoryCubit(
        user: authorizedUser,
        leadId: testLead.id,
        linkRepository: emptyLinkRepo,
        leadRepository: leadRepo,
        callActivityRepository: callRepo,
      );

      await cubit.loadHistory();

      expect(cubit.state, isA<LeadCallHistoryAccessDenied>());
      expect(callRepo.getActivitiesCallCount, 0);
    });
  });

  group('LeadCallHistoryCubit - Loading, Empty, Loaded, and Failure', () {
    test('authorized user with 0 activities emits Empty state', () async {
      final cubit = LeadCallHistoryCubit(
        user: authorizedUser,
        leadId: testLead.id,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        callActivityRepository: callRepo,
      );

      await cubit.loadHistory();

      expect(cubit.state, isA<LeadCallHistoryEmpty>());
      expect(callRepo.getActivitiesCallCount, 1);
    });

    test(
      'authorized user with activities emits Loaded state with activities',
      () async {
        final activity = LeadCallActivity(
          id: 'call-act-1',
          leadId: testLead.id,
          performedByUserId: 'usr-standard-1',
          outcome: CallOutcome.followUp,
          rescheduleAt: DateTime(2026, 9, 23, 14, 30),
          createdAt: DateTime(2026, 9, 21, 11, 0),
        );
        callRepo.seededActivities[testLead.id] = [activity];

        final cubit = LeadCallHistoryCubit(
          user: authorizedUser,
          leadId: testLead.id,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          callActivityRepository: callRepo,
        );

        await cubit.loadHistory();

        expect(cubit.state, isA<LeadCallHistoryLoaded>());
        final loaded = cubit.state as LeadCallHistoryLoaded;
        expect(loaded.activities.length, 1);
        expect(loaded.activities.first.id, 'call-act-1');
        expect(loaded.activities.first.outcome, CallOutcome.followUp);
      },
    );

    test('repository exception emits safe Failure state', () async {
      callRepo.shouldThrow = true;

      final cubit = LeadCallHistoryCubit(
        user: authorizedUser,
        leadId: testLead.id,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        callActivityRepository: callRepo,
      );

      await cubit.loadHistory();

      expect(cubit.state, isA<LeadCallHistoryFailure>());
      final failure = cubit.state as LeadCallHistoryFailure;
      expect(failure.message, 'Unable to load call history.');
    });
  });
}

class _SpyCallHistoryRepository implements LeadCallActivityRepository {
  int getActivitiesCallCount = 0;
  bool shouldThrow = false;
  final Map<String, List<LeadCallActivity>> seededActivities = {};

  @override
  Future<List<LeadCallActivity>> getActivitiesForLead(String leadId) async {
    getActivitiesCallCount++;
    if (shouldThrow) {
      throw Exception('Database read error');
    }
    return seededActivities[leadId] ?? [];
  }

  @override
  Future<LeadCallActivity> recordActivity({
    required String leadId,
    required String performedByUserId,
    required CallOutcome outcome,
    DateTime? rescheduleAt,
  }) => throw UnimplementedError();
}
