import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockAuthRepository', () {
    late MockAuthRepository repository;

    setUp(() {
      repository = MockAuthRepository();
    });

    test('starts unauthenticated when no initialUser is provided', () {
      expect(repository.currentUser, isNull);
    });

    test('starts with initialUser when provided in constructor', () {
      final repoWithUser = MockAuthRepository(
        initialUser: MockAuthRepository.mockAdmin,
      );
      expect(repoWithUser.currentUser, equals(MockAuthRepository.mockAdmin));
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

    test('logout clears currentUser from memory', () async {
      await repository.login(userId: 'admin', password: 'admin123');
      expect(repository.currentUser, isNotNull);

      await repository.logout();
      expect(repository.currentUser, isNull);
    });
  });
}
