import 'package:flutter/material.dart';

import '../../../auth/domain/entities/current_user.dart';

/// Simplified application header displayed across authenticated CRM dashboards.
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
        // On narrow viewports, display only avatar + logout to prevent crowding
        final isNarrow = constraints.maxWidth < 420;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Spacer(),
              if (!isNarrow && user.displayName.isNotEmpty) ...[
                Flexible(
                  child: Text(
                    user.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
        );
      },
    );
  }
}
