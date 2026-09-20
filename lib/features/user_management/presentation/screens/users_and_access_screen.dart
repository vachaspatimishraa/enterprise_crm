import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/entities/user_account_status.dart';
import '../../domain/repositories/user_management_repository.dart';
import '../bloc/user_directory_cubit.dart';
import '../bloc/user_directory_state.dart';
import 'create_user_screen.dart';
import 'user_details_screen.dart';

/// Admin-only Users & Access management workspace screen.
///
/// If a non-admin attempts to access this screen, access is blocked before
/// any directory cubit or repository query is executed.
class UsersAndAccessScreen extends StatelessWidget {
  final CurrentUser user;
  final UserManagementRepository? repository;

  const UsersAndAccessScreen({super.key, required this.user, this.repository});

  @override
  Widget build(BuildContext context) {
    // Strict Pre-Cubit Guard: Non-admin users are blocked immediately.
    // Zero calls to repository.getUsers() are made.
    if (!user.isAdmin) {
      return Scaffold(
        key: const Key('users_and_access_unauthorized_screen'),
        appBar: AppBar(title: const Text('Access Denied')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.gpp_bad_outlined,
                  size: 56,
                  color: Colors.redAccent,
                  key: Key('users_and_access_unauthorized_icon'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You do not have administrative privileges to access this area.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  key: const Key('users_and_access_unauthorized_back_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Return to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BlocProvider(
      create: (context) => UserDirectoryCubit(
        repository ?? context.read<UserManagementRepository>(),
      )..loadUsers(),
      child: _UsersAndAccessView(currentUser: user, repository: repository),
    );
  }
}

class _UsersAndAccessView extends StatefulWidget {
  final CurrentUser currentUser;
  final UserManagementRepository? repository;

  const _UsersAndAccessView({required this.currentUser, this.repository});

  @override
  State<_UsersAndAccessView> createState() => _UsersAndAccessViewState();
}

class _UsersAndAccessViewState extends State<_UsersAndAccessView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openUserDetails(ManagedUser managedUser) async {
    final repo = widget.repository ?? context.read<UserManagementRepository>();
    final cubit = context.read<UserDirectoryCubit>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserDetailsScreen(
          currentUser: widget.currentUser,
          user: managedUser,
          repository: repo,
        ),
      ),
    );
    if (mounted) {
      cubit.loadUsers();
    }
  }

  Future<void> _openCreateUser() async {
    final repo = widget.repository ?? context.read<UserManagementRepository>();
    final cubit = context.read<UserDirectoryCubit>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CreateUserScreen(currentUser: widget.currentUser, repository: repo),
      ),
    );
    if (created == true && mounted) {
      cubit.loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Users & Access'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: width < 600 ? 16.0 : 24.0,
            vertical: 20.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header
                  if (width >= 600)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'USER DIRECTORY',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Manage system accounts, module entitlements, and access policies.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.currentUser.isAdmin)
                          ElevatedButton.icon(
                            key: const Key('create_user_button'),
                            onPressed: _openCreateUser,
                            icon: const Icon(Icons.person_add_outlined),
                            label: const Text('+ Create User'),
                          ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'USER DIRECTORY',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage system accounts, module entitlements, and access policies.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (widget.currentUser.isAdmin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              key: const Key('create_user_button'),
                              onPressed: _openCreateUser,
                              icon: const Icon(Icons.person_add_outlined),
                              label: const Text('+ Create'),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 24),

                  // Search and Filter Controls Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    color: colorScheme.surfaceContainerLowest,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search Box
                          TextField(
                            key: const Key('user_search_field'),
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by name or user ID...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      key: const Key(
                                        'user_search_clear_button',
                                      ),
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        context
                                            .read<UserDirectoryCubit>()
                                            .clearSearch();
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {});
                              context.read<UserDirectoryCubit>().setSearchQuery(
                                val,
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // Filter Chips Row
                          BlocBuilder<UserDirectoryCubit, UserDirectoryState>(
                            builder: (context, state) {
                              final currentFilter = state is UserDirectoryLoaded
                                  ? state.statusFilter
                                  : null;

                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Status:',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  FilterChip(
                                    key: const Key('status_filter_all'),
                                    label: const Text('All'),
                                    selected: currentFilter == null,
                                    onSelected: (_) {
                                      context
                                          .read<UserDirectoryCubit>()
                                          .setStatusFilter(null);
                                    },
                                  ),
                                  FilterChip(
                                    key: const Key('status_filter_active'),
                                    label: const Text('Active'),
                                    selected:
                                        currentFilter ==
                                        UserAccountStatus.active,
                                    onSelected: (_) {
                                      context
                                          .read<UserDirectoryCubit>()
                                          .setStatusFilter(
                                            UserAccountStatus.active,
                                          );
                                    },
                                  ),
                                  FilterChip(
                                    key: const Key('status_filter_disabled'),
                                    label: const Text('Disabled'),
                                    selected:
                                        currentFilter ==
                                        UserAccountStatus.disabled,
                                    onSelected: (_) {
                                      context
                                          .read<UserDirectoryCubit>()
                                          .setStatusFilter(
                                            UserAccountStatus.disabled,
                                          );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Directory Content Area
                  BlocBuilder<UserDirectoryCubit, UserDirectoryState>(
                    builder: (context, state) {
                      switch (state) {
                        case UserDirectoryInitial():
                        case UserDirectoryLoading():
                          return const Center(
                            key: Key('user_directory_loading'),
                            child: Padding(
                              padding: EdgeInsets.all(48.0),
                              child: CircularProgressIndicator(),
                            ),
                          );

                        case UserDirectoryFailure(:final message):
                          return Center(
                            key: const Key('user_directory_error_view'),
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: colorScheme.error,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    message,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    key: const Key(
                                      'user_directory_retry_button',
                                    ),
                                    onPressed: () {
                                      context
                                          .read<UserDirectoryCubit>()
                                          .loadUsers();
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          );

                        case UserDirectoryLoaded(
                          :final allUsers,
                          :final filteredUsers,
                        ):
                          if (allUsers.isEmpty) {
                            return const Center(
                              key: Key('user_directory_empty'),
                              child: Padding(
                                padding: EdgeInsets.all(48.0),
                                child: Text('No users found.'),
                              ),
                            );
                          }

                          if (filteredUsers.isEmpty) {
                            return Center(
                              key: const Key('user_directory_no_matches'),
                              child: Padding(
                                padding: const EdgeInsets.all(48.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text('No users match your search.'),
                                    const SizedBox(height: 12),
                                    TextButton(
                                      key: const Key(
                                        'user_directory_reset_filters_button',
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        context
                                            .read<UserDirectoryCubit>()
                                            .clearSearch();
                                        context
                                            .read<UserDirectoryCubit>()
                                            .setStatusFilter(null);
                                      },
                                      child: const Text('Reset filters'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return _UserDirectoryList(
                            users: filteredUsers,
                            onSelectUser: _openUserDetails,
                          );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserDirectoryList extends StatelessWidget {
  final List<ManagedUser> users;
  final ValueChanged<ManagedUser> onSelectUser;

  const _UserDirectoryList({required this.users, required this.onSelectUser});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: users.length,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = users[index];
          return _UserMobileCard(
            key: Key('user_item_${user.id}'),
            user: user,
            onTap: () => onSelectUser(user),
          );
        },
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: users.length,
        separatorBuilder: (_, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final user = users[index];
          return _UserDesktopRow(
            key: Key('user_item_${user.id}'),
            user: user,
            onTap: () => onSelectUser(user),
          );
        },
      ),
    );
  }
}

class _UserMobileCard extends StatelessWidget {
  final ManagedUser user;
  final VoidCallback onTap;

  const _UserMobileCard({super.key, required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      color: colorScheme.surfaceContainerLowest,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: user.isAdmin
                        ? colorScheme.primaryContainer
                        : colorScheme.secondaryContainer,
                    child: Icon(
                      user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                      size: 20,
                      color: user.isAdmin
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@${user.userId}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _RoleChip(isAdmin: user.isAdmin),
                  _StatusChip(isActive: user.isActive),
                  Chip(
                    label: Text('${user.modules.length} modules'),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    side: BorderSide.none,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserDesktopRow extends StatelessWidget {
  final ManagedUser user;
  final VoidCallback onTap;

  const _UserDesktopRow({super.key, required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: user.isAdmin
                  ? colorScheme.primaryContainer
                  : colorScheme.secondaryContainer,
              child: Icon(
                user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                size: 18,
                color: user.isAdmin
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '@${user.userId}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _RoleChip(isAdmin: user.isAdmin),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusChip(isActive: user.isActive),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${user.modules.length} modules',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton.icon(
              key: Key('user_view_button_${user.id}'),
              onPressed: onTap,
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('View'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final bool isAdmin;

  const _RoleChip({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'User',
        style: theme.textTheme.labelSmall?.copyWith(
          color: isAdmin
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;

  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        isActive ? 'Active' : 'Disabled',
        style: theme.textTheme.labelSmall?.copyWith(
          color: isActive
              ? (theme.brightness == Brightness.dark
                    ? Colors.greenAccent
                    : Colors.green.shade800)
              : (theme.brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade700),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
