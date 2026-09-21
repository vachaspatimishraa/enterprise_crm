import 'package:flutter/material.dart';

import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../calling/domain/repositories/lead_call_activity_repository.dart';
import '../../../calling/domain/repositories/lead_follow_up_repository.dart';
import '../../../calling/presentation/screens/user_calling_workspace_screen.dart';
import '../../../inventory/domain/repositories/inventory_repository.dart';
import '../../../inventory/presentation/screens/inventory_workspace_screen.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import '../widgets/crm_app_header.dart';
import '../widgets/crm_module_card.dart';
import 'module_placeholder_screen.dart';
import 'user_lead_placeholder_screen.dart';

/// Dynamic User Dashboard rendering only the modules assigned to the user.
///
/// Administrative sections (e.g. Users & Access) are strictly excluded.
class UserDashboardScreen extends StatelessWidget {
  final CurrentUser user;
  final VoidCallback onLogout;
  final UserLeadLinkRepository userLeadLinkRepository;
  final LeadRepository leadRepository;
  final LeadCallActivityRepository callActivityRepository;
  final LeadFollowUpRepository leadFollowUpRepository;
  final InventoryRepository inventoryRepository;

  const UserDashboardScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.userLeadLinkRepository,
    required this.leadRepository,
    required this.callActivityRepository,
    required this.leadFollowUpRepository,
    required this.inventoryRepository,
  });

  void _openModule(BuildContext context, CrmModule module) {
    if (module == CrmModule.leadManagement) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserLeadPlaceholderScreen(
            user: user,
            linkRepository: userLeadLinkRepository,
            leadRepository: leadRepository,
            callActivityRepository: callActivityRepository,
            leadFollowUpRepository: leadFollowUpRepository,
          ),
        ),
      );
    } else if (module == CrmModule.calling) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserCallingWorkspaceScreen(
            user: user,
            leadRepository: leadRepository,
            linkRepository: userLeadLinkRepository,
            callActivityRepository: callActivityRepository,
            leadFollowUpRepository: leadFollowUpRepository,
          ),
        ),
      );
    } else if (module == CrmModule.inventory) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InventoryWorkspaceScreen(
            user: user,
            repository: inventoryRepository,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ModulePlaceholderScreen(module: module, user: user),
        ),
      );
    }
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
        : 3;

    // Filter modules to only those assigned to the current user
    final assignedModules = CrmModule.values
        .where((module) => user.modules.contains(module))
        .toList();

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
                          'USER DASHBOARD',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome, ${user.displayName}. Access your assigned enterprise workspaces below.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Section Header
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'ASSIGNED MODULES',
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
                                '${assignedModules.length}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (assignedModules.isEmpty)
                          Card(
                            key: const Key('user_no_modules_card'),
                            elevation: 0,
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'No modules have been assigned to your account.',
                                      key: Key('user_no_modules_message'),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'No modules are currently assigned to this account.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          GridView.builder(
                            key: const Key('user_assigned_modules_grid'),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  mainAxisExtent: 160,
                                ),
                            itemCount: assignedModules.length,
                            itemBuilder: (context, index) {
                              final module = assignedModules[index];
                              return CrmModuleCard(
                                module: module,
                                onTap: () => _openModule(context, module),
                              );
                            },
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
