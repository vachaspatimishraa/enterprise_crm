import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

/// Manages top-level authentication lifecycle and session state.
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit(this._repository)
    : super(
        _repository.currentUser != null
            ? AuthAuthenticated(_repository.currentUser!)
            : const AuthUnauthenticated(),
      );

  /// Authenticates with provided credentials.
  ///
  /// Protects against duplicate concurrent submission while in [AuthAuthenticating] state.
  Future<void> login({required String userId, required String password}) async {
    if (state is AuthAuthenticating) {
      return;
    }

    emit(const AuthAuthenticating());

    try {
      final user = await _repository.login(userId: userId, password: password);
      emit(AuthAuthenticated(user));
    } catch (e) {
      final message = e is AuthException
          ? e.message
          : 'Invalid User ID or password.';
      emit(AuthFailure(message));
    }
  }

  /// Terminates the current session and returns to unauthenticated state.
  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }

  /// Clears any transient failure state back to unauthenticated.
  void clearFailure() {
    if (state is AuthFailure) {
      emit(const AuthUnauthenticated());
    }
  }
}
