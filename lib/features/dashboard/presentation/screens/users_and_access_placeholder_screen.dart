import 'package:flutter/material.dart';

/// Admin-only UI shell placeholder for future Users & Access administration.
class UsersAndAccessPlaceholderScreen extends StatelessWidget {
  const UsersAndAccessPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Users & Access'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 32,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Administration: Users & Access',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enterprise access control, roles, and credential management.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Text(
                      'Planned Administrative Capabilities',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FeatureBullet(
                      icon: Icons.person_add_outlined,
                      title: 'User Management & Creation',
                      description:
                          'Create, enable, and disable employee accounts.',
                    ),
                    _FeatureBullet(
                      icon: Icons.view_module_outlined,
                      title: 'Module Access Assignment',
                      description:
                          'Assign access to any of the 8 business modules per account.',
                    ),
                    _FeatureBullet(
                      icon: Icons.security_outlined,
                      title: 'Fine-Grained Permissions',
                      description:
                          'Configure granular action permissions (view, add, edit, export, distribute).',
                    ),
                    _FeatureBullet(
                      icon: Icons.lock_reset_outlined,
                      title: 'Admin-Only Password Reset',
                      description:
                          'Only Administrators can reset credentials. No self-service reset allowed.',
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Users & Access implementation is scheduled for the next access-control checkpoint.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to Dashboard'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureBullet({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$title: ',
                style: const TextStyle(fontWeight: FontWeight.w600),
                children: [
                  TextSpan(
                    text: description,
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
