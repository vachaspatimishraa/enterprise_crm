import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrentUser Domain Entity', () {
    test('admin user reports isAdmin true and has unrestricted access', () {
      const admin = CurrentUser(
        id: 'admin_1',
        displayName: 'Admin User',
        accountType: AccountType.admin,
        modules: {},
        permissions: {},
      );

      expect(admin.isAdmin, isTrue);
      expect(admin.hasModule(CrmModule.leadManagement), isTrue);
      expect(admin.hasModule(CrmModule.inventory), isTrue);
      expect(admin.hasPermission('any.custom.permission'), isTrue);
    });

    test('standard user reports isAdmin false and enforces module access', () {
      const user = CurrentUser(
        id: 'user_1',
        displayName: 'Standard User',
        accountType: AccountType.user,
        modules: {CrmModule.leadManagement, CrmModule.calling},
        permissions: {'leads.view'},
      );

      expect(user.isAdmin, isFalse);
      expect(user.hasModule(CrmModule.leadManagement), isTrue);
      expect(user.hasModule(CrmModule.calling), isTrue);
      expect(user.hasModule(CrmModule.inventory), isFalse);
      expect(user.hasModule(CrmModule.dispatch), isFalse);
      expect(user.hasPermission('leads.view'), isTrue);
      expect(user.hasPermission('leads.export'), isFalse);
    });

    test(
      'equality and hashCode are based on id, displayName, and accountType',
      () {
        const user1 = CurrentUser(
          id: 'u1',
          displayName: 'Alice',
          accountType: AccountType.user,
        );
        const user2 = CurrentUser(
          id: 'u1',
          displayName: 'Alice',
          accountType: AccountType.user,
        );
        const user3 = CurrentUser(
          id: 'u2',
          displayName: 'Bob',
          accountType: AccountType.user,
        );

        expect(user1, equals(user2));
        expect(user1.hashCode, equals(user2.hashCode));
        expect(user1, isNot(equals(user3)));
      },
    );
  });
}
