import '../entities/managed_user.dart';

/// Domain contract for reading managed user accounts in the Admin directory.
abstract interface class UserManagementRepository {
  /// Retrieves all managed users in the system.
  Future<List<ManagedUser>> getUsers();

  /// Retrieves a specific managed user by record identifier, or `null` if not found.
  Future<ManagedUser?> getUserById(String id);
}

/// Represents an operational failure in user management.
class UserManagementException implements Exception {
  final String message;

  const UserManagementException(this.message);

  @override
  String toString() => message;
}
