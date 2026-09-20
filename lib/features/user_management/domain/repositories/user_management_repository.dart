import '../entities/managed_user.dart';
import '../entities/user_account_status.dart';
import '../inputs/create_managed_user_input.dart';
import '../inputs/update_managed_user_input.dart';

/// Domain contract for managing user accounts in the Admin directory.
abstract interface class UserManagementRepository {
  /// Retrieves all managed users in the system.
  Future<List<ManagedUser>> getUsers();

  /// Retrieves a specific managed user by internal record identifier (`id`), or `null` if not found.
  Future<ManagedUser?> getUserById(String id);

  /// Retrieves a specific managed user by normalized login identifier (`userId`), or `null` if not found.
  Future<ManagedUser?> findUserByUserId(String userId);

  /// Creates a new managed normal user account with initial credentials.
  Future<ManagedUser> createUser(
    CreateManagedUserInput input, {
    required String temporaryPassword,
  });

  /// Updates an existing managed user account's mutable attributes.
  Future<ManagedUser> updateUser(UpdateManagedUserInput input);

  /// Enables or disables an existing managed user account.
  Future<ManagedUser> setUserStatus({
    required String id,
    required UserAccountStatus status,
  });

  /// Resets the authentication password for a managed user account.
  Future<void> resetPassword({required String id, required String newPassword});
}

/// Represents an operational failure in user management.
class UserManagementException implements Exception {
  final String message;

  const UserManagementException(this.message);

  @override
  String toString() => message;
}
