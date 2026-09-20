import 'package:flutter/material.dart';

import '../../../auth/domain/entities/current_user.dart';

/// Application header displayed across CRM dashboards.
class CrmAppHeader extends StatelessWidget {
  final CurrentUser user;
  final VoidCallback onLogout;

  const CrmAppHeader({super.key, required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;
        final isVeryCompact = constraints.maxWidth < 360;

        final roleLabel = user.isAdmin ? 'Administrator' : 'Standard User';
        final roleColor = user.isAdmin
            ? colorScheme.primary
            : colorScheme.secondary;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isVeryCompact ? 12 : 20,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              // Branding
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.business_center,
                        size: 20,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Enterprise CRM',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // User info and Logout
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isCompact) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          roleLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: roleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                  ],
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      user.displayName.isNotEmpty
                          ? user.displayName.substring(0, 1).toUpperCase()
                          : 'U',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('crm_header_logout_button'),
                    icon: const Icon(Icons.logout),
                    tooltip: 'Logout',
                    onPressed: onLogout,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
