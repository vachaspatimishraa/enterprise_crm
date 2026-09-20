import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/repositories/auth_repository.dart';
import 'package:enterprise_crm/features/user_management/data/mock/mock_account_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mock_auth_test_fixtures.dart';

void main() {
  group('MockAuthRepository', () {
    late MockAccountStore accountStore;
    late MockAuthRepository repository;

    setUp(() {
      accountStore = MockAccountStore.seeded();
      repository = MockAuthRepository(accountStore: accountStore);
    });

    test('starts unauthenticated when no initialUser is provided', () {
      expect(repository.currentUser, isNull);
    });

    test('starts with initialUser when provided in constructor', () {
      final repoWithUser = MockAuthRepository(
        accountStore: accountStore,
        initialUser: MockAuthTestFixtures.admin,
      );
      expect(repoWithUser.currentUser, equals(MockAuthTestFixtures.admin));
    });

    test('login with valid admin credentials succeeds', () async {
      final user = await repository.login(
        userId: 'admin',
        password: 'admin123',
      );

      expect(user.id, 'admin');
      expect(user.displayName, 'Administrator');
      expect(user.accountType, AccountType.admin);
      expect(user.modules.length, 8);
      expect(repository.currentUser, equals(user));
    });

    test('login with valid standard user credentials succeeds', () async {
      final user = await repository.login(userId: 'user', password: 'user123');

      expect(user.id, 'user');
      expect(user.displayName, 'Standard User');
      expect(user.accountType, AccountType.user);
      expect(user.modules, {CrmModule.leadManagement, CrmModule.calling});
      expect(repository.currentUser, equals(user));
    });

    test('login with case-insensitive userId succeeds', () async {
      final user = await repository.login(
        userId: 'ADMIN',
        password: 'admin123',
      );
      expect(user.id, 'admin');
      expect(repository.currentUser, equals(user));
    });

    test('login with invalid credentials throws safe AuthException', () async {
      expect(
        () => repository.login(userId: 'admin', password: 'wrongpassword'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Invalid User ID or password.',
          ),
        ),
      );

      expect(repository.currentUser, isNull);
    });

    test(
      'login for disabled user throws safe AuthException without leaking status',
      () async {
        // First reset password for disabled user so it has a credential
        accountStore.resetPassword(id: 'usr_disabled', newPassword: 'pass');

        expect(
          () => repository.login(userId: 'disabled_user', password: 'pass'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'Invalid User ID or password.',
            ),
          ),
        );
        expect(repository.currentUser, isNull);
      },
    );

    test(
      'login for directory-only user without credential throws safe AuthException',
      () async {
        expect(
          () => repository.login(userId: 'hr_user', password: 'anypassword'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'Invalid User ID or password.',
            ),
          ),
        );
      },
    );

    test('logout clears currentUser from memory', () async {
      await repository.login(userId: 'admin', password: 'admin123');
      expect(repository.currentUser, isNotNull);

      await repository.logout();
      expect(repository.currentUser, isNull);
    });
  });
}
