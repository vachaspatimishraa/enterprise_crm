import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/entities/user_lead_link.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/domain/repositories/user_lead_link_repository.dart';
import 'package:enterprise_crm/features/dashboard/presentation/bloc/user_lead_details_cubit.dart';
import 'package:enterprise_crm/features/dashboard/presentation/bloc/user_lead_details_state.dart';
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

class _SpyLinkRepo implements UserLeadLinkRepository {
  int callCount = 0;
  final UserLeadLink? _link;
  _SpyLinkRepo([this._link]);

  @override
  Future<UserLeadLink?> getLinkForUser(String crmUserId) async {
    callCount++;
    return _link;
  }
}

class _SpyLeadRepo implements LeadRepository {
  int getLeadByIdCalls = 0;
  int getAssignableUsersCalls = 0;
  final Map<String, Lead> _leads;
  final List<LeadAssignee> _assignees;

  _SpyLeadRepo({Map<String, Lead>? leads, List<LeadAssignee>? assignees})
    : _leads = leads ?? {},
      _assignees =
          assignees ??
          const [LeadAssignee(id: 'agent-1', displayName: 'Mock Agent One')];

  @override
  Future<Lead?> getLeadById(String leadId) async {
    getLeadByIdCalls++;
    return _leads[leadId];
  }

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async {
    getAssignableUsersCalls++;
    return _assignees;
  }

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) =>
      throw UnimplementedError();

  @override
  Future<LeadSummary> getLeadSummary() => throw UnimplementedError();

  @override
  Future<Lead> createLead(CreateLeadInput input) => throw UnimplementedError();

  @override
  Future<Lead> updateLead(UpdateLeadInput input) => throw UnimplementedError();

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

void main() {
  group('UserLeadDetailsCubit', () {
    const userBothPerms = CurrentUser(
      id: 'usr_standard',
      displayName: 'Standard User',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement},
      permissions: {CrmPermissions.leadViewAssigned, CrmPermissions.leadUpdate},
    );

    const userViewOnly = CurrentUser(
      id: 'usr_standard',
      displayName: 'Standard User',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement},
      permissions: {CrmPermissions.leadViewAssigned},
    );

    const userNoLeadModule = CurrentUser(
      id: 'usr_standard',
      displayName: 'Standard User',
      accountType: AccountType.user,
      modules: {CrmModule.calling},
      permissions: {CrmPermissions.leadViewAssigned, CrmPermissions.leadUpdate},
    );

    const userNoViewPerm = CurrentUser(
      id: 'usr_standard',
      displayName: 'Standard User',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement},
      permissions: {CrmPermissions.leadUpdate},
    );

    final leadAgent1 = Lead(
      id: 'lead-1',
      name: 'Lead 1',
      status: const LeadStatus('New'),
      source: LeadSource.manual,
      assignedUserId: 'agent-1',
      assignedUserName: 'Mock Agent One',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final leadAgent2 = Lead(
      id: 'lead-2',
      name: 'Lead 2',
      status: const LeadStatus('New'),
      source: LeadSource.manual,
      assignedUserId: 'agent-2',
      assignedUserName: 'Mock Agent Two',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final leadUnassigned = Lead(
      id: 'lead-3',
      name: 'Lead 3',
      status: const LeadStatus('New'),
      source: LeadSource.manual,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    test('module denied -> AccessDenied, 0 link calls, 0 lead calls', () async {
      final linkRepo = _SpyLinkRepo();
      final leadRepo = _SpyLeadRepo();
      final cubit = UserLeadDetailsCubit(
        user: userNoLeadModule,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        leadId: 'lead-1',
      );

      await cubit.loadLead();

      expect(cubit.state, isA<UserLeadDetailsAccessDenied>());
      expect(linkRepo.callCount, 0);
      expect(leadRepo.getLeadByIdCalls, 0);
    });

    test(
      'no view permission -> AccessDenied, 0 link calls, 0 lead calls',
      () async {
        final linkRepo = _SpyLinkRepo();
        final leadRepo = _SpyLeadRepo();
        final cubit = UserLeadDetailsCubit(
          user: userNoViewPerm,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          leadId: 'lead-1',
        );

        await cubit.loadLead();

        expect(cubit.state, isA<UserLeadDetailsAccessDenied>());
        expect(linkRepo.callCount, 0);
        expect(leadRepo.getLeadByIdCalls, 0);
      },
    );

    test('no link -> AccessDenied, 0 getLeadById calls', () async {
      final linkRepo = _SpyLinkRepo(null);
      final leadRepo = _SpyLeadRepo();
      final cubit = UserLeadDetailsCubit(
        user: userBothPerms,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        leadId: 'lead-1',
      );

      await cubit.loadLead();

      expect(cubit.state, isA<UserLeadDetailsAccessDenied>());
      expect(linkRepo.callCount, 1);
      expect(leadRepo.getLeadByIdCalls, 0);
    });

    test('invalid link -> AccessDenied, 0 getLeadById calls', () async {
      final linkRepo = _SpyLinkRepo(
        const UserLeadLink(
          crmUserId: 'usr_standard',
          leadAssigneeId: 'nonexistent',
        ),
      );
      final leadRepo = _SpyLeadRepo();
      final cubit = UserLeadDetailsCubit(
        user: userBothPerms,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        leadId: 'lead-1',
      );

      await cubit.loadLead();

      expect(cubit.state, isA<UserLeadDetailsAccessDenied>());
      expect(leadRepo.getAssignableUsersCalls, 1);
      expect(leadRepo.getLeadByIdCalls, 0);
    });

    test('cross-assignee lead -> AccessDenied', () async {
      final linkRepo = _SpyLinkRepo(
        const UserLeadLink(
          crmUserId: 'usr_standard',
          leadAssigneeId: 'agent-1',
        ),
      );
      final leadRepo = _SpyLeadRepo(leads: {'lead-2': leadAgent2});
      final cubit = UserLeadDetailsCubit(
        user: userBothPerms,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        leadId: 'lead-2',
      );

      await cubit.loadLead();

      expect(cubit.state, isA<UserLeadDetailsAccessDenied>());
    });

    test('unassigned lead -> AccessDenied', () async {
      final linkRepo = _SpyLinkRepo(
        const UserLeadLink(
          crmUserId: 'usr_standard',
          leadAssigneeId: 'agent-1',
        ),
      );
      final leadRepo = _SpyLeadRepo(leads: {'lead-3': leadUnassigned});
      final cubit = UserLeadDetailsCubit(
        user: userBothPerms,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        leadId: 'lead-3',
      );

      await cubit.loadLead();

      expect(cubit.state, isA<UserLeadDetailsAccessDenied>());
    });

    test('own lead with view-only emits Loaded with canEdit: false', () async {
      final linkRepo = _SpyLinkRepo(
        const UserLeadLink(
          crmUserId: 'usr_standard',
          leadAssigneeId: 'agent-1',
        ),
      );
      final leadRepo = _SpyLeadRepo(leads: {'lead-1': leadAgent1});
      final cubit = UserLeadDetailsCubit(
        user: userViewOnly,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        leadId: 'lead-1',
      );

      await cubit.loadLead();

      expect(
        cubit.state,
        UserLeadDetailsLoaded(
          lead: leadAgent1,
          linkedAssigneeId: 'agent-1',
          canEdit: false,
        ),
      );
    });

    test('own lead with view+update emits Loaded with canEdit: true', () async {
      final linkRepo = _SpyLinkRepo(
        const UserLeadLink(
          crmUserId: 'usr_standard',
          leadAssigneeId: 'agent-1',
        ),
      );
      final leadRepo = _SpyLeadRepo(leads: {'lead-1': leadAgent1});
      final cubit = UserLeadDetailsCubit(
        user: userBothPerms,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        leadId: 'lead-1',
      );

      await cubit.loadLead();

      expect(
        cubit.state,
        UserLeadDetailsLoaded(
          lead: leadAgent1,
          linkedAssigneeId: 'agent-1',
          canEdit: true,
        ),
      );
    });

    test('refreshLead updates loaded lead state', () async {
      final linkRepo = _SpyLinkRepo(
        const UserLeadLink(
          crmUserId: 'usr_standard',
          leadAssigneeId: 'agent-1',
        ),
      );
      final leadRepo = _SpyLeadRepo(leads: {'lead-1': leadAgent1});
      final cubit = UserLeadDetailsCubit(
        user: userBothPerms,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        leadId: 'lead-1',
      );

      await cubit.loadLead();
      final updated = leadAgent1.copyWith(name: 'Updated Name');
      cubit.refreshLead(updated);

      final state = cubit.state as UserLeadDetailsLoaded;
      expect(state.lead.name, 'Updated Name');
      expect(state.canEdit, isTrue);
    });
  });
}
