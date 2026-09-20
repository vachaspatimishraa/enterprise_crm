import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/user_management/data/repositories/mock_user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/managed_user.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/user_account_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockUserManagementRepository Tests', () {
    late MockUserManagementRepository repository;

    setUp(() {
      repository = MockUserManagementRepository();
    });

    test('defaultSeeds contain expected accounts and no passwords', () {
      final seeds = MockUserManagementRepository.defaultSeeds;
      expect(seeds.length, 5);

      final admin = seeds.firstWhere((u) => u.userId == 'admin');
      expect(admin.accountType, AccountType.admin);
      expect(admin.isAdmin, isTrue);
      expect(admin.isActive, isTrue);
      // Correction 1: Admin has empty permissions set (no fake '*')
      expect(admin.permissions, isEmpty);
      expect(admin.modules, hasLength(CrmModule.values.length));

      final standard = seeds.firstWhere((u) => u.userId == 'user');
      expect(standard.accountType, AccountType.user);
      expect(standard.isAdmin, isFalse);
      expect(standard.isActive, isTrue);
      expect(standard.modules, contains(CrmModule.leadManagement));
      expect(standard.modules, contains(CrmModule.calling));
      expect(standard.permissions, contains('lead.view_assigned'));

      final disabled = seeds.firstWhere((u) => u.userId == 'disabled_user');
      expect(disabled.status, UserAccountStatus.disabled);
      expect(disabled.isDisabled, isTrue);
      expect(disabled.isActive, isFalse);
    });

    test(
      'getUsers sorts Admin first, then displayName alphabetically A-Z',
      () async {
        final customUsers = [
          const ManagedUser(
            id: 'u3',
            userId: 'charlie',
            displayName: 'Charlie Brown',
            accountType: AccountType.user,
          ),
          const ManagedUser(
            id: 'u1',
            userId: 'alice',
            displayName: 'Alice Walker',
            accountType: AccountType.user,
          ),
          const ManagedUser(
            id: 'u2',
            userId: 'admin2',
            displayName: 'Super Admin',
            accountType: AccountType.admin,
          ),
          const ManagedUser(
            id: 'u0',
            userId: 'admin1',
            displayName: 'Alpha Admin',
            accountType: AccountType.admin,
          ),
        ];

        final repo = MockUserManagementRepository(initialUsers: customUsers);
        final users = await repo.getUsers();

        expect(users.length, 4);
        // Admin accounts come first, sorted by displayName
        expect(users[0].userId, 'admin1'); // Alpha Admin (admin)
        expect(users[1].userId, 'admin2'); // Super Admin (admin)
        // Non-admin accounts sorted by displayName
        expect(users[2].userId, 'alice'); // Alice Walker (user)
        expect(users[3].userId, 'charlie'); // Charlie Brown (user)
      },
    );

    test('getUserById finds user by internal id or userId', () async {
      final byId = await repository.getUserById('usr_admin');
      expect(byId, isNotNull);
      expect(byId?.userId, 'admin');

      final byUserId = await repository.getUserById('admin');
      expect(byUserId, isNotNull);
      expect(byUserId?.id, 'usr_admin');

      final notFound = await repository.getUserById('non_existent_id');
      expect(notFound, isNull);
    });
  });
}
