import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../dashboard/presentation/mappers/crm_module_presentation.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/entities/user_account_status.dart';
import '../../domain/repositories/user_management_repository.dart';
import '../widgets/reset_password_dialog.dart';
import 'edit_user_screen.dart';

/// Screen displaying the details, module entitlements, permissions, and administrative
/// actions (Edit, Enable/Disable, Reset Password) for a managed user.
class UserDetailsScreen extends StatefulWidget {
  final CurrentUser currentUser;
  final ManagedUser user;
  final UserManagementRepository? repository;

  const UserDetailsScreen({
    super.key,
    required this.currentUser,
    required this.user,
    this.repository,
  });

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  late ManagedUser _user;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  UserManagementRepository _resolveRepository() {
    return widget.repository ?? context.read<UserManagementRepository>();
  }

  Future<void> _handleEditUser() async {
    final repo = _resolveRepository();
    final messenger = ScaffoldMessenger.of(context);
    final updatedUser = await Navigator.of(context).push<ManagedUser>(
      MaterialPageRoute(
        builder: (_) => EditUserScreen(
          currentUser: widget.currentUser,
          user: _user,
          repository: repo,
        ),
      ),
    );

    if (updatedUser != null && mounted) {
      setState(() {
        _user = updatedUser;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('User details updated for @${_user.userId}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleToggleStatus() async {
    if (_isActionInProgress) return;

    final repo = _resolveRepository();
    final messenger = ScaffoldMessenger.of(context);

    if (_user.isActive) {
      // Require explicit confirmation before disabling
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          key: const Key('disable_user_confirm_dialog'),
          title: const Text('Disable User Account?'),
          content: Text(
            'Are you sure you want to disable @${_user.userId}? They will no longer be able to log in to the CRM.',
          ),
          actions: [
            TextButton(
              key: const Key('disable_user_cancel_button'),
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('disable_user_confirm_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Disable User'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      setState(() => _isActionInProgress = true);
      try {
        final updated = await repo.setUserStatus(
          id: _user.id,
          status: UserAccountStatus.disabled,
        );
        if (mounted) {
          setState(() {
            _user = updated;
            _isActionInProgress = false;
          });
          messenger.showSnackBar(
            SnackBar(
              content: Text('Account @${_user.userId} has been disabled.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isActionInProgress = false);
          messenger.showSnackBar(
            SnackBar(
              content: Text('Failed to update status: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      // Re-enabling account
      setState(() => _isActionInProgress = true);
      try {
        final updated = await repo.setUserStatus(
          id: _user.id,
          status: UserAccountStatus.active,
        );
        if (mounted) {
          setState(() {
            _user = updated;
            _isActionInProgress = false;
          });
          messenger.showSnackBar(
            SnackBar(
              content: Text('Account @${_user.userId} has been enabled.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isActionInProgress = false);
          messenger.showSnackBar(
            SnackBar(
              content: Text('Failed to enable account: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleResetPassword() async {
    final repo = _resolveRepository();
    final messenger = ScaffoldMessenger.of(context);
    final reset = await ResetPasswordDialog.show(
      context,
      targetUser: _user,
      repository: repo,
    );

    if (reset == true && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Password reset successfully for @${_user.userId}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.currentUser.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Colors.redAccent,
                  key: Key('user_details_unauthorized_icon'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You do not have administrative privileges to view user details.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  key: const Key('user_details_unauthorized_back_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Return'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: Text(_user.displayName), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: width < 600 ? 16.0 : 24.0,
            vertical: 20.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Profile Card
                  Card(
                    key: const Key('user_details_profile_card'),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    color: colorScheme.surfaceContainerLowest,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: _user.isAdmin
                                    ? colorScheme.primaryContainer
                                    : colorScheme.secondaryContainer,
                                child: Icon(
                                  _user.isAdmin
                                      ? Icons.admin_panel_settings
                                      : Icons.person,
                                  color: _user.isAdmin
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _user.displayName,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '@${_user.userId}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Role Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _user.isAdmin
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _user.isAdmin ? 'Admin' : 'Standard User',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: _user.isAdmin
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _user.isActive
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _user.isActive
                                        ? Colors.green.withValues(alpha: 0.5)
                                        : Colors.grey.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  _user.isActive ? 'Active' : 'Disabled',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: _user.isActive
                                        ? (theme.brightness == Brightness.dark
                                              ? Colors.greenAccent
                                              : Colors.green.shade800)
                                        : (theme.brightness == Brightness.dark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade700),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // System Identifier
                              Text(
                                'ID: ${_user.id}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Module Entitlements Card
                  Text(
                    'MODULE ACCESS',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    color: colorScheme.surfaceContainerLowest,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: _user.modules.isEmpty
                          ? Text(
                              'No business modules assigned.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _user.modules.map((module) {
                                return Chip(
                                  avatar: Icon(module.icon, size: 18),
                                  label: Text(module.displayName),
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                  side: BorderSide.none,
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Permissions Card
                  Text(
                    'PERMISSIONS',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    color: colorScheme.surfaceContainerLowest,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: _user.isAdmin
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Administrative access',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Full frontend access in the current mock environment',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            )
                          : (_user.permissions.isEmpty
                                ? Text(
                                    'No explicit permissions assigned.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _user.permissions.map((perm) {
                                      return Chip(
                                        avatar: const Icon(
                                          Icons.check_circle_outline,
                                          size: 16,
                                        ),
                                        label: Text(perm),
                                        backgroundColor:
                                            colorScheme.surfaceContainerHighest,
                                        side: BorderSide.none,
                                      );
                                    }).toList(),
                                  )),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions Section
                  Text(
                    'ADMINISTRATIVE ACTIONS',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    key: const Key('user_details_actions_card'),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    color: colorScheme.surfaceContainerLowest,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_user.isAdmin) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Master Administrator accounts cannot be disabled or have modules/permissions modified.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              // Edit User (Normal users only)
                              if (!_user.isAdmin)
                                OutlinedButton.icon(
                                  key: const Key('user_details_edit_button'),
                                  onPressed: _isActionInProgress
                                      ? null
                                      : () => _handleEditUser(),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit User'),
                                ),

                              // Enable / Disable User (Normal users only)
                              if (!_user.isAdmin)
                                ElevatedButton.icon(
                                  key: const Key(
                                    'user_details_status_toggle_button',
                                  ),
                                  style: _user.isActive
                                      ? ElevatedButton.styleFrom(
                                          backgroundColor:
                                              colorScheme.errorContainer,
                                          foregroundColor:
                                              colorScheme.onErrorContainer,
                                        )
                                      : ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green
                                              .withValues(alpha: 0.15),
                                          foregroundColor:
                                              theme.brightness ==
                                                  Brightness.dark
                                              ? Colors.greenAccent
                                              : Colors.green.shade800,
                                        ),
                                  onPressed: _isActionInProgress
                                      ? null
                                      : () => _handleToggleStatus(),
                                  icon: Icon(
                                    _user.isActive
                                        ? Icons.person_off_outlined
                                        : Icons.check_circle_outline,
                                  ),
                                  label: Text(
                                    _user.isActive
                                        ? 'Disable User'
                                        : 'Enable User',
                                  ),
                                ),

                              // Reset Password (Admin and Normal users)
                              OutlinedButton.icon(
                                key: const Key(
                                  'user_details_reset_password_button',
                                ),
                                onPressed: _isActionInProgress
                                    ? null
                                    : () => _handleResetPassword(),
                                icon: const Icon(Icons.lock_reset_outlined),
                                label: const Text('Reset Password'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Back Button
                  OutlinedButton.icon(
                    key: const Key('user_details_back_button'),
                    onPressed: () => Navigator.of(context).pop(_user),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Users'),
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
