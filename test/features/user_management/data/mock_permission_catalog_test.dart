import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/user_management/data/mock/mock_permission_catalog.dart';
import 'package:enterprise_crm/features/user_management/domain/repositories/user_management_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockPermissionCatalog Tests', () {
    test(
      'isValidPermission correctly identifies known vs unknown permissions',
      () {
        expect(
          MockPermissionCatalog.isValidPermission('lead.view_assigned'),
          isTrue,
        );
        expect(MockPermissionCatalog.isValidPermission('lead.update'), isTrue);
        expect(MockPermissionCatalog.isValidPermission('calling.use'), isTrue);
        expect(MockPermissionCatalog.isValidPermission('hr.view'), isTrue);
        expect(MockPermissionCatalog.isValidPermission('payroll.view'), isTrue);
        expect(
          MockPermissionCatalog.isValidPermission('inventory.view'),
          isTrue,
        );
        expect(
          MockPermissionCatalog.isValidPermission('inventory.export.csv'),
          isTrue,
        );
        expect(
          MockPermissionCatalog.isValidPermission('inventory.export.xlsx'),
          isTrue,
        );
        expect(
          MockPermissionCatalog.isValidPermission('purchase.view'),
          isTrue,
        );
        expect(MockPermissionCatalog.isValidPermission('vendor.view'), isTrue);

        expect(
          MockPermissionCatalog.isValidPermission('unknown.perm'),
          isFalse,
        );
        expect(MockPermissionCatalog.isValidPermission('*'), isFalse);
      },
    );

    test('getModuleForPermission maps permissions to owning module', () {
      expect(
        MockPermissionCatalog.getModuleForPermission('lead.update'),
        CrmModule.leadManagement,
      );
      expect(
        MockPermissionCatalog.getModuleForPermission('calling.use'),
        CrmModule.calling,
      );
      expect(
        MockPermissionCatalog.getModuleForPermission('unknown.perm'),
        isNull,
      );
    });

    test(
      'filterPermissionsForModules retains only permissions belonging to modules',
      () {
        final input = {
          'lead.view_assigned',
          'lead.update',
          'calling.use',
          'hr.view',
        };

        final filtered = MockPermissionCatalog.filterPermissionsForModules(
          input,
          {CrmModule.leadManagement},
        );

        expect(filtered, {'lead.view_assigned', 'lead.update'});
        expect(filtered.contains('calling.use'), isFalse);
        expect(filtered.contains('hr.view'), isFalse);
      },
    );

    test(
      'validateForCreate allows valid permissions matching selected modules',
      () {
        expect(
          () => MockPermissionCatalog.validateForCreate(
            {'calling.use'},
            {CrmModule.calling},
          ),
          returnsNormally,
        );
      },
    );

    test('validateForCreate rejects unknown permission identifier', () {
      expect(
        () => MockPermissionCatalog.validateForCreate(
          {'fake.permission'},
          {CrmModule.leadManagement},
        ),
        throwsA(
          isA<UserManagementException>().having(
            (e) => e.message,
            'message',
            contains('Unknown permission'),
          ),
        ),
      );
    });

    test(
      'validateForCreate rejects orphan permission not in selected modules',
      () {
        expect(
          () => MockPermissionCatalog.validateForCreate(
            {'lead.update'},
            {CrmModule.calling}, // Module does not own lead.update
          ),
          throwsA(
            isA<UserManagementException>().having(
              (e) => e.message,
              'message',
              contains('does not belong to any selected module'),
            ),
          ),
        );
      },
    );

    test('validateAndPruneForUpdate prunes removed module permissions', () {
      final submitted = {'lead.view_assigned', 'lead.update', 'calling.use'};

      // Admin removes leadManagement, keeping only calling
      final pruned = MockPermissionCatalog.validateAndPruneForUpdate(
        submitted,
        {CrmModule.calling},
      );

      expect(pruned, {'calling.use'});
    });

    test('validateAndPruneForUpdate rejects unknown permission identifier', () {
      expect(
        () => MockPermissionCatalog.validateAndPruneForUpdate(
          {'nonexistent.permission'},
          {CrmModule.calling},
        ),
        throwsA(
          isA<UserManagementException>().having(
            (e) => e.message,
            'message',
            contains('Unknown permission'),
          ),
        ),
      );
    });
    test('inventory export permissions map to inventory module', () {
      expect(
        MockPermissionCatalog.getModuleForPermission('inventory.export.csv'),
        CrmModule.inventory,
      );
      expect(
        MockPermissionCatalog.getModuleForPermission('inventory.export.xlsx'),
        CrmModule.inventory,
      );
      final inventoryPerms = MockPermissionCatalog.getPermissionsForModule(
        CrmModule.inventory,
      );
      expect(inventoryPerms.contains('inventory.export.csv'), isTrue);
      expect(inventoryPerms.contains('inventory.export.xlsx'), isTrue);
      expect(inventoryPerms.contains('inventory.import.csv'), isTrue);
      expect(inventoryPerms.contains('inventory.import.xlsx'), isTrue);
    });

    test('purchase permissions map to purchase module', () {
      expect(
        MockPermissionCatalog.getModuleForPermission('purchase.create'),
        CrmModule.purchase,
      );
      expect(
        MockPermissionCatalog.getModuleForPermission('purchase.bill.download'),
        CrmModule.purchase,
      );
      final purchasePerms =
          MockPermissionCatalog.getPermissionsForModule(CrmModule.purchase);
      expect(purchasePerms.contains('purchase.view'), isTrue);
      expect(purchasePerms.contains('purchase.create'), isTrue);
      expect(purchasePerms.contains('purchase.approve'), isTrue);
      expect(purchasePerms.contains('purchase.receive_stock'), isTrue);
      expect(purchasePerms.contains('purchase.export.csv'), isTrue);
      expect(purchasePerms.contains('purchase.export.pdf'), isTrue);
      expect(purchasePerms.contains('purchase.bill.download'), isTrue);
    });

    test(
      'exposes every enterprise HR and payroll permission in user forms',
      () {
        final defined = MockPermissionCatalog.definitions
            .where((definition) => definition.module == CrmModule.hrPayroll)
            .map((definition) => definition.id)
            .toSet();

        expect(
          defined,
          containsAll(CrmPermissions.permissionsFor(CrmModule.hrPayroll)),
        );
        expect(defined, contains(CrmPermissions.hrDocumentsManage));
        expect(defined, contains(CrmPermissions.payrollRunApprove));
        expect(defined, contains(CrmPermissions.payrollPaymentRelease));
      },
    );

    test('lead permissions map to leadManagement module and user forms', () {
      expect(
        MockPermissionCatalog.getModuleForPermission(CrmPermissions.leadView),
        CrmModule.leadManagement,
      );
      expect(
        MockPermissionCatalog.getModuleForPermission(CrmPermissions.leadCreate),
        CrmModule.leadManagement,
      );
      expect(
        MockPermissionCatalog.getModuleForPermission(CrmPermissions.leadEdit),
        CrmModule.leadManagement,
      );
      expect(
        MockPermissionCatalog.getModuleForPermission(CrmPermissions.leadDelete),
        CrmModule.leadManagement,
      );
      expect(
        MockPermissionCatalog.getModuleForPermission(CrmPermissions.leadAssign),
        CrmModule.leadManagement,
      );
      expect(
        MockPermissionCatalog.getModuleForPermission(
          CrmPermissions.leadImportCsv,
        ),
        CrmModule.leadManagement,
      );
      expect(
        MockPermissionCatalog.getModuleForPermission(
          CrmPermissions.leadImportXlsx,
        ),
        CrmModule.leadManagement,
      );
      expect(
        MockPermissionCatalog.getModuleForPermission(
          CrmPermissions.leadExportCsv,
        ),
        CrmModule.leadManagement,
      );
      expect(
        MockPermissionCatalog.getModuleForPermission(
          CrmPermissions.leadExportXlsx,
        ),
        CrmModule.leadManagement,
      );

      final defined = MockPermissionCatalog.definitions
          .where((d) => d.module == CrmModule.leadManagement)
          .map((d) => d.id)
          .toSet();

      expect(
        defined,
        containsAll(CrmPermissions.permissionsFor(CrmModule.leadManagement)),
      );
      expect(defined.contains(CrmPermissions.leadView), isTrue);
      expect(defined.contains(CrmPermissions.leadViewAssigned), isTrue);
      expect(defined.contains(CrmPermissions.leadCreate), isTrue);
      expect(defined.contains(CrmPermissions.leadEdit), isTrue);
      expect(defined.contains(CrmPermissions.leadUpdate), isTrue);
      expect(defined.contains(CrmPermissions.leadDelete), isTrue);
      expect(defined.contains(CrmPermissions.leadAssign), isTrue);
      expect(defined.contains(CrmPermissions.leadImportCsv), isTrue);
      expect(defined.contains(CrmPermissions.leadImportXlsx), isTrue);
      expect(defined.contains(CrmPermissions.leadExportCsv), isTrue);
      expect(defined.contains(CrmPermissions.leadExportXlsx), isTrue);
    });
  });
}
