import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:enterprise_crm/features/auth/presentation/bloc/auth_state.dart';
import 'package:enterprise_crm/features/user_management/data/mock/mock_account_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/mock_auth_test_fixtures.dart';

void main() {
  group('AuthCubit', () {
    late MockAccountStore accountStore;
    late MockAuthRepository repository;
    late AuthCubit cubit;

    setUp(() {
      accountStore = MockAccountStore.seeded();
      repository = MockAuthRepository(accountStore: accountStore);
      cubit = AuthCubit(repository);
    });

    tearDown(() {
      cubit.close();
    });

    test(
      'initial state is AuthUnauthenticated when repository has no user',
      () {
        expect(cubit.state, isA<AuthUnauthenticated>());
      },
    );

    test(
      'initial state is AuthAuthenticated when repository has active user',
      () {
        final repoWithUser = MockAuthRepository(
          accountStore: accountStore,
          initialUser: MockAuthTestFixtures.admin,
        );
        final activeCubit = AuthCubit(repoWithUser);

        expect(
          activeCubit.state,
          equals(const AuthAuthenticated(MockAuthTestFixtures.admin)),
        );

        activeCubit.close();
      },
    );

    test(
      'valid admin login emits [AuthAuthenticating, AuthAuthenticated]',
      () async {
        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([isA<AuthAuthenticating>(), isA<AuthAuthenticated>()]),
        );

        await cubit.login(userId: 'admin', password: 'admin123');
        await expectation;

        final authenticated = cubit.state as AuthAuthenticated;
        expect(authenticated.user.id, 'admin');
        expect(authenticated.user.isAdmin, isTrue);
      },
    );

    test(
      'valid user login emits [AuthAuthenticating, AuthAuthenticated]',
      () async {
        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([isA<AuthAuthenticating>(), isA<AuthAuthenticated>()]),
        );

        await cubit.login(userId: 'user', password: 'user123');
        await expectation;

        final authenticated = cubit.state as AuthAuthenticated;
        expect(authenticated.user.id, 'user');
        expect(authenticated.user.isAdmin, isFalse);
      },
    );

    test('invalid login emits [AuthAuthenticating, AuthFailure]', () async {
      final expectation = expectLater(
        cubit.stream,
        emitsInOrder([isA<AuthAuthenticating>(), isA<AuthFailure>()]),
      );

      await cubit.login(userId: 'admin', password: 'wrong');
      await expectation;

      final failure = cubit.state as AuthFailure;
      expect(failure.message, 'Invalid User ID or password.');
    });

    test(
      'double submit protection ignores second call while authenticating',
      () async {
        // Custom repo with a delay on login
        final slowRepo = _SlowMockAuthRepository();
        final slowCubit = AuthCubit(slowRepo);

        final states = <AuthState>[];
        slowCubit.stream.listen(states.add);

        final firstCall = slowCubit.login(
          userId: 'admin',
          password: 'admin123',
        );
        final secondCall = slowCubit.login(
          userId: 'admin',
          password: 'admin123',
        );

        await Future.wait([firstCall, secondCall]);

        // Login on repository must be called only once
        expect(slowRepo.loginCallCount, equals(1));
        expect(slowCubit.state, isA<AuthAuthenticated>());

        slowCubit.close();
      },
    );

    test('logout transitions to AuthUnauthenticated', () async {
      await cubit.login(userId: 'admin', password: 'admin123');
      expect(cubit.state, isA<AuthAuthenticated>());

      await cubit.logout();
      expect(cubit.state, isA<AuthUnauthenticated>());
      expect(repository.currentUser, isNull);
    });

    test('clearFailure resets AuthFailure to AuthUnauthenticated', () async {
      await cubit.login(userId: 'unknown', password: 'bad');
      expect(cubit.state, isA<AuthFailure>());

      cubit.clearFailure();
      expect(cubit.state, isA<AuthUnauthenticated>());
    });
  });
}

class _SlowMockAuthRepository extends MockAuthRepository {
  int loginCallCount = 0;

  _SlowMockAuthRepository() : super(accountStore: MockAccountStore.seeded());

  @override
  Future<CurrentUser> login({
    required String userId,
    required String password,
  }) async {
    loginCallCount++;
    await Future.delayed(const Duration(milliseconds: 50));
    return super.login(userId: userId, password: password);
  }
}
