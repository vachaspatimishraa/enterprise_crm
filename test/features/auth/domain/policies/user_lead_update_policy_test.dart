import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/domain/policies/user_lead_update_policy.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserLeadUpdatePolicy', () {
    const userViewOnly = CurrentUser(
      id: 'usr_standard',
      displayName: 'Standard User',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement},
      permissions: {CrmPermissions.leadViewAssigned},
    );

    const userBothPerms = CurrentUser(
      id: 'usr_standard',
      displayName: 'Standard User',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement},
      permissions: {CrmPermissions.leadViewAssigned, CrmPermissions.leadUpdate},
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

    final leadAssignedAgent1 = Lead(
      id: 'lead-1',
      name: 'Alice',
      phone: '1234567890',
      email: 'alice@example.com',
      status: const LeadStatus('New'),
      source: LeadSource.manual,
      assignedUserId: 'agent-1',
      assignedUserName: 'Agent One',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final leadAssignedAgent2 = Lead(
      id: 'lead-2',
      name: 'Bob',
      phone: '9876543210',
      email: 'bob@example.com',
      status: const LeadStatus('In Progress'),
      source: LeadSource.csv,
      assignedUserId: 'agent-2',
      assignedUserName: 'Agent Two',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final leadUnassigned = Lead(
      id: 'lead-3',
      name: 'Charlie',
      source: LeadSource.excel,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    group('canViewAssignedLeads', () {
      test('true when user has lead module and lead.view_assigned', () {
        expect(UserLeadUpdatePolicy.canViewAssignedLeads(userViewOnly), isTrue);
        expect(
          UserLeadUpdatePolicy.canViewAssignedLeads(userBothPerms),
          isTrue,
        );
      });

      test('false when user lacks lead.view_assigned', () {
        expect(
          UserLeadUpdatePolicy.canViewAssignedLeads(userUpdateOnly),
          isFalse,
        );
      });

      test('false when user lacks lead module', () {
        expect(
          UserLeadUpdatePolicy.canViewAssignedLeads(userNoLeadModule),
          isFalse,
        );
      });
    });

    group('canEditAssignedLeads', () {
      test(
        'true when user has lead module, lead.view_assigned, and lead.update',
        () {
          expect(
            UserLeadUpdatePolicy.canEditAssignedLeads(userBothPerms),
            isTrue,
          );
        },
      );

      test('false when user has view only (no lead.update)', () {
        expect(
          UserLeadUpdatePolicy.canEditAssignedLeads(userViewOnly),
          isFalse,
        );
      });

      test('false when user has update only without view permission', () {
        expect(
          UserLeadUpdatePolicy.canEditAssignedLeads(userUpdateOnly),
          isFalse,
        );
      });

      test('false when user lacks lead module', () {
        expect(
          UserLeadUpdatePolicy.canEditAssignedLeads(userNoLeadModule),
          isFalse,
        );
      });
    });

    group('canViewLead', () {
      test('true on own lead when user has view permission and valid link', () {
        expect(
          UserLeadUpdatePolicy.canViewLead(
            user: userViewOnly,
            lead: leadAssignedAgent1,
            linkedAssigneeId: 'agent-1',
          ),
          isTrue,
        );
      });

      test('false on cross-assignee lead', () {
        expect(
          UserLeadUpdatePolicy.canViewLead(
            user: userBothPerms,
            lead: leadAssignedAgent2,
            linkedAssigneeId: 'agent-1',
          ),
          isFalse,
        );
      });

      test('false on unassigned lead', () {
        expect(
          UserLeadUpdatePolicy.canViewLead(
            user: userBothPerms,
            lead: leadUnassigned,
            linkedAssigneeId: 'agent-1',
          ),
          isFalse,
        );
      });

      test('false when linkedAssigneeId is null or empty', () {
        expect(
          UserLeadUpdatePolicy.canViewLead(
            user: userBothPerms,
            lead: leadAssignedAgent1,
            linkedAssigneeId: null,
          ),
          isFalse,
        );
        expect(
          UserLeadUpdatePolicy.canViewLead(
            user: userBothPerms,
            lead: leadAssignedAgent1,
            linkedAssigneeId: '',
          ),
          isFalse,
        );
      });
    });

    group('canEditLead', () {
      test('true on own lead when user has view+update and matching link', () {
        expect(
          UserLeadUpdatePolicy.canEditLead(
            user: userBothPerms,
            lead: leadAssignedAgent1,
            linkedAssigneeId: 'agent-1',
          ),
          isTrue,
        );
      });

      test('false on own lead when user has view only (no lead.update)', () {
        expect(
          UserLeadUpdatePolicy.canEditLead(
            user: userViewOnly,
            lead: leadAssignedAgent1,
            linkedAssigneeId: 'agent-1',
          ),
          isFalse,
        );
      });

      test('false on cross-assignee lead even with update permission', () {
        expect(
          UserLeadUpdatePolicy.canEditLead(
            user: userBothPerms,
            lead: leadAssignedAgent2,
            linkedAssigneeId: 'agent-1',
          ),
          isFalse,
        );
      });

      test('false on unassigned lead even with update permission', () {
        expect(
          UserLeadUpdatePolicy.canEditLead(
            user: userBothPerms,
            lead: leadUnassigned,
            linkedAssigneeId: 'agent-1',
          ),
          isFalse,
        );
      });

      test('false when link is null or empty', () {
        expect(
          UserLeadUpdatePolicy.canEditLead(
            user: userBothPerms,
            lead: leadAssignedAgent1,
            linkedAssigneeId: null,
          ),
          isFalse,
        );
      });
    });

    group('buildUserUpdateInput', () {
      test(
        'sanitizes name, phone, email and strictly preserves immutable fields',
        () {
          final input = UserLeadUpdatePolicy.buildUserUpdateInput(
            existing: leadAssignedAgent1,
            name: '  Alice Updated  ',
            phone: '  5551234  ',
            email: '  alice.new@example.com  ',
          );

          expect(input.leadId, 'lead-1');
          expect(input.draft.name, 'Alice Updated');
          expect(input.draft.phone, '5551234');
          expect(input.draft.email, 'alice.new@example.com');
          // Preserved immutable fields
          expect(input.draft.status, leadAssignedAgent1.status);
          expect(input.draft.source, leadAssignedAgent1.source);
        },
      );

      test('converts blank phone/email to null', () {
        final input = UserLeadUpdatePolicy.buildUserUpdateInput(
          existing: leadAssignedAgent1,
          name: 'Alice',
          phone: '   ',
          email: '',
        );

        expect(input.draft.name, 'Alice');
        expect(input.draft.phone, isNull);
        expect(input.draft.email, isNull);
      });
    });
  });
}
