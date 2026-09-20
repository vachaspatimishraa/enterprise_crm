import 'package:flutter/material.dart';

import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../user_management/domain/repositories/user_management_repository.dart';
import '../../../user_management/presentation/screens/users_and_access_screen.dart';
import '../widgets/crm_app_header.dart';
import '../widgets/crm_module_card.dart';
import 'module_placeholder_screen.dart';

/// Global Admin Dashboard providing access to all 8 CRM business modules
/// and the Administration section.
class AdminDashboardScreen extends StatelessWidget {
  final CurrentUser user;
  final VoidCallback onLogout;
  final VoidCallback onOpenLeadManagement;
  final UserManagementRepository? userManagementRepository;

  const AdminDashboardScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onOpenLeadManagement,
    this.userManagementRepository,
  });

  void _openModule(BuildContext context, CrmModule module) {
    if (module == CrmModule.leadManagement) {
      onOpenLeadManagement();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ModulePlaceholderScreen(module: module, user: user),
        ),
      );
    }
  }

  void _openUsersAndAccess(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UsersAndAccessScreen(
          user: user,
          repository: userManagementRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.of(context).size.width;

    final crossAxisCount = width < 600
        ? 1
        : width < 1000
        ? 2
        : 4;

    const allModules = CrmModule.values;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            CrmAppHeader(user: user, onLogout: onLogout),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: width < 400 ? 14.0 : 24.0,
                  vertical: 20.0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page Title & Subtitle
                        Text(
                          'ADMIN DASHBOARD',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Full system access across all enterprise modules.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Business Modules Section Header
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'BUSINESS MODULES',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${allModules.length}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Business Modules Grid
                        GridView.builder(
                          key: const Key('admin_business_modules_grid'),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 160,
                              ),
                          itemCount: allModules.length,
                          itemBuilder: (context, index) {
                            final module = allModules[index];
                            return CrmModuleCard(
                              module: module,
                              onTap: () => _openModule(context, module),
                            );
                          },
                        ),
                        const SizedBox(height: 36),

                        // Administration Section Header
                        Text(
                          'ADMINISTRATION',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.secondary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Users & Access Card
                        SizedBox(
                          width: crossAxisCount == 1 ? double.infinity : 320,
                          child: Card(
                            key: const Key('admin_card_users_and_access'),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            color: colorScheme.surfaceContainerLowest,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _openUsersAndAccess(context),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                colorScheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.admin_panel_settings_outlined,
                                            size: 26,
                                            color: colorScheme
                                                .onSecondaryContainer,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                          color: colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.6),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Users & Access',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'User creation, permissions, and credential control',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
