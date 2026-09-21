import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/entities/user_lead_link.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/domain/repositories/user_lead_link_repository.dart';
import 'package:enterprise_crm/features/dashboard/presentation/bloc/user_lead_edit_cubit.dart';
import 'package:enterprise_crm/features/dashboard/presentation/bloc/user_lead_edit_state.dart';
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
  UserLeadLink? link;
  _SpyLinkRepo([this.link]);

  @override
  Future<UserLeadLink?> getLinkForUser(String crmUserId) async {
    callCount++;
    return link;
  }
}

class _SpyLeadRepo implements LeadRepository {
  int getLeadByIdCalls = 0;
  int updateLeadCalls = 0;
  UpdateLeadInput? lastUpdateInput;
  bool throwOnUpdate = false;

  final Map<String, Lead> leads;
  final List<LeadAssignee> assignees;

  _SpyLeadRepo({Map<String, Lead>? leads, List<LeadAssignee>? assignees})
    : leads = leads ?? {},
      assignees =
          assignees ??
          const [
            LeadAssignee(id: 'agent-1', displayName: 'Mock Agent One'),
            LeadAssignee(id: 'agent-2', displayName: 'Mock Agent Two'),
          ];

  @override
  Future<Lead?> getLeadById(String leadId) async {
    getLeadByIdCalls++;
    return leads[leadId];
  }

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async => assignees;

  @override
  Future<Lead> updateLead(UpdateLeadInput input) async {
    updateLeadCalls++;
    lastUpdateInput = input;
    if (throwOnUpdate) {
      throw Exception('DB timeout');
    }
    final existing = leads[input.leadId]!;
    final updated = existing.copyWith(
      name: input.draft.name ?? existing.name,
      phone: input.draft.phone ?? existing.phone,
      email: input.draft.email ?? existing.email,
      status: input.draft.status ?? existing.status,
      source: input.draft.source ?? existing.source,
      updatedAt: DateTime.now(),
    );
    leads[input.leadId] = updated;
    return updated;
  }

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

void main() {
  group('UserLeadEditCubit', () {
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

    const userUpdateOnly = CurrentUser(
      id: 'usr_standard',
      displayName: 'Standard User',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement},
      permissions: {CrmPermissions.leadUpdate},
    );

    const userNoLeadModule = CurrentUser(
      id: 'usr_standard',
      displayName: 'Standard User',
      accountType: AccountType.user,
      modules: {CrmModule.calling},
      permissions: {CrmPermissions.leadViewAssigned, CrmPermissions.leadUpdate},
    );

    final leadAgent1 = Lead(
      id: 'lead-1',
      name: 'Original Name',
      phone: '1234567890',
      email: 'original@example.com',
      status: const LeadStatus('New'),
      source: LeadSource.manual,
      assignedUserId: 'agent-1',
      assignedUserName: 'Mock Agent One',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final leadAgent2 = Lead(
      id: 'lead-2',
      name: 'Agent 2 Lead',
      source: LeadSource.csv,
      assignedUserId: 'agent-2',
      assignedUserName: 'Mock Agent Two',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final leadUnassigned = Lead(
      id: 'lead-3',
      name: 'Unassigned Lead',
      source: LeadSource.excel,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    test('module denied -> AccessDenied, 0 updateLead calls', () async {
      final linkRepo = _SpyLinkRepo();
      final leadRepo = _SpyLeadRepo();
      final cubit = UserLeadEditCubit(
        user: userNoLeadModule,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        leadId: 'lead-1',
      );

      await cubit.load();

      expect(cubit.state, isA<UserLeadEditAccessDenied>());
      expect(leadRepo.updateLeadCalls, 0);
    });

    test(
      'view permission missing -> AccessDenied, 0 updateLead calls',
      () async {
        final linkRepo = _SpyLinkRepo();
        final leadRepo = _SpyLeadRepo();
        final cubit = UserLeadEditCubit(
          user: userUpdateOnly,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          leadId: 'lead-1',
        );

        await cubit.load();

        expect(cubit.state, isA<UserLeadEditAccessDenied>());
        expect(leadRepo.updateLeadCalls, 0);
      },
    );

    test(
      'update permission missing -> AccessDenied, 0 updateLead calls',
      () async {
        final linkRepo = _SpyLinkRepo(
          const UserLeadLink(
            crmUserId: 'usr_standard',
            leadAssigneeId: 'agent-1',
          ),
        );
        final leadRepo = _SpyLeadRepo(leads: {'lead-1': leadAgent1});
        final cubit = UserLeadEditCubit(
          user: userViewOnly,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          leadId: 'lead-1',
        );

        await cubit.load();

        expect(cubit.state, isA<UserLeadEditAccessDenied>());
        expect(leadRepo.updateLeadCalls, 0);
      },
    );

    test('cross-assignee lead -> AccessDenied, 0 updateLead calls', () async {
      final linkRepo = _SpyLinkRepo(
        const UserLeadLink(
          crmUserId: 'usr_standard',
          leadAssigneeId: 'agent-1',
        ),
      );
      final leadRepo = _SpyLeadRepo(leads: {'lead-2': leadAgent2});
      final cubit = UserLeadEditCubit(
        user: userBothPerms,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        leadId: 'lead-2',
      );

      await cubit.load();

      expect(cubit.state, isA<UserLeadEditAccessDenied>());
      expect(leadRepo.updateLeadCalls, 0);
    });

    test('unassigned lead -> AccessDenied, 0 updateLead calls', () async {
      final linkRepo = _SpyLinkRepo(
        const UserLeadLink(
          crmUserId: 'usr_standard',
          leadAssigneeId: 'agent-1',
        ),
      );
      final leadRepo = _SpyLeadRepo(leads: {'lead-3': leadUnassigned});
      final cubit = UserLeadEditCubit(
        user: userBothPerms,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        leadId: 'lead-3',
      );

      await cubit.load();

      expect(cubit.state, isA<UserLeadEditAccessDenied>());
      expect(leadRepo.updateLeadCalls, 0);
    });

    test(
      'fresh re-fetch check: lead reassigned by Admin while form open blocks update',
      () async {
        final linkRepo = _SpyLinkRepo(
          const UserLeadLink(
            crmUserId: 'usr_standard',
            leadAssigneeId: 'agent-1',
          ),
        );
        final leadRepo = _SpyLeadRepo(leads: {'lead-1': leadAgent1});
        final cubit = UserLeadEditCubit(
          user: userBothPerms,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          leadId: 'lead-1',
        );

        await cubit.load();
        expect(cubit.state, isA<UserLeadEditReady>());

        // Admin reassigns lead to agent-2 in the repository
        leadRepo.leads['lead-1'] = leadAgent1.copyWith(
          assignedUserId: 'agent-2',
          assignedUserName: 'Mock Agent Two',
        );

        // User attempts to save
        await cubit.submitUpdate(
          name: 'Malicious Change',
          phone: '999',
          email: 'mal@test.com',
        );

        // Ownership mismatch caught by fresh getLeadById check!
        expect(cubit.state, isA<UserLeadEditAccessDenied>());
        expect(leadRepo.updateLeadCalls, 0);
      },
    );

    test(
      'valid update mutates safe fields and preserves immutable fields',
      () async {
        final linkRepo = _SpyLinkRepo(
          const UserLeadLink(
            crmUserId: 'usr_standard',
            leadAssigneeId: 'agent-1',
          ),
        );
        final leadRepo = _SpyLeadRepo(leads: {'lead-1': leadAgent1});
        final cubit = UserLeadEditCubit(
          user: userBothPerms,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          leadId: 'lead-1',
        );

        await cubit.load();
        expect(cubit.state, isA<UserLeadEditReady>());

        await cubit.submitUpdate(
          name: 'Alice Cooper',
          phone: '+1 555-0199',
          email: 'alice.c@example.com',
        );

        expect(cubit.state, isA<UserLeadEditSuccess>());
        final success = cubit.state as UserLeadEditSuccess;
        expect(success.updatedLead.name, 'Alice Cooper');
        expect(success.updatedLead.phone, '+1 555-0199');
        expect(success.updatedLead.email, 'alice.c@example.com');
        // Immutable fields intact
        expect(success.updatedLead.id, 'lead-1');
        expect(success.updatedLead.assignedUserId, 'agent-1');
        expect(success.updatedLead.source, LeadSource.manual);
        expect(success.updatedLead.status, const LeadStatus('New'));

        expect(leadRepo.updateLeadCalls, 1);
      },
    );

    test('double submit in flight performs only 1 repository update', () async {
      final linkRepo = _SpyLinkRepo(
        const UserLeadLink(
          crmUserId: 'usr_standard',
          leadAssigneeId: 'agent-1',
        ),
      );
      final leadRepo = _SpyLeadRepo(leads: {'lead-1': leadAgent1});
      final cubit = UserLeadEditCubit(
        user: userBothPerms,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        leadId: 'lead-1',
      );

      await cubit.load();

      // Submit multiple times concurrently
      final f1 = cubit.submitUpdate(name: 'A', phone: null, email: null);
      final f2 = cubit.submitUpdate(name: 'B', phone: null, email: null);
      await Future.wait([f1, f2]);

      expect(leadRepo.updateLeadCalls, 1);
    });

    test('failure handles error with safe message and allows retry', () async {
      final linkRepo = _SpyLinkRepo(
        const UserLeadLink(
          crmUserId: 'usr_standard',
          leadAssigneeId: 'agent-1',
        ),
      );
      final leadRepo = _SpyLeadRepo(leads: {'lead-1': leadAgent1});
      leadRepo.throwOnUpdate = true;

      final cubit = UserLeadEditCubit(
        user: userBothPerms,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        leadId: 'lead-1',
      );

      await cubit.load();
      await cubit.submitUpdate(name: 'Fail Attempt', phone: null, email: null);

      expect(cubit.state, isA<UserLeadEditFailure>());
      final failure = cubit.state as UserLeadEditFailure;
      expect(failure.message, 'Unable to update lead.');

      // Retry after resolving backend error
      leadRepo.throwOnUpdate = false;
      await cubit.submitUpdate(name: 'Success Retry', phone: null, email: null);

      expect(cubit.state, isA<UserLeadEditSuccess>());
      expect(leadRepo.updateLeadCalls, 2);
    });
  });
}
