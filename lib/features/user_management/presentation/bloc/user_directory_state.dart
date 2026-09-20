import '../../domain/entities/managed_user.dart';
import '../../domain/entities/user_account_status.dart';

/// Represents the UI state of the Admin User Directory.
sealed class UserDirectoryState {
  const UserDirectoryState();
}

/// Initial uninitialized directory state.
final class UserDirectoryInitial extends UserDirectoryState {
  const UserDirectoryInitial();
}

/// Loading directory state.
final class UserDirectoryLoading extends UserDirectoryState {
  const UserDirectoryLoading();
}

/// Loaded directory state containing loaded users, search query, and status filter.
final class UserDirectoryLoaded extends UserDirectoryState {
  final List<ManagedUser> allUsers;
  final String searchQuery;
  final UserAccountStatus? statusFilter; // null signifies 'All'

  const UserDirectoryLoaded({
    required this.allUsers,
    this.searchQuery = '',
    this.statusFilter,
  });

  /// Computes the filtered list of users based on current search query and status filter.
  List<ManagedUser> get filteredUsers {
    final query = searchQuery.trim().toLowerCase();

    return allUsers.where((user) {
      // 1. Status Filter matching
      if (statusFilter != null && user.status != statusFilter) {
        return false;
      }
      // 2. Search Query matching (case-insensitive substring across displayName and userId)
      if (query.isNotEmpty) {
        final matchesName = user.displayName.toLowerCase().contains(query);
        final matchesUserId = user.userId.toLowerCase().contains(query);
        if (!matchesName && !matchesUserId) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  UserDirectoryLoaded copyWith({
    List<ManagedUser>? allUsers,
    String? searchQuery,
    UserAccountStatus? Function()? statusFilter,
  }) {
    return UserDirectoryLoaded(
      allUsers: allUsers ?? this.allUsers,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter != null ? statusFilter() : this.statusFilter,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDirectoryLoaded &&
          runtimeType == other.runtimeType &&
          searchQuery == other.searchQuery &&
          statusFilter == other.statusFilter &&
          allUsers.length == other.allUsers.length;

  @override
  int get hashCode => Object.hash(searchQuery, statusFilter, allUsers.length);
}

/// Failure state displaying a safe error message with retry capability.
final class UserDirectoryFailure extends UserDirectoryState {
  final String message;

  const UserDirectoryFailure(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDirectoryFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}
