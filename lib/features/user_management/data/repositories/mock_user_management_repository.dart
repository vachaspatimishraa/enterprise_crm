import '../../domain/entities/managed_user.dart';
import '../../domain/entities/user_account_status.dart';
import '../../domain/inputs/create_managed_user_input.dart';
import '../../domain/inputs/update_managed_user_input.dart';
import '../../domain/repositories/user_management_repository.dart';
import '../mock/mock_account_store.dart';

/// In-memory mock implementation of [UserManagementRepository] backed by a shared [MockAccountStore].
class MockUserManagementRepository implements UserManagementRepository {
  final MockAccountStore _accountStore;

  /// Compatibility getter for tests referencing the default seeded directory accounts.
  static List<ManagedUser> get defaultSeeds =>
      MockAccountStore.seeded().getUsers();

  MockUserManagementRepository({required MockAccountStore accountStore})
    : _accountStore = accountStore;

  @override
  Future<List<ManagedUser>> getUsers() async {
    await Future<void>.delayed(Duration.zero);
    return _accountStore.getUsers();
  }

  @override
  Future<ManagedUser?> getUserById(String id) async {
    await Future<void>.delayed(Duration.zero);
    return _accountStore.getUserById(id);
  }

  @override
  Future<ManagedUser?> findUserByUserId(String userId) async {
    await Future<void>.delayed(Duration.zero);
    return _accountStore.findUserByUserId(userId);
  }

  @override
  Future<ManagedUser> createUser(
    CreateManagedUserInput input, {
    required String temporaryPassword,
  }) async {
    await Future<void>.delayed(Duration.zero);
    return _accountStore.createUser(
      input,
      temporaryPassword: temporaryPassword,
    );
  }

  @override
  Future<ManagedUser> updateUser(UpdateManagedUserInput input) async {
    await Future<void>.delayed(Duration.zero);
    return _accountStore.updateUser(input);
  }

  @override
  Future<ManagedUser> setUserStatus({
    required String id,
    required UserAccountStatus status,
  }) async {
    await Future<void>.delayed(Duration.zero);
    return _accountStore.setUserStatus(id: id, status: status);
  }

  @override
  Future<void> resetPassword({
    required String id,
    required String newPassword,
  }) async {
    await Future<void>.delayed(Duration.zero);
    _accountStore.resetPassword(id: id, newPassword: newPassword);
  }
}
