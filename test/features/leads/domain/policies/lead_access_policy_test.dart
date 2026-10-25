import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/leads/domain/policies/lead_access_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadAccessPolicy Tests', () {
    const adminUser = CurrentUser(
      id: 'admin_1',
      displayName: 'Admin User',
      accountType: AccountType.admin,
      modules: {CrmModule.leadManagement},
      permissions: {},
    );

    const leadUserAllPerms = CurrentUser(
      id: 'user_1',
      displayName: 'Lead Manager',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement},
      permissions: {
        CrmPermissions.leadView,
        CrmPermissions.leadViewAssigned,
        CrmPermissions.leadCreate,
        CrmPermissions.leadEdit,
        CrmPermissions.leadUpdate,
        CrmPermissions.leadDelete,
        CrmPermissions.leadAssign,
        CrmPermissions.leadImportCsv,
        CrmPermissions.leadImportXlsx,
        CrmPermissions.leadExportCsv,
        CrmPermissions.leadExportXlsx,
      },
    );

    const leadUserViewOnly = CurrentUser(
      id: 'user_2',
      displayName: 'View Only User',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement},
      permissions: {CrmPermissions.leadView},
    );

    const leadUserAssignedOnly = CurrentUser(
      id: 'user_3',
      displayName: 'Assigned Only User',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement},
      permissions: {CrmPermissions.leadViewAssigned},
    );

    const otherModuleUser = CurrentUser(
      id: 'user_4',
      displayName: 'Calling User',
      accountType: AccountType.user,
      modules: {CrmModule.calling},
      permissions: {CrmPermissions.callingUse},
    );

    test('Administrator has full access across all operations', () {
      expect(LeadAccessPolicy.canView(adminUser), isTrue);
      expect(LeadAccessPolicy.canViewAll(adminUser), isTrue);
      expect(LeadAccessPolicy.canViewAssigned(adminUser), isTrue);
      expect(LeadAccessPolicy.canCreate(adminUser), isTrue);
      expect(LeadAccessPolicy.canEdit(adminUser), isTrue);
      expect(LeadAccessPolicy.canDelete(adminUser), isTrue);
      expect(LeadAccessPolicy.canAssign(adminUser), isTrue);
      expect(LeadAccessPolicy.canImport(adminUser), isTrue);
      expect(LeadAccessPolicy.canImportCsv(adminUser), isTrue);
      expect(LeadAccessPolicy.canImportXlsx(adminUser), isTrue);
      expect(LeadAccessPolicy.canExport(adminUser), isTrue);
      expect(LeadAccessPolicy.canExportCsv(adminUser), isTrue);
      expect(LeadAccessPolicy.canExportXlsx(adminUser), isTrue);
    });

    test('User without leadManagement module has zero access', () {
      expect(LeadAccessPolicy.canView(otherModuleUser), isFalse);
      expect(LeadAccessPolicy.canViewAll(otherModuleUser), isFalse);
      expect(LeadAccessPolicy.canViewAssigned(otherModuleUser), isFalse);
      expect(LeadAccessPolicy.canCreate(otherModuleUser), isFalse);
      expect(LeadAccessPolicy.canEdit(otherModuleUser), isFalse);
      expect(LeadAccessPolicy.canDelete(otherModuleUser), isFalse);
      expect(LeadAccessPolicy.canAssign(otherModuleUser), isFalse);
      expect(LeadAccessPolicy.canImport(otherModuleUser), isFalse);
      expect(LeadAccessPolicy.canExport(otherModuleUser), isFalse);
    });

    test('User with all permissions can perform all lead operations', () {
      expect(LeadAccessPolicy.canView(leadUserAllPerms), isTrue);
      expect(LeadAccessPolicy.canViewAll(leadUserAllPerms), isTrue);
      expect(LeadAccessPolicy.canViewAssigned(leadUserAllPerms), isTrue);
      expect(LeadAccessPolicy.canCreate(leadUserAllPerms), isTrue);
      expect(LeadAccessPolicy.canEdit(leadUserAllPerms), isTrue);
      expect(LeadAccessPolicy.canDelete(leadUserAllPerms), isTrue);
      expect(LeadAccessPolicy.canAssign(leadUserAllPerms), isTrue);
      expect(LeadAccessPolicy.canImport(leadUserAllPerms), isTrue);
      expect(LeadAccessPolicy.canImportCsv(leadUserAllPerms), isTrue);
      expect(LeadAccessPolicy.canImportXlsx(leadUserAllPerms), isTrue);
      expect(LeadAccessPolicy.canExport(leadUserAllPerms), isTrue);
      expect(LeadAccessPolicy.canExportCsv(leadUserAllPerms), isTrue);
      expect(LeadAccessPolicy.canExportXlsx(leadUserAllPerms), isTrue);
    });

    test('canViewAll vs canViewAssigned distinction', () {
      expect(LeadAccessPolicy.canViewAll(leadUserViewOnly), isTrue);
      expect(LeadAccessPolicy.canViewAssigned(leadUserViewOnly), isFalse);

      expect(LeadAccessPolicy.canViewAll(leadUserAssignedOnly), isFalse);
      expect(LeadAccessPolicy.canViewAssigned(leadUserAssignedOnly), isTrue);
    });

    test('canEdit accepts either leadEdit or leadUpdate', () {
      const userWithEdit = CurrentUser(
        id: 'u_edit',
        displayName: 'Edit User',
        accountType: AccountType.user,
        modules: {CrmModule.leadManagement},
        permissions: {CrmPermissions.leadView, CrmPermissions.leadEdit},
      );
      const userWithUpdate = CurrentUser(
        id: 'u_update',
        displayName: 'Update User',
        accountType: AccountType.user,
        modules: {CrmModule.leadManagement},
        permissions: {CrmPermissions.leadView, CrmPermissions.leadUpdate},
      );

      expect(LeadAccessPolicy.canEdit(userWithEdit), isTrue);
      expect(LeadAccessPolicy.canEdit(userWithUpdate), isTrue);
      expect(LeadAccessPolicy.canEdit(leadUserViewOnly), isFalse);
    });

    test('granular delete, assign, import, export permissions', () {
      const userCustom = CurrentUser(
        id: 'u_custom',
        displayName: 'Custom User',
        accountType: AccountType.user,
        modules: {CrmModule.leadManagement},
        permissions: {
          CrmPermissions.leadView,
          CrmPermissions.leadDelete,
          CrmPermissions.leadImportCsv,
          CrmPermissions.leadExportXlsx,
        },
      );

      expect(LeadAccessPolicy.canDelete(userCustom), isTrue);
      expect(LeadAccessPolicy.canAssign(userCustom), isFalse);
      expect(LeadAccessPolicy.canImportCsv(userCustom), isTrue);
      expect(LeadAccessPolicy.canImportXlsx(userCustom), isFalse);
      expect(LeadAccessPolicy.canImport(userCustom), isTrue);
      expect(LeadAccessPolicy.canExportCsv(userCustom), isFalse);
      expect(LeadAccessPolicy.canExportXlsx(userCustom), isTrue);
      expect(LeadAccessPolicy.canExport(userCustom), isTrue);
    });
  });
}
