import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/domain/entities/call_outcome.dart';
import 'package:enterprise_crm/features/calling/domain/entities/follow_up_timing.dart';
import 'package:enterprise_crm/features/calling/domain/entities/lead_call_activity.dart';
import 'package:enterprise_crm/features/calling/presentation/bloc/calling_dashboard_cubit.dart';
import 'package:enterprise_crm/features/calling/presentation/bloc/calling_dashboard_state.dart';
import 'package:enterprise_crm/features/calling/presentation/models/follow_up_queue_item.dart';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignee.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class SpyLeadRepository extends MockLeadRepository {
  int getLeadsCallCount = 0;
  int getAssignableUsersCallCount = 0;

  SpyLeadRepository({super.dataSource});

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) {
    getLeadsCallCount++;
    return super.getLeads(query);
  }

  @override
  Future<List<LeadAssignee>> getAssignableUsers() {
    getAssignableUsersCallCount++;
    return super.getAssignableUsers();
  }
}

class SpyCallActivityRepository extends MockLeadCallActivityRepository {
  int getScheduledCallCount = 0;

  SpyCallActivityRepository({super.now, super.initialActivities});

  @override
  Future<List<LeadCallActivity>> getScheduledActivitiesForLeadIds(
    Set<String> leadIds,
  ) {
    getScheduledCallCount++;
    return super.getScheduledActivitiesForLeadIds(leadIds);
  }
}

void main() {
  final fixedNow = DateTime(2026, 9, 21, 10, 0, 0);

  const authorizedUser = CurrentUser(
    id: 'usr-agent-1',
    displayName: 'Agent One User',
    accountType: AccountType.user,
    modules: {CrmModule.calling, CrmModule.leadManagement},
    permissions: {CrmPermissions.callingUse, CrmPermissions.leadViewAssigned},
  );

  const leadOnlyUser = CurrentUser(
    id: 'usr-agent-1',
    displayName: 'Agent One User',
    accountType: AccountType.user,
    modules: {CrmModule.leadManagement},
    permissions: {CrmPermissions.leadViewAssigned},
  );

  const callingOnlyUser = CurrentUser(
    id: 'usr-agent-1',
    displayName: 'Agent One User',
    accountType: AccountType.user,
    modules: {CrmModule.calling},
    permissions: {CrmPermissions.callingUse},
  );

  final leadA = Lead(
    id: 'lead-A',
    name: 'Aarav Sharma',
    phone: '+91 9876543210',
    email: 'aarav@example.com',
    status: const LeadStatus('Contacted'),
    source: LeadSource.manual,
    assignedUserId: 'agent-1',
    assignedUserName: 'Agent One',
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );

  final leadB = Lead(
    id: 'lead-B',
    name: 'Vikram Joshi',
    phone: '+91 9876500000',
    email: 'vikram@example.com',
    status: const LeadStatus('Contacted'),
    source: LeadSource.manual,
    assignedUserId: 'agent-2',
    assignedUserName: 'Agent Two',
    createdAt: DateTime(2026, 9, 2),
    updatedAt: DateTime(2026, 9, 2),
  );

  late SpyLeadRepository leadRepo;
  late MockUserLeadLinkRepository linkRepo;
  late SpyCallActivityRepository callRepo;

  setUp(() {
    leadRepo = SpyLeadRepository(
      dataSource: MockLeadDataSource(initialLeads: [leadA, leadB]),
    );
    linkRepo = MockUserLeadLinkRepository(links: {'usr-agent-1': 'agent-1'});
    callRepo = SpyCallActivityRepository(now: () => fixedNow);
  });

  group('CallingDashboardCubit - Security Gates & Zero-Call Guarantees', () {
    test(
      'missing Calling module/permission emits Failure with 0 downstream queries',
      () async {
        final cubit = CallingDashboardCubit(
          user: leadOnlyUser,
          leadRepository: leadRepo,
          linkRepository: linkRepo,
          callActivityRepository: callRepo,
          now: () => fixedNow,
        );

        await cubit.load();

        expect(cubit.state, isA<CallingDashboardFailure>());
        expect(leadRepo.getLeadsCallCount, 0);
        expect(leadRepo.getAssignableUsersCallCount, 0);
        expect(callRepo.getScheduledCallCount, 0);
      },
    );

    test(
      'missing Lead view access emits CallingDashboardNoLeadAccess with 0 Lead/Activity reads',
      () async {
        final cubit = CallingDashboardCubit(
          user: callingOnlyUser,
          leadRepository: leadRepo,
          linkRepository: linkRepo,
          callActivityRepository: callRepo,
          now: () => fixedNow,
        );

        await cubit.load();

        expect(cubit.state, const CallingDashboardNoLeadAccess());
        expect(leadRepo.getLeadsCallCount, 0);
        expect(leadRepo.getAssignableUsersCallCount, 0);
        expect(callRepo.getScheduledCallCount, 0);
      },
    );

    test(
      'missing user-assignee link emits CallingDashboardNoLink with 0 Activity reads',
      () async {
        final emptyLinkRepo = MockUserLeadLinkRepository();
        final cubit = CallingDashboardCubit(
          user: authorizedUser,
          leadRepository: leadRepo,
          linkRepository: emptyLinkRepo,
          callActivityRepository: callRepo,
          now: () => fixedNow,
        );

        await cubit.load();

        expect(cubit.state, const CallingDashboardNoLink());
        expect(leadRepo.getLeadsCallCount, 0);
        expect(callRepo.getScheduledCallCount, 0);
      },
    );

    test(
      'invalid assignee link emits CallingDashboardInvalidLink with 0 Activity reads',
      () async {
        final invalidLinkRepo = MockUserLeadLinkRepository(
          links: {'usr-agent-1': 'non-existent-agent'},
        );

        final cubit = CallingDashboardCubit(
          user: authorizedUser,
          leadRepository: leadRepo,
          linkRepository: invalidLinkRepo,
          callActivityRepository: callRepo,
          now: () => fixedNow,
        );

        await cubit.load();

        expect(cubit.state, const CallingDashboardInvalidLink());
        expect(leadRepo.getLeadsCallCount, 0);
        expect(callRepo.getScheduledCallCount, 0);
      },
    );

    test(
      'authorized user with 0 assigned leads emits CallingDashboardEmpty with 0 Activity reads',
      () async {
        final emptyLeadsRepo = SpyLeadRepository(
          dataSource: MockLeadDataSource(
            initialLeads: [leadB],
          ), // only agent-2 leads
        );

        final cubit = CallingDashboardCubit(
          user: authorizedUser,
          leadRepository: emptyLeadsRepo,
          linkRepository: linkRepo,
          callActivityRepository: callRepo,
          now: () => fixedNow,
        );

        await cubit.load();

        expect(cubit.state, const CallingDashboardEmpty());
        expect(emptyLeadsRepo.getLeadsCallCount, 1);
        expect(callRepo.getScheduledCallCount, 0);
      },
    );
  });

  group('CallingDashboardCubit - Scoping, Actor Independence & Reassignment', () {
    test(
      'strictly scopes queue to currently owned Leads (Lead A yes, Lead B no)',
      () async {
        // Record scheduled activity for Lead A (owned by agent-1)
        await callRepo.recordActivity(
          leadId: 'lead-A',
          performedByUserId: 'usr-agent-1',
          outcome: CallOutcome.followUp,
          rescheduleAt: DateTime(2026, 9, 22, 10, 0),
        );

        // Record scheduled activity for Lead B (owned by agent-2)
        await callRepo.recordActivity(
          leadId: 'lead-B',
          performedByUserId: 'usr-agent-2',
          outcome: CallOutcome.visitScheduled,
          rescheduleAt: DateTime(2026, 9, 23, 10, 0),
        );

        final cubit = CallingDashboardCubit(
          user: authorizedUser,
          leadRepository: leadRepo,
          linkRepository: linkRepo,
          callActivityRepository: callRepo,
          now: () => fixedNow,
        );

        await cubit.load();

        expect(cubit.state, isA<CallingDashboardLoaded>());
        final loaded = cubit.state as CallingDashboardLoaded;
        expect(loaded.allItems.length, 1);
        expect(loaded.allItems.first.lead.id, 'lead-A');
        expect(loaded.allItems.first.activity.outcome, CallOutcome.followUp);
      },
    );

    test(
      'ACTOR INDEPENDENCE: activity performed by user on unowned Lead does NOT appear',
      () async {
        // User usr-agent-1 previously recorded activity on Lead B (which is currently assigned to agent-2)
        await callRepo.recordActivity(
          leadId: 'lead-B',
          performedByUserId: 'usr-agent-1', // actor is usr-agent-1
          outcome: CallOutcome.followUp,
          rescheduleAt: DateTime(2026, 9, 22, 10, 0),
        );

        final cubit = CallingDashboardCubit(
          user: authorizedUser,
          leadRepository: leadRepo,
          linkRepository: linkRepo,
          callActivityRepository: callRepo,
          now: () => fixedNow,
        );

        await cubit.load();

        // Must be empty because usr-agent-1 currently owns 0 activities for lead-A
        expect(cubit.state, const CallingDashboardEmpty());
      },
    );

    test(
      'REASSIGNMENT: reassigned lead disappears from previous owner upon refresh',
      () async {
        await callRepo.recordActivity(
          leadId: 'lead-A',
          performedByUserId: 'usr-agent-1',
          outcome: CallOutcome.followUp,
          rescheduleAt: DateTime(2026, 9, 22, 10, 0),
        );

        final cubit = CallingDashboardCubit(
          user: authorizedUser,
          leadRepository: leadRepo,
          linkRepository: linkRepo,
          callActivityRepository: callRepo,
          now: () => fixedNow,
        );

        await cubit.load();
        expect(cubit.state, isA<CallingDashboardLoaded>());

        // Admin reassigns lead-A to agent-2
        await leadRepo.assignLead(leadId: 'lead-A', assigneeId: 'agent-2');

        // User refreshes dashboard
        await cubit.refresh();

        // Lead-A disappears from agent-1's queue
        expect(cubit.state, const CallingDashboardEmpty());
      },
    );

    test(
      'MULTIPLE ACTIVITIES: multiple scheduled activities for one Lead remain independent',
      () async {
        await callRepo.recordActivity(
          leadId: 'lead-A',
          performedByUserId: 'usr-agent-1',
          outcome: CallOutcome.notConnected,
          rescheduleAt: DateTime(2026, 9, 21, 14, 0),
        );
        await callRepo.recordActivity(
          leadId: 'lead-A',
          performedByUserId: 'usr-agent-1',
          outcome: CallOutcome.followUp,
          rescheduleAt: DateTime(2026, 9, 25, 11, 0),
        );

        final cubit = CallingDashboardCubit(
          user: authorizedUser,
          leadRepository: leadRepo,
          linkRepository: linkRepo,
          callActivityRepository: callRepo,
          now: () => fixedNow,
        );

        await cubit.load();

        expect(cubit.state, isA<CallingDashboardLoaded>());
        final loaded = cubit.state as CallingDashboardLoaded;
        expect(loaded.allItems.length, 2);
        expect(loaded.allItems[0].activity.outcome, CallOutcome.notConnected);
        expect(loaded.allItems[1].activity.outcome, CallOutcome.followUp);
      },
    );
  });

  group('CallingDashboardCubit - Metrics, Filtering & Local Search', () {
    setUp(() async {
      // Overdue: 20 Sep 16:00
      await callRepo.recordActivity(
        leadId: 'lead-A',
        performedByUserId: 'usr-agent-1',
        outcome: CallOutcome.notConnected,
        rescheduleAt: DateTime(2026, 9, 20, 16, 0),
      );
      // Due Today: 21 Sep 15:30
      await callRepo.recordActivity(
        leadId: 'lead-A',
        performedByUserId: 'usr-agent-1',
        outcome: CallOutcome.followUp,
        rescheduleAt: DateTime(2026, 9, 21, 15, 30),
      );
      // Upcoming: 22 Sep 10:00
      await callRepo.recordActivity(
        leadId: 'lead-A',
        performedByUserId: 'usr-agent-1',
        outcome: CallOutcome.visitScheduled,
        rescheduleAt: DateTime(2026, 9, 22, 10, 0),
      );
    });

    test(
      'derives accurate full-queue summary metrics (Overdue: 1, Due Today: 1, Upcoming: 1)',
      () async {
        final cubit = CallingDashboardCubit(
          user: authorizedUser,
          leadRepository: leadRepo,
          linkRepository: linkRepo,
          callActivityRepository: callRepo,
          now: () => fixedNow,
        );

        await cubit.load();

        expect(cubit.state, isA<CallingDashboardLoaded>());
        final loaded = cubit.state as CallingDashboardLoaded;
        expect(loaded.overdueCount, 1);
        expect(loaded.dueTodayCount, 1);
        expect(loaded.upcomingCount, 1);
        expect(loaded.allItems.length, 3);
        expect(loaded.visibleItems.length, 3);
      },
    );

    test(
      'timing filters update visibleItems without altering summary counts',
      () async {
        final cubit = CallingDashboardCubit(
          user: authorizedUser,
          leadRepository: leadRepo,
          linkRepository: linkRepo,
          callActivityRepository: callRepo,
          now: () => fixedNow,
        );

        await cubit.load();

        // Filter Overdue
        cubit.setFilter(FollowUpTimingFilter.overdue);
        var state = cubit.state as CallingDashboardLoaded;
        expect(state.visibleItems.length, 1);
        expect(state.visibleItems.first.timing, FollowUpTiming.overdue);
        expect(state.overdueCount, 1);
        expect(state.dueTodayCount, 1);
        expect(state.upcomingCount, 1);

        // Filter Due Today
        cubit.setFilter(FollowUpTimingFilter.dueToday);
        state = cubit.state as CallingDashboardLoaded;
        expect(state.visibleItems.length, 1);
        expect(state.visibleItems.first.timing, FollowUpTiming.dueToday);
        expect(state.dueTodayCount, 1);

        // Filter Upcoming
        cubit.setFilter(FollowUpTimingFilter.upcoming);
        state = cubit.state as CallingDashboardLoaded;
        expect(state.visibleItems.length, 1);
        expect(state.visibleItems.first.timing, FollowUpTiming.upcoming);
        expect(state.upcomingCount, 1);

        // Back to All
        cubit.setFilter(FollowUpTimingFilter.all);
        state = cubit.state as CallingDashboardLoaded;
        expect(state.visibleItems.length, 3);
      },
    );

    test(
      'local search filters by lead name, phone, or email without backend calls',
      () async {
        final cubit = CallingDashboardCubit(
          user: authorizedUser,
          leadRepository: leadRepo,
          linkRepository: linkRepo,
          callActivityRepository: callRepo,
          now: () => fixedNow,
        );

        await cubit.load();
        final initialLeadsCalls = leadRepo.getLeadsCallCount;

        // Search by name substring
        cubit.setSearchQuery('Aarav');
        var state = cubit.state as CallingDashboardLoaded;
        expect(state.visibleItems.length, 3);
        expect(
          leadRepo.getLeadsCallCount,
          initialLeadsCalls,
        ); // 0 additional backend queries

        // Search non-matching
        cubit.setSearchQuery('NonExistent');
        state = cubit.state as CallingDashboardLoaded;
        expect(state.visibleItems, isEmpty);
        expect(state.overdueCount, 1); // summary metrics retained
        expect(state.dueTodayCount, 1);
        expect(state.upcomingCount, 1);

        // Search by phone substring
        cubit.setSearchQuery('987654');
        state = cubit.state as CallingDashboardLoaded;
        expect(state.visibleItems.length, 3);

        // Search by email substring
        cubit.setSearchQuery('aarav@example.com');
        state = cubit.state as CallingDashboardLoaded;
        expect(state.visibleItems.length, 3);
      },
    );
  });

  group('CallingDashboardCubit - Pagination Deduplication & Failure / Retry', () {
    test('deduplicates overlapping paginated Leads by Lead.id', () async {
      // Mock repository that returns leadA on page 1 and ALSO leadA on page 2
      final duplicatePagingRepo = DuplicatePagingLeadRepository(leadA);

      await callRepo.recordActivity(
        leadId: 'lead-A',
        performedByUserId: 'usr-agent-1',
        outcome: CallOutcome.followUp,
        rescheduleAt: DateTime(2026, 9, 22, 10, 0),
      );

      final cubit = CallingDashboardCubit(
        user: authorizedUser,
        leadRepository: duplicatePagingRepo,
        linkRepository: linkRepo,
        callActivityRepository: callRepo,
        now: () => fixedNow,
      );

      await cubit.load();

      expect(cubit.state, isA<CallingDashboardLoaded>());
      final loaded = cubit.state as CallingDashboardLoaded;
      // Exactly 1 queue item, not 2
      expect(loaded.allItems.length, 1);
      expect(loaded.allItems.first.lead.id, 'lead-A');
    });

    test(
      'failure on repository error emits Failure; retry successfully re-executes',
      () async {
        final failingRepo = FailingLeadRepository(
          delegate: leadRepo,
          shouldFail: true,
        );

        final cubit = CallingDashboardCubit(
          user: authorizedUser,
          leadRepository: failingRepo,
          linkRepository: linkRepo,
          callActivityRepository: callRepo,
          now: () => fixedNow,
        );

        await cubit.load();
        expect(cubit.state, isA<CallingDashboardFailure>());

        // Fix failure and retry
        failingRepo.shouldFail = false;
        await cubit.retry();

        expect(cubit.state, isA<CallingDashboardEmpty>());
      },
    );
  });
}

class DuplicatePagingLeadRepository extends MockLeadRepository {
  final Lead lead;

  DuplicatePagingLeadRepository(this.lead);

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async {
    return [const LeadAssignee(id: 'agent-1', displayName: 'Agent One')];
  }

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async {
    if (query.page == 1) {
      return LeadPage(
        items: [lead],
        currentPage: 1,
        pageSize: 1,
        totalItems: 1,
        hasNext: true, // triggers page 2
      );
    }
    return LeadPage(
      items: [lead], // returns leadA again on page 2!
      currentPage: 2,
      pageSize: 1,
      totalItems: 1,
      hasNext: false,
    );
  }
}

class FailingLeadRepository extends MockLeadRepository {
  final LeadRepository delegate;
  bool shouldFail;

  FailingLeadRepository({required this.delegate, required this.shouldFail});

  @override
  Future<List<LeadAssignee>> getAssignableUsers() {
    if (shouldFail) {
      throw Exception('Database connection dropped');
    }
    return delegate.getAssignableUsers();
  }

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) {
    if (shouldFail) {
      throw Exception('Query timeout');
    }
    return delegate.getLeads(query);
  }
}
