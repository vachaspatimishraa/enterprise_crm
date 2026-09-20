import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
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
  });
}
