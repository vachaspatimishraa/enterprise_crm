import 'package:flutter/material.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../domain/entities/managed_user.dart';
import '../../../dashboard/presentation/mappers/crm_module_presentation.dart';

/// Screen displaying the read-only details, module entitlements, and permissions of a managed user.
class UserDetailsScreen extends StatelessWidget {
  final CurrentUser currentUser;
  final ManagedUser user;

  const UserDetailsScreen({
    super.key,
    required this.currentUser,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    if (!currentUser.isAdmin) {
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
      appBar: AppBar(title: Text(user.displayName), elevation: 0),
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
                                backgroundColor: user.isAdmin
                                    ? colorScheme.primaryContainer
                                    : colorScheme.secondaryContainer,
                                child: Icon(
                                  user.isAdmin
                                      ? Icons.admin_panel_settings
                                      : Icons.person,
                                  color: user.isAdmin
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
                                      user.displayName,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '@${user.userId}',
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
                                  color: user.isAdmin
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  user.isAdmin ? 'Admin' : 'Standard User',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: user.isAdmin
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
                                  color: user.isActive
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: user.isActive
                                        ? Colors.green.withValues(alpha: 0.5)
                                        : Colors.grey.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  user.isActive ? 'Active' : 'Disabled',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: user.isActive
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
                                'ID: ${user.id}',
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
                      child: user.modules.isEmpty
                          ? Text(
                              'No business modules assigned.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: user.modules.map((module) {
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
                      child: user.isAdmin
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
                          : (user.permissions.isEmpty
                                ? Text(
                                    'No explicit permissions assigned.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: user.permissions.map((perm) {
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

                  // Deferral Notice Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'User editing and access changes will be added in the next administration phase.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Back Button
                  OutlinedButton.icon(
                    key: const Key('user_details_back_button'),
                    onPressed: () => Navigator.of(context).pop(),
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
