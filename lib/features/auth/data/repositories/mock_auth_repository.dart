import '../../../../features/user_management/data/mock/mock_account_store.dart';
import '../../domain/entities/current_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// In-memory mock authentication repository backed by a shared [MockAccountStore].
class MockAuthRepository implements AuthRepository {
  final MockAccountStore _accountStore;
  CurrentUser? _currentUser;

  MockAuthRepository({
    required MockAccountStore accountStore,
    CurrentUser? initialUser,
  }) : _accountStore = accountStore,
       _currentUser = initialUser;

  @override
  CurrentUser? get currentUser => _currentUser;

  @override
  Future<CurrentUser> login({
    required String userId,
    required String password,
  }) async {
    await Future<void>.delayed(Duration.zero);

    final managedUser = _accountStore.authenticate(
      userId: userId,
      password: password,
    );

    if (managedUser == null) {
      throw const AuthException('Invalid User ID or password.');
    }

    final user = CurrentUser(
      id: managedUser.userId,
      displayName: managedUser.displayName,
      accountType: managedUser.accountType,
      modules: managedUser.modules,
      permissions: managedUser.permissions,
    );

    _currentUser = user;
    return user;
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(Duration.zero);
    _currentUser = null;
  }
}
