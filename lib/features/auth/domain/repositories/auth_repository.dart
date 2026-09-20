import '../entities/current_user.dart';

/// Domain repository contract for CRM authentication and session management.
abstract interface class AuthRepository {
  /// Authenticates with user credentials.
  ///
  /// Throws [AuthException] on invalid credentials or failure.
  Future<CurrentUser> login({required String userId, required String password});

  /// Logs out the current user and clears session state.
  Future<void> logout();

  /// The currently authenticated user in memory, or `null` if unauthenticated.
  CurrentUser? get currentUser;
}

/// Represents a domain-level authentication error.
class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}
