import '../../domain/entities/current_user.dart';

/// Represents the top-level authentication and session state.
sealed class AuthState {
  const AuthState();
}

/// Unauthenticated state; displays login screen.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Authenticating state during in-flight login request.
final class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();
}

/// Authenticated state holding the active [CurrentUser].
final class AuthAuthenticated extends AuthState {
  final CurrentUser user;

  const AuthAuthenticated(this.user);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthAuthenticated &&
          runtimeType == other.runtimeType &&
          user == other.user;

  @override
  int get hashCode => user.hashCode;
}

/// Authentication failure state holding user-safe error message.
final class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}
