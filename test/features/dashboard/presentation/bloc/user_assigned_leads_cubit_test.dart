import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/entities/user_lead_link.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/domain/repositories/user_lead_link_repository.dart';
import 'package:enterprise_crm/features/dashboard/presentation/bloc/user_assigned_leads_cubit.dart';
import 'package:enterprise_crm/features/dashboard/presentation/bloc/user_assigned_leads_state.dart';
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
import 'package:flutter_test/flutter_test.dart';

// ── Spy / stub helpers ────────────────────────────────────────────────────

class _SpyLinkRepository implements UserLeadLinkRepository {
  int callCount = 0;
  final UserLeadLink? _link;

  _SpyLinkRepository([this._link]);

  @override
  Future<UserLeadLink?> getLinkForUser(String crmUserId) async {
    callCount++;
    return _link;
  }
}

class _SpyLeadRepository implements LeadRepository {
  int getLeadsCalls = 0;
  int getAssignableUsersCalls = 0;
  final List<Lead> _leads;
  final List<LeadAssignee> _assignees;

  _SpyLeadRepository({
    List<Lead>? leads,
    List<LeadAssignee>? assignees,
  })  : _leads = leads ?? [],
        _assignees = assignees ??
            const [LeadAssignee(id: 'agent-1', displayName: 'Mock Agent One')];

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async {
    getLeadsCalls++;
    final filtered = query.assignedUserId == null
        ? _leads
        : _leads.where((l) => l.assignedUserId == query.assignedUserId).toList();
    return LeadPage(
      items: filtered,
      currentPage: 1,
      pageSize: 20,
      totalItems: filtered.length,
      hasNext: false,
    );
  }

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async {
    getAssignableUsersCalls++;
    return _assignees;
  }

  // ── Unused stubs ─────────────────────────────────────────────────────
  @override
  Future<Lead?> getLeadById(String id) async => null;
  @override
  Future<Lead> createLead(CreateLeadInput input) => throw UnimplementedError();
  @override
  Future<Lead> updateLead(UpdateLeadInput input) => throw UnimplementedError();
  @override
  Future<void> assignLead({required String leadId, required String assigneeId}) async {}
  @override
  Future<void> assignLeads(LeadAssignmentRequest request) async {}
  @override
  Future<void> reassignLead(LeadReassignmentRequest request) async {}
  @override
  Future<LeadImportResult> importLeads(LeadImportRequest request) => throw UnimplementedError();
  @override
  Future<LeadExportResult> exportLeads(LeadExportRequest request) => throw UnimplementedError();
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

// ── Users ─────────────────────────────────────────────────────────────────

const _userWithNoModule = CurrentUser(
  id: 'usr_hr',
  displayName: 'HR User',
  accountType: AccountType.user,
  modules: {CrmModule.hrPayroll},
  permissions: {CrmPermissions.hrView},
);

const _userWithModuleNoViewPerm = CurrentUser(
  id: 'usr_noperm',
  displayName: 'No Perm',
  accountType: AccountType.user,
  modules: {CrmModule.leadManagement},
  permissions: {CrmPermissions.leadUpdate}, // update but NOT view_assigned
);

const _userWithView = CurrentUser(
  id: 'usr_standard',
  displayName: 'Standard User',
  accountType: AccountType.user,
  modules: {CrmModule.leadManagement},
  permissions: {CrmPermissions.leadViewAssigned, CrmPermissions.leadUpdate},
);

const _validLink = UserLeadLink(
  crmUserId: 'usr_standard',
  leadAssigneeId: 'agent-1',
);

Lead _lead(String id, String assigneeId) => Lead(
      id: id,
      name: 'Lead $id',
      source: LeadSource.manual,
      assignedUserId: assigneeId,
      assignedUserName: 'Agent',
    );

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  group('UserAssignedLeadsCubit — authorization order', () {
    test(
      'Step 1: no Lead module → linkRepo = 0 calls, leadRepo.getLeads = 0 calls',
      () async {
        final linkSpy = _SpyLinkRepository();
        final leadSpy = _SpyLeadRepository();

        final cubit = UserAssignedLeadsCubit(
          user: _userWithNoModule,
          linkRepository: linkSpy,
          leadRepository: leadSpy,
        );
        await cubit.load();

        expect(cubit.state, isA<UserAssignedLeadsFailure>());
        expect(linkSpy.callCount, 0);
        expect(leadSpy.getLeadsCalls, 0);
        expect(leadSpy.getAssignableUsersCalls, 0);
        cubit.close();
      },
    );

    test(
      'Step 2: Lead module but no lead.view_assigned → linkRepo = 0 calls, leadRepo.getLeads = 0 calls',
      () async {
        final linkSpy = _SpyLinkRepository();
        final leadSpy = _SpyLeadRepository();

        final cubit = UserAssignedLeadsCubit(
          user: _userWithModuleNoViewPerm,
          linkRepository: linkSpy,
          leadRepository: leadSpy,
        );
        await cubit.load();

        expect(cubit.state, isA<UserAssignedLeadsFailure>());
        expect(linkSpy.callCount, 0);
        expect(leadSpy.getLeadsCalls, 0);
        cubit.close();
      },
    );

    test(
      'Step 3: valid permission but no link → leadRepo.getLeads = 0 calls',
      () async {
        final linkSpy = _SpyLinkRepository(null); // returns null
        final leadSpy = _SpyLeadRepository();

        final cubit = UserAssignedLeadsCubit(
          user: _userWithView,
          linkRepository: linkSpy,
          leadRepository: leadSpy,
        );
        await cubit.load();

        expect(cubit.state, isA<UserAssignedLeadsNoLink>());
        expect(linkSpy.callCount, 1);
        expect(leadSpy.getLeadsCalls, 0);
        cubit.close();
      },
    );

    test(
      'Step 4: link exists but assignee not in getAssignableUsers() → leadRepo.getLeads = 0 calls',
      () async {
        final linkSpy = _SpyLinkRepository(_validLink);
        // Assignees list does NOT contain agent-1
        final leadSpy = _SpyLeadRepository(
          assignees: [const LeadAssignee(id: 'agent-99', displayName: 'Other')],
        );

        final cubit = UserAssignedLeadsCubit(
          user: _userWithView,
          linkRepository: linkSpy,
          leadRepository: leadSpy,
        );
        await cubit.load();

        expect(cubit.state, isA<UserAssignedLeadsInvalidLink>());
        expect(
          (cubit.state as UserAssignedLeadsInvalidLink).leadAssigneeId,
          'agent-1',
        );
        expect(leadSpy.getAssignableUsersCalls, 1);
        expect(leadSpy.getLeadsCalls, 0);
        cubit.close();
      },
    );

    test(
      'Step 5: valid link + valid assignee → getLeads called with mandatory assignedUserId scope',
      () async {
        final linkSpy = _SpyLinkRepository(_validLink);
        final leadSpy = _SpyLeadRepository(
          leads: [_lead('lead-1', 'agent-1'), _lead('lead-2', 'agent-2')],
        );

        final cubit = UserAssignedLeadsCubit(
          user: _userWithView,
          linkRepository: linkSpy,
          leadRepository: leadSpy,
        );
        await cubit.load();

        final state = cubit.state;
        expect(state, isA<UserAssignedLeadsLoaded>());
        final loaded = state as UserAssignedLeadsLoaded;
        // Only agent-1 leads returned — cross-assignee filtered
        expect(loaded.leads.length, 1);
        expect(loaded.leads.first.id, 'lead-1');
        expect(loaded.leadAssigneeId, 'agent-1');
        expect(leadSpy.getLeadsCalls, 1);
        cubit.close();
      },
    );
  });

  group('UserAssignedLeadsCubit — terminal states', () {
    test('no-link state emitted when link is null', () async {
      final cubit = UserAssignedLeadsCubit(
        user: _userWithView,
        linkRepository: _SpyLinkRepository(null),
        leadRepository: _SpyLeadRepository(),
      );
      await cubit.load();
      expect(cubit.state, const UserAssignedLeadsNoLink());
      cubit.close();
    });

    test('invalid-link state emitted for stale mapping', () async {
      final cubit = UserAssignedLeadsCubit(
        user: _userWithView,
        linkRepository: _SpyLinkRepository(_validLink),
        leadRepository: _SpyLeadRepository(assignees: []),
      );
      await cubit.load();
      expect(cubit.state, const UserAssignedLeadsInvalidLink('agent-1'));
      cubit.close();
    });

    test('empty state emitted when assignee has zero leads', () async {
      final cubit = UserAssignedLeadsCubit(
        user: _userWithView,
        linkRepository: _SpyLinkRepository(_validLink),
        leadRepository: _SpyLeadRepository(leads: []),
      );
      await cubit.load();
      expect(cubit.state, const UserAssignedLeadsEmpty('agent-1'));
      cubit.close();
    });

    test('loaded state contains only scoped leads', () async {
      final leads = [
        _lead('a1', 'agent-1'),
        _lead('a2', 'agent-1'),
        _lead('b1', 'agent-2'), // different assignee — should be excluded
      ];
      final cubit = UserAssignedLeadsCubit(
        user: _userWithView,
        linkRepository: _SpyLinkRepository(_validLink),
        leadRepository: _SpyLeadRepository(leads: leads),
      );
      await cubit.load();

      final state = cubit.state as UserAssignedLeadsLoaded;
      expect(state.leads.map((l) => l.id), containsAll(['a1', 'a2']));
      expect(state.leads.any((l) => l.id == 'b1'), isFalse);
      cubit.close();
    });

    test('retry re-runs the pipeline', () async {
      int loadCount = 0;
      final linkSpy = _SpyLinkRepository(null);
      final leadSpy = _SpyLeadRepository();
      // Wrap link repo to count loads
      final cubit = UserAssignedLeadsCubit(
        user: _userWithView,
        linkRepository: linkSpy,
        leadRepository: leadSpy,
      );
      await cubit.load();
      loadCount = linkSpy.callCount;
      await cubit.retry();
      expect(linkSpy.callCount, loadCount + 1);
      cubit.close();
    });

    test('initial state is UserAssignedLeadsLoading', () {
      final cubit = UserAssignedLeadsCubit(
        user: _userWithView,
        linkRepository: _SpyLinkRepository(),
        leadRepository: _SpyLeadRepository(),
      );
      expect(cubit.state, isA<UserAssignedLeadsLoading>());
      cubit.close();
    });
  });
}
