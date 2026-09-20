import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/user_account_status.dart';
import '../../domain/repositories/user_management_repository.dart';
import 'user_directory_state.dart';

/// Manages directory listing, search queries, and status filtering for CRM users.
class UserDirectoryCubit extends Cubit<UserDirectoryState> {
  final UserManagementRepository _repository;

  UserDirectoryCubit(this._repository) : super(const UserDirectoryInitial());

  /// Fetches managed user records from the repository.
  Future<void> loadUsers() async {
    final currentQuery = state is UserDirectoryLoaded
        ? (state as UserDirectoryLoaded).searchQuery
        : '';
    final currentFilter = state is UserDirectoryLoaded
        ? (state as UserDirectoryLoaded).statusFilter
        : null;

    emit(const UserDirectoryLoading());

    try {
      final users = await _repository.getUsers();
      emit(
        UserDirectoryLoaded(
          allUsers: users,
          searchQuery: currentQuery,
          statusFilter: currentFilter,
        ),
      );
    } catch (_) {
      emit(const UserDirectoryFailure('Unable to load users.'));
    }
  }

  /// Updates the local substring search query.
  void setSearchQuery(String query) {
    if (state is UserDirectoryLoaded) {
      final loaded = state as UserDirectoryLoaded;
      emit(loaded.copyWith(searchQuery: query));
    }
  }

  /// Clears the active search query.
  void clearSearch() {
    setSearchQuery('');
  }

  /// Updates the account status filter (`null` represents All).
  void setStatusFilter(UserAccountStatus? status) {
    if (state is UserDirectoryLoaded) {
      final loaded = state as UserDirectoryLoaded;
      emit(loaded.copyWith(statusFilter: () => status));
    }
  }
}
