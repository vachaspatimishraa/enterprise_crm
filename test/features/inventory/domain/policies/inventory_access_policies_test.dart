import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/domain/policies/inventory_deletion_policy.dart';
import 'package:enterprise_crm/features/inventory/domain/policies/inventory_import_policy.dart';
import 'package:enterprise_crm/features/inventory/domain/policies/inventory_item_administration_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('INVENTORY-ACCESS-1: Inventory Authorization Policies', () {
    const adminUser = CurrentUser(
      id: 'admin_1',
      displayName: 'System Admin',
      accountType: AccountType.admin,
      modules: {CrmModule.inventory},
      permissions: {},
    );

    const standardUserWithoutModule = CurrentUser(
      id: 'user_no_mod',
      displayName: 'No Module User',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement},
      permissions: {
        CrmPermissions.inventoryView,
        CrmPermissions.inventoryCreate,
        CrmPermissions.inventoryEdit,
        CrmPermissions.inventoryDelete,
      },
    );

    const standardUserWithoutView = CurrentUser(
      id: 'user_no_view',
      displayName: 'No View User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {
        CrmPermissions.inventoryCreate,
        CrmPermissions.inventoryEdit,
        CrmPermissions.inventoryDelete,
      },
    );

    const viewOnlyUser = CurrentUser(
      id: 'user_view_only',
      displayName: 'View Only User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {CrmPermissions.inventoryView},
    );

    const createOnlyUser = CurrentUser(
      id: 'user_create',
      displayName: 'Create User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {
        CrmPermissions.inventoryView,
        CrmPermissions.inventoryCreate,
      },
    );

    const editOnlyUser = CurrentUser(
      id: 'user_edit',
      displayName: 'Edit User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {CrmPermissions.inventoryView, CrmPermissions.inventoryEdit},
    );

    const deleteOnlyUser = CurrentUser(
      id: 'user_delete',
      displayName: 'Delete User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {
        CrmPermissions.inventoryView,
        CrmPermissions.inventoryDelete,
      },
    );

    const csvImportUser = CurrentUser(
      id: 'user_csv',
      displayName: 'CSV User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {
        CrmPermissions.inventoryView,
        CrmPermissions.inventoryImportCsv,
      },
    );

    const xlsxImportUser = CurrentUser(
      id: 'user_xlsx',
      displayName: 'XLSX User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {
        CrmPermissions.inventoryView,
        CrmPermissions.inventoryImportXlsx,
      },
    );

    group('Admin Full Access', () {
      test('Admin unconditionally has all Inventory capabilities', () {
        expect(InventoryItemAdministrationPolicy.canCreate(adminUser), isTrue);
        expect(InventoryItemAdministrationPolicy.canEdit(adminUser), isTrue);
        expect(InventoryItemAdministrationPolicy.canManage(adminUser), isTrue);
        expect(InventoryDeletionPolicy.canDelete(adminUser), isTrue);
        expect(
          InventoryDeletionPolicy.canUndo(
            adminUser,
            initiatedByUserId: 'other_user',
          ),
          isTrue,
        );
        expect(InventoryImportPolicy.canImport(adminUser), isTrue);
        expect(InventoryImportPolicy.canImportCsv(adminUser), isTrue);
        expect(InventoryImportPolicy.canImportXlsx(adminUser), isTrue);
      });
    });

    group('Standard User Without Module or Without View', () {
      test('Standard user without inventory module is denied all actions', () {
        expect(
          InventoryItemAdministrationPolicy.canCreate(
            standardUserWithoutModule,
          ),
          isFalse,
        );
        expect(
          InventoryItemAdministrationPolicy.canEdit(standardUserWithoutModule),
          isFalse,
        );
        expect(
          InventoryDeletionPolicy.canDelete(standardUserWithoutModule),
          isFalse,
        );
        expect(
          InventoryImportPolicy.canImportCsv(standardUserWithoutModule),
          isFalse,
        );
        expect(
          InventoryImportPolicy.canImportXlsx(standardUserWithoutModule),
          isFalse,
        );
      });

      test('Standard user without inventory.view is denied all actions', () {
        expect(
          InventoryItemAdministrationPolicy.canCreate(standardUserWithoutView),
          isFalse,
        );
        expect(
          InventoryItemAdministrationPolicy.canEdit(standardUserWithoutView),
          isFalse,
        );
        expect(
          InventoryDeletionPolicy.canDelete(standardUserWithoutView),
          isFalse,
        );
        expect(
          InventoryImportPolicy.canImportCsv(standardUserWithoutView),
          isFalse,
        );
        expect(
          InventoryImportPolicy.canImportXlsx(standardUserWithoutView),
          isFalse,
        );
      });
    });

    group('Granular Action Permissions', () {
      test(
        'View-only user has view but cannot create, edit, delete, or import',
        () {
          expect(
            InventoryItemAdministrationPolicy.canCreate(viewOnlyUser),
            isFalse,
          );
          expect(
            InventoryItemAdministrationPolicy.canEdit(viewOnlyUser),
            isFalse,
          );
          expect(InventoryDeletionPolicy.canDelete(viewOnlyUser), isFalse);
          expect(InventoryImportPolicy.canImportCsv(viewOnlyUser), isFalse);
          expect(InventoryImportPolicy.canImportXlsx(viewOnlyUser), isFalse);
        },
      );

      test(
        'Create-only user can create but cannot edit, delete, or import',
        () {
          expect(
            InventoryItemAdministrationPolicy.canCreate(createOnlyUser),
            isTrue,
          );
          expect(
            InventoryItemAdministrationPolicy.canEdit(createOnlyUser),
            isFalse,
          );
          expect(InventoryDeletionPolicy.canDelete(createOnlyUser), isFalse);
          expect(InventoryImportPolicy.canImport(createOnlyUser), isFalse);
        },
      );

      test('Edit-only user can edit but cannot create, delete, or import', () {
        expect(InventoryItemAdministrationPolicy.canEdit(editOnlyUser), isTrue);
        expect(
          InventoryItemAdministrationPolicy.canCreate(editOnlyUser),
          isFalse,
        );
        expect(InventoryDeletionPolicy.canDelete(editOnlyUser), isFalse);
      });

      test('Delete-only user can delete and undo their own deletion', () {
        expect(InventoryDeletionPolicy.canDelete(deleteOnlyUser), isTrue);
        expect(
          InventoryDeletionPolicy.canUndo(
            deleteOnlyUser,
            initiatedByUserId: deleteOnlyUser.id,
          ),
          isTrue,
        );
        // Cannot undo deletion initiated by another user
        expect(
          InventoryDeletionPolicy.canUndo(
            deleteOnlyUser,
            initiatedByUserId: 'another_user_id',
          ),
          isFalse,
        );
      });

      test(
        'CSV-only user can import CSV but cannot import XLSX or create directly',
        () {
          expect(InventoryImportPolicy.canImport(csvImportUser), isTrue);
          expect(InventoryImportPolicy.canImportCsv(csvImportUser), isTrue);
          expect(InventoryImportPolicy.canImportXlsx(csvImportUser), isFalse);
          expect(
            InventoryItemAdministrationPolicy.canCreate(csvImportUser),
            isFalse,
          );
        },
      );

      test(
        'XLSX-only user can import XLSX but cannot import CSV or create directly',
        () {
          expect(InventoryImportPolicy.canImport(xlsxImportUser), isTrue);
          expect(InventoryImportPolicy.canImportXlsx(xlsxImportUser), isTrue);
          expect(InventoryImportPolicy.canImportCsv(xlsxImportUser), isFalse);
          expect(
            InventoryItemAdministrationPolicy.canCreate(xlsxImportUser),
            isFalse,
          );
        },
      );
    });
  });
}
