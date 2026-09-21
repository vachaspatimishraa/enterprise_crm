import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/calling/domain/policies/user_calling_policy.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const authorizedUser = CurrentUser(
    id: 'usr-1',
    displayName: 'Caller One',
    accountType: AccountType.user,
    modules: {CrmModule.calling, CrmModule.leadManagement},
    permissions: {CrmPermissions.callingUse, CrmPermissions.leadViewAssigned},
  );

  const userWithUpdateAlso = CurrentUser(
    id: 'usr-1',
    displayName: 'Caller One',
    accountType: AccountType.user,
    modules: {CrmModule.calling, CrmModule.leadManagement},
    permissions: {
      CrmPermissions.callingUse,
      CrmPermissions.leadViewAssigned,
      CrmPermissions.leadUpdate,
    },
  );

  const adminUser = CurrentUser(
    id: 'admin-1',
    displayName: 'Admin User',
    accountType: AccountType.admin,
    modules: {CrmModule.calling, CrmModule.leadManagement},
    permissions: {CrmPermissions.callingUse, CrmPermissions.leadViewAssigned},
  );

  final ownLead = Lead(
    id: 'lead-1',
    name: 'Aarav Sharma',
    phone: '+91 9876543210',
    email: 'aarav@example.com',
    status: const LeadStatus('Contacted'),
    source: LeadSource.manual,
    assignedUserId: 'agent-1',
    assignedUserName: 'Sarah Jenkins',
    createdAt: DateTime(2025, 1, 1),
  );

  final crossAssigneeLead = Lead(
    id: 'lead-2',
    name: 'Bob Smith',
    status: const LeadStatus('New'),
    source: LeadSource.excel,
    assignedUserId: 'agent-2',
    createdAt: DateTime(2025, 1, 1),
  );

  final unassignedLead = Lead(
    id: 'lead-3',
    name: 'Charlie Brown',
    status: const LeadStatus('New'),
    source: LeadSource.csv,
    createdAt: DateTime(2025, 1, 1),
  );

  group('UserCallingPolicy - canUseCalling', () {
    test('true when user has calling module and calling.use permission', () {
      expect(UserCallingPolicy.canUseCalling(authorizedUser), isTrue);
    });

    test('false when user lacks calling.use permission', () {
      const user = CurrentUser(
        id: 'usr-1',
        displayName: 'Caller',
        accountType: AccountType.user,
        modules: {CrmModule.calling},
        permissions: {},
      );
      expect(UserCallingPolicy.canUseCalling(user), isFalse);
    });

    test('false when user lacks calling module', () {
      const user = CurrentUser(
        id: 'usr-1',
        displayName: 'Caller',
        accountType: AccountType.user,
        modules: {CrmModule.leadManagement},
        permissions: {CrmPermissions.callingUse},
      );
      expect(UserCallingPolicy.canUseCalling(user), isFalse);
    });

    test('false for admin user (admin has separate workflow)', () {
      expect(UserCallingPolicy.canUseCalling(adminUser), isFalse);
    });
  });

  group(
    'UserCallingPolicy - canRecordActivityForLead & Independence from lead.update',
    () {
      test(
        'true on own lead when user has calling.use and lead.view_assigned (without lead.update)',
        () {
          expect(
            UserCallingPolicy.canRecordActivityForLead(
              user: authorizedUser,
              lead: ownLead,
              linkedAssigneeId: 'agent-1',
            ),
            isTrue,
          );
        },
      );

      test('true on own lead when user also has lead.update', () {
        expect(
          UserCallingPolicy.canRecordActivityForLead(
            user: userWithUpdateAlso,
            lead: ownLead,
            linkedAssigneeId: 'agent-1',
          ),
          isTrue,
        );
      });

      test('false when user lacks Calling module', () {
        const user = CurrentUser(
          id: 'usr-1',
          displayName: 'Caller',
          accountType: AccountType.user,
          modules: {CrmModule.leadManagement},
          permissions: {
            CrmPermissions.callingUse,
            CrmPermissions.leadViewAssigned,
          },
        );
        expect(
          UserCallingPolicy.canRecordActivityForLead(
            user: user,
            lead: ownLead,
            linkedAssigneeId: 'agent-1',
          ),
          isFalse,
        );
      });

      test('false when user lacks calling.use permission', () {
        const user = CurrentUser(
          id: 'usr-1',
          displayName: 'Caller',
          accountType: AccountType.user,
          modules: {CrmModule.calling, CrmModule.leadManagement},
          permissions: {CrmPermissions.leadViewAssigned},
        );
        expect(
          UserCallingPolicy.canRecordActivityForLead(
            user: user,
            lead: ownLead,
            linkedAssigneeId: 'agent-1',
          ),
          isFalse,
        );
      });

      test('false when user lacks Lead Management module', () {
        const user = CurrentUser(
          id: 'usr-1',
          displayName: 'Caller',
          accountType: AccountType.user,
          modules: {CrmModule.calling},
          permissions: {
            CrmPermissions.callingUse,
            CrmPermissions.leadViewAssigned,
          },
        );
        expect(
          UserCallingPolicy.canRecordActivityForLead(
            user: user,
            lead: ownLead,
            linkedAssigneeId: 'agent-1',
          ),
          isFalse,
        );
      });

      test('false when user lacks lead.view_assigned permission', () {
        const user = CurrentUser(
          id: 'usr-1',
          displayName: 'Caller',
          accountType: AccountType.user,
          modules: {CrmModule.calling, CrmModule.leadManagement},
          permissions: {CrmPermissions.callingUse, CrmPermissions.leadUpdate},
        );
        expect(
          UserCallingPolicy.canRecordActivityForLead(
            user: user,
            lead: ownLead,
            linkedAssigneeId: 'agent-1',
          ),
          isFalse,
        );
      });

      test('false on cross-assignee lead', () {
        expect(
          UserCallingPolicy.canRecordActivityForLead(
            user: authorizedUser,
            lead: crossAssigneeLead,
            linkedAssigneeId: 'agent-1',
          ),
          isFalse,
        );
      });

      test('false on unassigned lead', () {
        expect(
          UserCallingPolicy.canRecordActivityForLead(
            user: authorizedUser,
            lead: unassignedLead,
            linkedAssigneeId: 'agent-1',
          ),
          isFalse,
        );
      });

      test('false when linkedAssigneeId is null or empty', () {
        expect(
          UserCallingPolicy.canRecordActivityForLead(
            user: authorizedUser,
            lead: ownLead,
            linkedAssigneeId: null,
          ),
          isFalse,
        );
        expect(
          UserCallingPolicy.canRecordActivityForLead(
            user: authorizedUser,
            lead: ownLead,
            linkedAssigneeId: '   ',
          ),
          isFalse,
        );
      });

      test('false for admin user', () {
        expect(
          UserCallingPolicy.canRecordActivityForLead(
            user: adminUser,
            lead: ownLead,
            linkedAssigneeId: 'agent-1',
          ),
          isFalse,
        );
      });
    },
  );

  group('UserCallingPolicy - canViewLeadHistory', () {
    test('mirrors canRecordActivityForLead security gates', () {
      expect(
        UserCallingPolicy.canViewLeadHistory(
          user: authorizedUser,
          lead: ownLead,
          linkedAssigneeId: 'agent-1',
        ),
        isTrue,
      );
      expect(
        UserCallingPolicy.canViewLeadHistory(
          user: authorizedUser,
          lead: crossAssigneeLead,
          linkedAssigneeId: 'agent-1',
        ),
        isFalse,
      );
    });
  });
}
