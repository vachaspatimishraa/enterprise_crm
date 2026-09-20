import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/access_policy.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/mappers/crm_permission_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrmPermissions & CrmPermissionPresentation', () {
    test('canonical permissions map to expected modules', () {
      expect(
        CrmPermissions.moduleFor(CrmPermissions.leadViewAssigned),
        CrmModule.leadManagement,
      );
      expect(
        CrmPermissions.moduleFor(CrmPermissions.leadUpdate),
        CrmModule.leadManagement,
      );
      expect(
        CrmPermissions.moduleFor(CrmPermissions.callingUse),
        CrmModule.calling,
      );
      expect(
        CrmPermissions.moduleFor(CrmPermissions.hrView),
        CrmModule.hrPayroll,
      );
      expect(
        CrmPermissions.moduleFor(CrmPermissions.payrollView),
        CrmModule.hrPayroll,
      );
      expect(
        CrmPermissions.moduleFor(CrmPermissions.inventoryView),
        CrmModule.inventory,
      );
      expect(
        CrmPermissions.moduleFor(CrmPermissions.purchaseView),
        CrmModule.purchase,
      );
      expect(
        CrmPermissions.moduleFor(CrmPermissions.vendorView),
        CrmModule.vendorManagement,
      );
    });

    test('isKnown validates known catalog and rejects arbitrary strings', () {
      expect(CrmPermissions.isKnown(CrmPermissions.leadViewAssigned), isTrue);
      expect(CrmPermissions.isKnown('lead.delete'), isFalse);
      expect(CrmPermissions.isKnown('*'), isFalse);
      expect(CrmPermissions.isKnown(''), isFalse);
    });

    test('permissionsFor returns correct sets per module', () {
      expect(CrmPermissions.permissionsFor(CrmModule.leadManagement), {
        CrmPermissions.leadViewAssigned,
        CrmPermissions.leadUpdate,
      });
      expect(CrmPermissions.permissionsFor(CrmModule.calling), {
        CrmPermissions.callingUse,
      });
      expect(CrmPermissions.permissionsFor(CrmModule.dispatch), isEmpty);
      expect(
        CrmPermissions.permissionsFor(CrmModule.approvalsNotifications),
        isEmpty,
      );
    });

    test('allKnown contains exactly 8 permissions', () {
      expect(CrmPermissions.allKnown.length, 8);
    });

    test('CrmPermissionPresentation returns human-readable labels', () {
      expect(
        CrmPermissionPresentation.displayNameFor(
          CrmPermissions.leadViewAssigned,
        ),
        'View assigned leads',
      );
      expect(
        CrmPermissionPresentation.displayNameFor(CrmPermissions.leadUpdate),
        'Update leads',
      );
      expect(
        CrmPermissionPresentation.displayNameFor(CrmPermissions.callingUse),
        'Use calling',
      );
      expect(
        CrmPermissionPresentation.displayNameFor('unknown.perm'),
        'unknown.perm',
      );
    });
  });

  group('AccessPolicy - canAccessModule', () {
    const admin = CurrentUser(
      id: 'usr_admin',
      displayName: 'Administrator',
      accountType: AccountType.admin,
      modules: {},
      permissions: {},
    );

    const normalUser = CurrentUser(
      id: 'usr_user',
      displayName: 'Standard User',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement, CrmModule.calling},
      permissions: {CrmPermissions.leadViewAssigned, CrmPermissions.callingUse},
    );

    test('Administrator can access every CrmModule unconditionally', () {
      for (final module in CrmModule.values) {
        expect(
          AccessPolicy.canAccessModule(admin, module),
          isTrue,
          reason: 'Admin should have access to ${module.name}',
        );
      }
    });

    test('Standard user can only access explicitly assigned modules', () {
      expect(
        AccessPolicy.canAccessModule(normalUser, CrmModule.leadManagement),
        isTrue,
      );
      expect(
        AccessPolicy.canAccessModule(normalUser, CrmModule.calling),
        isTrue,
      );
      expect(
        AccessPolicy.canAccessModule(normalUser, CrmModule.inventory),
        isFalse,
      );
      expect(
        AccessPolicy.canAccessModule(normalUser, CrmModule.hrPayroll),
        isFalse,
      );
      expect(
        AccessPolicy.canAccessModule(normalUser, CrmModule.purchase),
        isFalse,
      );
      expect(
        AccessPolicy.canAccessModule(normalUser, CrmModule.vendorManagement),
        isFalse,
      );
      expect(
        AccessPolicy.canAccessModule(normalUser, CrmModule.dispatch),
        isFalse,
      );
      expect(
        AccessPolicy.canAccessModule(
          normalUser,
          CrmModule.approvalsNotifications,
        ),
        isFalse,
      );
    });
  });

  group('AccessPolicy - hasPermission', () {
    const admin = CurrentUser(
      id: 'usr_admin',
      displayName: 'Administrator',
      accountType: AccountType.admin,
      modules: {},
      permissions: {}, // Empty permissions; admin bypass uses accountType
    );

    test('unknown permissions return false for all users including admin', () {
      expect(AccessPolicy.hasPermission(admin, 'unknown.perm'), isFalse);
      expect(AccessPolicy.hasPermission(admin, '*'), isFalse);
      expect(AccessPolicy.hasPermission(admin, 'lead.delete'), isFalse);
    });

    test('Admin has access to all recognized catalog permissions', () {
      for (final perm in CrmPermissions.allKnown) {
        expect(
          AccessPolicy.hasPermission(admin, perm),
          isTrue,
          reason: 'Admin should have known permission: $perm',
        );
      }
    });

    test(
      'Standard user with assigned module and permission has permission',
      () {
        const user = CurrentUser(
          id: 'usr_user',
          displayName: 'Standard User',
          accountType: AccountType.user,
          modules: {CrmModule.leadManagement},
          permissions: {CrmPermissions.leadViewAssigned},
        );

        expect(
          AccessPolicy.hasPermission(user, CrmPermissions.leadViewAssigned),
          isTrue,
        );
        expect(
          AccessPolicy.hasPermission(user, CrmPermissions.leadUpdate),
          isFalse,
        );
      },
    );

    test(
      'Standard user cannot access permission if module is NOT assigned (orphan defense)',
      () {
        // User somehow has 'inventory.view' in permissions set, but NOT CrmModule.inventory in modules
        const userWithOrphanPerm = CurrentUser(
          id: 'usr_user',
          displayName: 'Standard User',
          accountType: AccountType.user,
          modules: {CrmModule.leadManagement}, // inventory NOT assigned
          permissions: {
            CrmPermissions.leadViewAssigned,
            CrmPermissions.inventoryView, // orphan
          },
        );

        // Lead view is allowed because module is assigned
        expect(
          AccessPolicy.hasPermission(
            userWithOrphanPerm,
            CrmPermissions.leadViewAssigned,
          ),
          isTrue,
        );

        // Inventory view is DENIED because inventory module is not assigned
        expect(
          AccessPolicy.hasPermission(
            userWithOrphanPerm,
            CrmPermissions.inventoryView,
          ),
          isFalse,
        );
      },
    );

    test('Standard user with zero permissions has no permissions', () {
      const user = CurrentUser(
        id: 'usr_user',
        displayName: 'Standard User',
        accountType: AccountType.user,
        modules: {CrmModule.leadManagement},
        permissions: {},
      );

      expect(
        AccessPolicy.hasPermission(user, CrmPermissions.leadViewAssigned),
        isFalse,
      );
      expect(
        AccessPolicy.hasPermission(user, CrmPermissions.leadUpdate),
        isFalse,
      );
    });
  });
}
