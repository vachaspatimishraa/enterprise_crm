import 'package:flutter/material.dart';

import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../auth/presentation/mappers/crm_permission_presentation.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../mappers/crm_module_presentation.dart';

/// Clean placeholder screen for CRM business modules scheduled for future phases.
///
/// Unconditionally enforces module authorization via [AccessPolicy] and displays
/// truthful operational permission status.
class ModulePlaceholderScreen extends StatelessWidget {
  final CrmModule module;
  final CurrentUser user;

  const ModulePlaceholderScreen({
    super.key,
    required this.module,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    // Route guard: Direct navigation protection
    if (!AccessPolicy.canAccessModule(user, module)) {
      return const AccessRestrictedScreen();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final modulePermissions = CrmPermissions.permissionsFor(module);
    final isFineGrained = modulePermissions.isNotEmpty;

    final hasOperationalPermission =
        user.isAdmin ||
        !isFineGrained ||
        modulePermissions.any((p) => AccessPolicy.hasPermission(user, p));

    final grantedPermissions = isFineGrained
        ? modulePermissions
              .where((p) => AccessPolicy.hasPermission(user, p))
              .toList()
        : const <String>[];

    return Scaffold(
      key: Key('module_placeholder_screen_${module.name}'),
      appBar: AppBar(title: Text(module.displayName), elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        module.icon,
                        size: 40,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      module.displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      module.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Status / Capability Banner
                    if (hasOperationalPermission) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Access granted.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Coming in a later module phase.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This business module has not been implemented yet.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      if (grantedPermissions.isNotEmpty && !user.isAdmin) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ASSIGNED CAPABILITIES',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final p in grantedPermissions)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check,
                                        size: 14,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        CrmPermissionPresentation.displayNameFor(
                                          p,
                                        ),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      // Assigned module without operational permissions
                      Container(
                        key: const Key('module_no_operational_permission'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'You do not currently have an operational permission for this module.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Contact an administrator to request operational permissions.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      key: const Key('module_placeholder_back_button'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Dashboard'),
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
