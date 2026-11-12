import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_crm/app/bootstrap/mock_crm_dependencies.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/user_account_status.dart';
import 'package:enterprise_crm/features/user_management/domain/inputs/create_managed_user_input.dart';

void main() {
  group('Mock CRM Dependencies - Lead Assignment & Permissions Wiring', () {
    test(
      'getAssignableUsers removes default mock agents when permissioned users exist',
      () async {
        final deps = createMockCrmDependencies();

        final assignees = await deps.leadRepository.getAssignableUsers();
        final ids = assignees.map((a) => a.id).toSet();
        final names = assignees.map((a) => a.displayName).toSet();

        // Hardcoded mock fallback users must be excluded when real permissioned users exist.
        expect(ids, isNot(contains('agent-1')));
        expect(ids, isNot(contains('agent-2')));
        expect(ids, isNot(contains('agent-3')));
        expect(names, isNot(contains('Mock Agent One')));

        // Seeded active admin ('admin') and lead-permissioned user ('user') must appear.
        expect(ids, contains('admin'));
        expect(ids, contains('user'));

        // Non-lead-module and disabled seeded users must be excluded.
        expect(ids, isNot(contains('hr_user')));
        expect(ids, isNot(contains('inventory_user')));
        expect(ids, isNot(contains('disabled_user')));
      },
    );

    test(
      'newly created active Lead-permissioned user appears in getAssignableUsers and link resolution, and disappears if disabled',
      () async {
        final deps = createMockCrmDependencies();

        final createdUser = await deps.userManagementRepository.createUser(
          CreateManagedUserInput(
            userId: 'lead_manager_1',
            displayName: 'Lead Manager One',
            modules: {CrmModule.leadManagement},
            permissions: {
              CrmPermissions.leadCreate,
              CrmPermissions.leadAssign,
              CrmPermissions.leadViewAssigned,
            },
          ),
          temporaryPassword: 'TempPassword1!',
        );

        final assignees = await deps.leadRepository.getAssignableUsers();
        expect(
          assignees.any(
            (a) => a.id == 'lead_manager_1' && a.displayName == 'Lead Manager One',
          ),
          isTrue,
        );

        // UserLeadLinkRepository resolves both userId and internal managed id.
        expect(
          (await deps.userLeadLinkRepository.getLinkForUser(
            'lead_manager_1',
          ))?.leadAssigneeId,
          equals('lead_manager_1'),
        );
        expect(
          (await deps.userLeadLinkRepository.getLinkForUser(
            createdUser.id,
          ))?.leadAssigneeId,
          equals('lead_manager_1'),
        );

        // Assigning a newly created lead resolves the display name from permissioned users.
        final lead = await deps.leadRepository.createLead(
          const CreateLeadInput(
            draft: LeadDraft(name: 'Prospect Alpha', phone: '+919999888877'),
          ),
        );
        await deps.leadRepository.assignLead(
          leadId: lead.id,
          assigneeId: 'lead_manager_1',
        );
        final assigned = await deps.leadRepository.getLeadById(lead.id);
        expect(assigned, isNotNull);
        expect(assigned!.assignedUserId, equals('lead_manager_1'));
        expect(assigned.assignedUserName, equals('Lead Manager One'));

        final scoped = await deps.leadRepository.getLeads(
          const LeadQuery(assignedUserId: 'lead_manager_1'),
        );
        expect(scoped.items.map((l) => l.id), contains(lead.id));

        // Disabling the user excludes them from assignable users and link resolution.
        await deps.userManagementRepository.setUserStatus(
          id: createdUser.id,
          status: UserAccountStatus.disabled,
        );
        final afterDisable = await deps.leadRepository.getAssignableUsers();
        expect(afterDisable.any((a) => a.id == 'lead_manager_1'), isFalse);
        expect(
          await deps.userLeadLinkRepository.getLinkForUser('lead_manager_1'),
          isNull,
        );
      },
    );

    test(
      'MockLeadRepository falls back to default mock assignees when assignableUsersProvider returns empty',
      () async {
        final repo = MockLeadRepository(
          assignableUsersProvider: () => const [],
        );

        final assignees = await repo.getAssignableUsers();
        expect(
          assignees.map((a) => a.id),
          containsAll(['agent-1', 'agent-2', 'agent-3']),
        );
      },
    );
  });
}
