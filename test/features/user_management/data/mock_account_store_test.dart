import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/user_management/data/mock/mock_account_store.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/managed_user.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/user_account_status.dart';
import 'package:enterprise_crm/features/user_management/domain/inputs/create_managed_user_input.dart';
import 'package:enterprise_crm/features/user_management/domain/inputs/update_managed_user_input.dart';
import 'package:enterprise_crm/features/user_management/domain/repositories/user_management_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockAccountStore Tests', () {
    late MockAccountStore store;

    setUp(() {
      store = MockAccountStore.seeded();
    });

    test('initial seeding contains expected 5 accounts and correct status', () {
      final users = store.getUsers();
      expect(users.length, 5);

      final admin = users.firstWhere((u) => u.userId == 'admin');
      expect(admin.id, 'usr_admin');
      expect(admin.accountType, AccountType.admin);
      expect(admin.isAdmin, isTrue);
      expect(admin.isActive, isTrue);
      expect(admin.permissions, isEmpty);
      expect(admin.modules.length, 8);

      final standard = users.firstWhere((u) => u.userId == 'user');
      expect(standard.id, 'usr_standard');
      expect(standard.accountType, AccountType.user);
      expect(standard.isActive, isTrue);

      final hr = users.firstWhere((u) => u.userId == 'hr_user');
      expect(hr.id, 'usr_hr');
      expect(hr.isActive, isTrue);

      final inventory = users.firstWhere((u) => u.userId == 'inventory_user');
      expect(inventory.id, 'usr_inventory');
      expect(inventory.isActive, isTrue);

      final disabled = users.firstWhere((u) => u.userId == 'disabled_user');
      expect(disabled.id, 'usr_disabled');
      expect(disabled.isDisabled, isTrue);
    });

    test(
      'credential isolation: only admin and user have initial credentials',
      () {
        expect(
          store.authenticate(userId: 'admin', password: 'admin123'),
          isNotNull,
        );
        expect(
          store.authenticate(userId: 'user', password: 'user123'),
          isNotNull,
        );
        // hr_user, inventory_user, and disabled_user have no initial passwords
        expect(
          store.authenticate(userId: 'hr_user', password: 'password'),
          isNull,
        );
        expect(
          store.authenticate(userId: 'inventory_user', password: 'password'),
          isNull,
        );
        expect(
          store.authenticate(userId: 'disabled_user', password: 'password'),
          isNull,
        );
      },
    );

    test('strict separation: getUserById(id) vs findUserByUserId(userId)', () {
      // getUserById strictly matches internal record id
      expect(store.getUserById('usr_admin'), isNotNull);
      expect(store.getUserById('admin'), isNull);

      // findUserByUserId strictly matches login identifier
      expect(store.findUserByUserId('admin'), isNotNull);
      expect(store.findUserByUserId('usr_admin'), isNull);

      // findUserByUserId matches case-insensitively and trimmed
      expect(store.findUserByUserId('  ADMIN  '), isNotNull);
      expect(store.findUserByUserId('USER'), isNotNull);
    });

    test('defensive immutability: getUsers() returns unmodifiable list', () {
      final users = store.getUsers();
      expect(
        () => (users as dynamic).add(
          ManagedUser(
            id: 'fake',
            userId: 'fake',
            displayName: 'Fake',
            accountType: AccountType.user,
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test(
      'defensive immutability: ManagedUser modules and permissions are unmodifiable',
      () {
        final user = store.getUserById('usr_standard')!;
        expect(
          () => (user.modules as dynamic).add(CrmModule.hrPayroll),
          throwsA(isA<UnsupportedError>()),
        );
        expect(
          () => (user.permissions as dynamic).add('new.perm'),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );

    group('createUser', () {
      test('creates normal user with active status and stores credentials', () {
        final input = CreateManagedUserInput(
          userId: 'sales_rep',
          displayName: 'Sales Rep',
          modules: {CrmModule.leadManagement, CrmModule.calling},
          permissions: {'lead.view_assigned', 'calling.use'},
        );

        final created = store.createUser(
          input,
          temporaryPassword: 'tempPassword123',
        );

        expect(created.id, startsWith('usr_gen_'));
        expect(created.userId, 'sales_rep');
        expect(created.displayName, 'Sales Rep');
        expect(created.accountType, AccountType.user);
        expect(created.status, UserAccountStatus.active);
        expect(created.modules, input.modules);
        expect(created.permissions, input.permissions);

        // Can authenticate with newly stored temporary password
        final authenticated = store.authenticate(
          userId: 'sales_rep',
          password: 'tempPassword123',
        );
        expect(authenticated, isNotNull);
        expect(authenticated?.id, created.id);
      });

      test('rejects duplicate userId case-insensitively', () {
        final input1 = CreateManagedUserInput(
          userId: 'USER',
          displayName: 'Duplicate User',
        );
        expect(
          () => store.createUser(input1, temporaryPassword: 'pass'),
          throwsA(
            isA<UserManagementException>().having(
              (e) => e.message,
              'message',
              contains('already taken'),
            ),
          ),
        );
      });

      test('validates required fields', () {
        expect(
          () => store.createUser(
            CreateManagedUserInput(userId: '  ', displayName: 'Valid'),
            temporaryPassword: 'pass',
          ),
          throwsA(isA<UserManagementException>()),
        );

        expect(
          () => store.createUser(
            CreateManagedUserInput(userId: 'valid_id', displayName: '  '),
            temporaryPassword: 'pass',
          ),
          throwsA(isA<UserManagementException>()),
        );

        expect(
          () => store.createUser(
            CreateManagedUserInput(userId: 'valid_id', displayName: 'Valid'),
            temporaryPassword: '   ',
          ),
          throwsA(isA<UserManagementException>()),
        );
      });

      test('allows zero modules for staged account setup', () {
        final created = store.createUser(
          CreateManagedUserInput(
            userId: 'staged_user',
            displayName: 'Staged User',
            modules: const {},
            permissions: const {},
          ),
          temporaryPassword: 'pass',
        );

        expect(created.modules, isEmpty);
        expect(created.permissions, isEmpty);
        expect(
          store.authenticate(userId: 'staged_user', password: 'pass'),
          isNotNull,
        );
      });

      test('rejects unknown or orphan permissions on create', () {
        // Unknown permission
        expect(
          () => store.createUser(
            CreateManagedUserInput(
              userId: 'new_user1',
              displayName: 'User',
              modules: {CrmModule.leadManagement},
              permissions: {'fake.perm'},
            ),
            temporaryPassword: 'pass',
          ),
          throwsA(isA<UserManagementException>()),
        );

        // Orphan permission (calling.use submitted but calling module not selected)
        expect(
          () => store.createUser(
            CreateManagedUserInput(
              userId: 'new_user2',
              displayName: 'User',
              modules: {CrmModule.leadManagement},
              permissions: {'calling.use'},
            ),
            temporaryPassword: 'pass',
          ),
          throwsA(isA<UserManagementException>()),
        );
      });
    });

    group('updateUser', () {
      test(
        'updates displayName, modules, and auto-prunes orphan permissions',
        () {
          final input = UpdateManagedUserInput(
            id: 'usr_standard',
            displayName: 'Updated Standard User',
            modules: {CrmModule.calling}, // removed leadManagement
            permissions: {
              'lead.view_assigned',
              'calling.use',
            }, // contains old lead perm
          );

          final updated = store.updateUser(input);
          expect(updated.displayName, 'Updated Standard User');
          expect(updated.modules, {CrmModule.calling});
          // lead.view_assigned was automatically pruned; only calling.use survives
          expect(updated.permissions, {'calling.use'});
        },
      );

      test('rejects unknown permission on update', () {
        final input = UpdateManagedUserInput(
          id: 'usr_standard',
          displayName: 'Standard User',
          modules: {CrmModule.leadManagement},
          permissions: {'bogus.perm'},
        );

        expect(
          () => store.updateUser(input),
          throwsA(isA<UserManagementException>()),
        );
      });

      test('enforces Master Administrator access protection', () {
        // Attempting to remove modules from Master Admin must fail
        final inputModules = UpdateManagedUserInput(
          id: 'usr_admin',
          displayName: 'Administrator',
          modules: {CrmModule.leadManagement},
          permissions: const {},
        );

        expect(
          () => store.updateUser(inputModules),
          throwsA(
            isA<UserManagementException>().having(
              (e) => e.message,
              'message',
              contains('Master Administrator access cannot be modified'),
            ),
          ),
        );

        // Attempting to alter permissions of Master Admin must fail
        final inputPerms = UpdateManagedUserInput(
          id: 'usr_admin',
          displayName: 'Administrator',
          modules: Set.of(CrmModule.values),
          permissions: {'lead.view_assigned'},
        );

        expect(
          () => store.updateUser(inputPerms),
          throwsA(
            isA<UserManagementException>().having(
              (e) => e.message,
              'message',
              contains('Master Administrator permissions cannot be modified'),
            ),
          ),
        );
      });

      test('rejects non-existent user id', () {
        final input = UpdateManagedUserInput(
          id: 'usr_nonexistent',
          displayName: 'Ghost',
        );
        expect(
          () => store.updateUser(input),
          throwsA(isA<UserManagementException>()),
        );
      });
    });

    group('setUserStatus', () {
      test(
        'disabling active user blocks login while retaining access configuration',
        () {
          final disabled = store.setUserStatus(
            id: 'usr_standard',
            status: UserAccountStatus.disabled,
          );

          expect(disabled.status, UserAccountStatus.disabled);
          expect(disabled.isDisabled, isTrue);
          expect(disabled.modules, contains(CrmModule.leadManagement));
          expect(disabled.permissions, contains('lead.view_assigned'));

          // Login fails while disabled
          expect(
            store.authenticate(userId: 'user', password: 'user123'),
            isNull,
          );

          // Re-enabling restores login
          final reEnabled = store.setUserStatus(
            id: 'usr_standard',
            status: UserAccountStatus.active,
          );
          expect(reEnabled.isActive, isTrue);
          expect(
            store.authenticate(userId: 'user', password: 'user123'),
            isNotNull,
          );
        },
      );

      test('Master Administrator account cannot be disabled', () {
        expect(
          () => store.setUserStatus(
            id: 'usr_admin',
            status: UserAccountStatus.disabled,
          ),
          throwsA(
            isA<UserManagementException>().having(
              (e) => e.message,
              'message',
              contains('Master Administrator account cannot be disabled'),
            ),
          ),
        );
      });
    });

    group('resetPassword', () {
      test('invalidates old password and sets new password', () {
        store.resetPassword(
          id: 'usr_standard',
          newPassword: 'newSecretPassword123',
        );

        // Old password fails
        expect(store.authenticate(userId: 'user', password: 'user123'), isNull);
        // New password succeeds
        expect(
          store.authenticate(userId: 'user', password: 'newSecretPassword123'),
          isNotNull,
        );
      });

      test('establishes login credential for directory-only account', () {
        // usr_hr has no initial password
        expect(store.authenticate(userId: 'hr_user', password: 'any'), isNull);

        // Reset establishes initial credential
        store.resetPassword(id: 'usr_hr', newPassword: 'hrSecretPassword');

        final user = store.authenticate(
          userId: 'hr_user',
          password: 'hrSecretPassword',
        );
        expect(user, isNotNull);
        expect(user?.userId, 'hr_user');
      });

      test(
        'resetting password on disabled user remains unauthenticated until re-enabled',
        () {
          store.resetPassword(id: 'usr_disabled', newPassword: 'newPass');

          // Still rejected because account is disabled
          expect(
            store.authenticate(userId: 'disabled_user', password: 'newPass'),
            isNull,
          );

          // Once re-enabled, new password works
          store.setUserStatus(
            id: 'usr_disabled',
            status: UserAccountStatus.active,
          );
          expect(
            store.authenticate(userId: 'disabled_user', password: 'newPass'),
            isNotNull,
          );
        },
      );

      test('rejects empty password', () {
        expect(
          () => store.resetPassword(id: 'usr_standard', newPassword: '   '),
          throwsA(isA<UserManagementException>()),
        );
      });
    });
  });
}
