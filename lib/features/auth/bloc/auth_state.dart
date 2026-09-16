enum AuthStatus { unknown, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({required this.status, this.errorMessage});

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.authenticated() : this(status: AuthStatus.authenticated);
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);
  const AuthState.loading() : this(status: AuthStatus.loading);
  const AuthState.error(String message)
      : this(status: AuthStatus.error, errorMessage: message);
}