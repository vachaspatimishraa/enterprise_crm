import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../user_management/domain/inputs/update_managed_user_input.dart';
import '../../../user_management/domain/repositories/user_management_repository.dart';
import 'account_otp_password_reset_section.dart';

/// Modal dialog for managing authenticated account profile, OTP-verified
/// password reset, and session termination.
///
/// NOTE: The User ID is permanent and strictly cannot be changed.
class AccountProfileDialog extends StatefulWidget {
  final CurrentUser user;
  final VoidCallback onLogout;
  final UserManagementRepository? userManagementRepository;
  final AuthRepository? authRepository;

  const AccountProfileDialog({
    super.key,
    required this.user,
    required this.onLogout,
    this.userManagementRepository,
    this.authRepository,
  });

  static Future<void> show(
    BuildContext context, {
    required CurrentUser user,
    required VoidCallback onLogout,
    UserManagementRepository? userManagementRepository,
    AuthRepository? authRepository,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AccountProfileDialog(
        user: user,
        onLogout: onLogout,
        userManagementRepository: userManagementRepository,
        authRepository: authRepository,
      ),
    );
  }

  @override
  State<AccountProfileDialog> createState() => _AccountProfileDialogState();
}

class _AccountProfileDialogState extends State<AccountProfileDialog> {
  late final TextEditingController _userIdController;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  bool _showPasswordResetFlow = false;
  String? _profileError;
  bool _isSavingProfile = false;

  @override
  void initState() {
    super.initState();
    _userIdController = TextEditingController(text: widget.user.id);
    _nameController = TextEditingController(text: widget.user.displayName);
    _emailController = TextEditingController(text: '${widget.user.id}@enterprise-crm.internal');
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  T? _tryRead<T>(BuildContext context) {
    try {
      return context.read<T?>();
    } catch (_) {
      try {
        return context.read<T>();
      } catch (_) {
        return null;
      }
    }
  }

  AuthRepository? _resolveAuthRepository(BuildContext context) {
    return widget.authRepository ??
        _tryRead<AuthRepository>(context) ??
        _tryRead<AuthCubit>(context)?.repository;
  }

  Future<void> _handleSaveProfile() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      setState(() {
        _profileError = 'Display Name cannot be empty.';
      });
      return;
    }

    setState(() {
      _isSavingProfile = true;
      _profileError = null;
    });

    try {
      final repo =
          widget.userManagementRepository ??
          _tryRead<UserManagementRepository>(context);
      if (repo != null) {
        final managedUser = await repo.getUserById(widget.user.id) ??
            await repo.findUserByUserId(widget.user.id);
        if (managedUser != null) {
          await repo.updateUser(
            UpdateManagedUserInput(
              id: managedUser.id,
              displayName: newName,
              modules: managedUser.modules,
              permissions: managedUser.permissions,
            ),
          );
        }
      }

      if (mounted) {
        final updatedUser = widget.user.copyWith(displayName: newName);
        try {
          context.read<AuthCubit>().updateCurrentUser(updatedUser);
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account profile updated successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _profileError = e.toString();
          _isSavingProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      key: const Key('home_account_dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Avatar and User Info
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      widget.user.displayName.isNotEmpty
                          ? widget.user.displayName.substring(0, 1).toUpperCase()
                          : 'U',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.user.isAdmin
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.user.isAdmin ? 'Administrator' : 'Standard User',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: widget.user.isAdmin
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('account_dialog_close_button'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section: Appearance / Theme Mode
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Appearance',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeModeController.instance,
                    builder: (context, mode, _) {
                      final isDark = theme.brightness == Brightness.dark;
                      return OutlinedButton.icon(
                        key: const Key('account_dialog_theme_toggle'),
                        icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 16),
                        label: Text(isDark ? 'Switch to Light' : 'Switch to Dark'),
                        onPressed: () => ThemeModeController.instance.toggleTheme(theme.brightness),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              // Section: Profile Attributes
              Text(
                'Profile Details',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Read-only User ID (Cannot be changed)
              TextField(
                key: const Key('account_user_id_field'),
                controller: _userIdController,
                readOnly: true,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'User ID',
                  helperText: 'User ID cannot be changed',
                  helperStyle: TextStyle(color: colorScheme.outline),
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Editable Display Name
              TextField(
                key: const Key('account_display_name_field'),
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full / Display Name',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),

              // Editable Contact / Email
              TextField(
                key: const Key('account_email_field'),
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email / Contact',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              if (_profileError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _profileError!,
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('account_save_profile_button'),
                  onPressed: _isSavingProfile ? null : _handleSaveProfile,
                  child: _isSavingProfile
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Profile Changes'),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Section: OTP-Verified Password Reset
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Security & Password',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'OTP verification required to reset password',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('account_reset_password_button'),
                    icon: Icon(_showPasswordResetFlow ? Icons.keyboard_arrow_up : Icons.lock_reset, size: 18),
                    label: Text(_showPasswordResetFlow ? 'Hide' : 'Reset Password'),
                    onPressed: () {
                      setState(() {
                        _showPasswordResetFlow = !_showPasswordResetFlow;
                      });
                    },
                  ),
                ],
              ),

              if (_showPasswordResetFlow) ...[
                const SizedBox(height: 10),
                AccountOtpPasswordResetSection(
                  userId: widget.user.id,
                  authRepository: _resolveAuthRepository(context),
                  onPasswordChanged: () {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password changed successfully.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    setState(() {
                      _showPasswordResetFlow = false;
                    });
                  },
                ),
              ],

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),

              // Section: Logout Button
              FilledButton.icon(
                key: const Key('account_logout_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onLogout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
