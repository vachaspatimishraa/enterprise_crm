import 'package:flutter/material.dart';
import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../../dashboard/presentation/screens/user_lead_workspace_screen.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import '../../domain/policies/user_calling_policy.dart';
import '../../domain/repositories/lead_call_activity_repository.dart';

/// Workspace screen for standard CRM users navigating into the Calling module.
///
/// Calling activities in CALL-1A are scoped to assigned Leads. Provides navigation
/// into [UserLeadWorkspaceScreen] while retaining all shared repository instances.
class UserCallingWorkspaceScreen extends StatelessWidget {
  final CurrentUser user;
  final LeadRepository leadRepository;
  final UserLeadLinkRepository linkRepository;
  final LeadCallActivityRepository callActivityRepository;

  const UserCallingWorkspaceScreen({
    super.key,
    required this.user,
    required this.leadRepository,
    required this.linkRepository,
    required this.callActivityRepository,
  });

  @override
  Widget build(BuildContext context) {
    if (!UserCallingPolicy.canUseCalling(user)) {
      return const AccessRestrictedScreen();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasLeadViewAccess =
        AccessPolicy.canAccessModule(user, CrmModule.leadManagement) &&
        AccessPolicy.hasPermission(user, CrmPermissions.leadViewAssigned);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calling'),
        leading: IconButton(
          key: const Key('user_calling_workspace_back_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 32 : 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isWide ? 32 : 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimaryContainer,
                              child: const Icon(Icons.phone_in_talk, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CALLING',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Calling access is enabled.',
                                    key: const Key(
                                      'user_calling_status_enabled',
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 24),
                        if (hasLeadViewAccess) ...[
                          Text(
                            'Call and follow-up activity is managed from your assigned Lead details.',
                            key: const Key(
                              'user_calling_manage_from_leads_message',
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const Key('user_calling_open_leads_button'),
                              icon: const Icon(Icons.people_outline, size: 18),
                              label: const Text('Open My Assigned Leads'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => UserLeadWorkspaceScreen(
                                      user: user,
                                      linkRepository: linkRepository,
                                      leadRepository: leadRepository,
                                      callActivityRepository:
                                          callActivityRepository,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ] else ...[
                          Container(
                            key: const Key(
                              'user_calling_no_lead_access_message',
                            ),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Calling access is enabled, but no Lead viewing access has been assigned to your account.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
