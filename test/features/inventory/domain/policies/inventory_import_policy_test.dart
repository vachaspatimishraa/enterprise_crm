import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/domain/policies/inventory_import_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryImportPolicy', () {
    test('Admin is authorized for import', () {
      final admin = CurrentUser(
        id: 'admin_1',
        displayName: 'Admin User',
        accountType: AccountType.admin,
        modules: {CrmModule.inventory},
        permissions: {CrmPermissions.inventoryView},
      );

      expect(InventoryImportPolicy.canImport(admin), isTrue);
    });

    test(
      'Standard user with inventory module and view permission is strictly denied',
      () {
        final user = CurrentUser(
          id: 'user_1',
          displayName: 'Standard User',
          accountType: AccountType.user,
          modules: {CrmModule.inventory},
          permissions: {CrmPermissions.inventoryView},
        );

        expect(InventoryImportPolicy.canImport(user), isFalse);
      },
    );

    test('Standard user without inventory module is strictly denied', () {
      final user = CurrentUser(
        id: 'user_2',
        displayName: 'Standard User',
        accountType: AccountType.user,
        modules: {CrmModule.leadManagement},
        permissions: {CrmPermissions.inventoryView},
      );

      expect(InventoryImportPolicy.canImport(user), isFalse);
    });
  });
}
