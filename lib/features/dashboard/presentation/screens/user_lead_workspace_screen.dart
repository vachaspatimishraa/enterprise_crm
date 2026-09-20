import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../auth/presentation/mappers/crm_permission_presentation.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../../leads/domain/entities/lead.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import '../bloc/user_assigned_leads_cubit.dart';
import '../bloc/user_assigned_leads_state.dart';

/// Permission-aware Lead Management workspace for standard users.
///
/// This widget is render-only. All authorization checks, identity resolution,
/// assignee validation, and lead loading are delegated to
/// [UserAssignedLeadsCubit].
///
/// The screen is strictly read-only. No editing, creation, assignment,
/// reassignment, import, or export controls are present in AUTH-3B.1.
class UserLeadWorkspaceScreen extends StatelessWidget {
  final CurrentUser user;
  final UserLeadLinkRepository linkRepository;
  final LeadRepository leadRepository;

  const UserLeadWorkspaceScreen({
    super.key,
    required this.user,
    required this.linkRepository,
    required this.leadRepository,
  });

  @override
  Widget build(BuildContext context) {
    // Route guard at the widget layer — protects against direct navigation.
    if (!AccessPolicy.canAccessModule(user, CrmModule.leadManagement)) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider(
      create: (_) => UserAssignedLeadsCubit(
        user: user,
        linkRepository: linkRepository,
        leadRepository: leadRepository,
      )..load(),
      child: _UserLeadWorkspaceView(user: user),
    );
  }
}

class _UserLeadWorkspaceView extends StatelessWidget {
  final CurrentUser user;
  const _UserLeadWorkspaceView({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final canView =
        AccessPolicy.hasPermission(user, CrmPermissions.leadViewAssigned);
    final canUpdate =
        AccessPolicy.hasPermission(user, CrmPermissions.leadUpdate);
    final hasAnyLeadPermission = canView || canUpdate;

    return Scaffold(
      key: const Key('user_lead_workspace_screen'),
      appBar: AppBar(title: const Text('Lead Management'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── AUTH-3A: Capability summary ──────────────────────────
                _CapabilityCard(
                  user: user,
                  colorScheme: colorScheme,
                  theme: theme,
                  hasAnyLeadPermission: hasAnyLeadPermission,
                  canView: canView,
                  canUpdate: canUpdate,
                ),
                const SizedBox(height: 20),

                // ── AUTH-3B.1: Assigned leads list ───────────────────────
                if (canView) ...[
                  _SectionHeader(
                    label: 'MY ASSIGNED LEADS',
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  const _AssignedLeadsBody(),
                ],

                const SizedBox(height: 24),
                OutlinedButton.icon(
                  key: const Key('user_lead_back_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _SectionHeader({
    required this.label,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.assignment_ind_outlined,
            size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── AUTH-3A capability card ────────────────────────────────────────────────

class _CapabilityCard extends StatelessWidget {
  final CurrentUser user;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final bool hasAnyLeadPermission;
  final bool canView;
  final bool canUpdate;

  const _CapabilityCard({
    required this.user,
    required this.colorScheme,
    required this.theme,
    required this.hasAnyLeadPermission,
    required this.canView,
    required this.canUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'YOUR ACCESS',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!hasAnyLeadPermission) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You have access to this module, but no Lead actions have been assigned to your account.',
                        key: const Key('user_lead_no_actions_message'),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Contact an administrator to assign lead permissions.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ] else ...[
              if (canView)
                _CapabilityItem(
                  icon: Icons.check_circle_outline,
                  label: CrmPermissionPresentation.displayNameFor(
                    CrmPermissions.leadViewAssigned,
                  ),
                  itemKey: const Key('lead_perm_view_assigned'),
                  color: colorScheme.primary,
                ),
              if (canView && canUpdate) const SizedBox(height: 8),
              if (canUpdate)
                _CapabilityItem(
                  icon: Icons.check_circle_outline,
                  label: CrmPermissionPresentation.displayNameFor(
                    CrmPermissions.leadUpdate,
                  ),
                  itemKey: const Key('lead_perm_update'),
                  color: colorScheme.primary,
                ),
              // Case D: update-without-view warning
              if (!canView && canUpdate) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 20, color: colorScheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Viewing leads requires the view permission. Operational lead screens are unavailable without view permission.',
                          key: const Key(
                              'user_lead_update_without_view_warning'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ── Assigned leads Cubit consumer ─────────────────────────────────────────

class _AssignedLeadsBody extends StatelessWidget {
  const _AssignedLeadsBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserAssignedLeadsCubit, UserAssignedLeadsState>(
      builder: (context, state) => switch (state) {
        UserAssignedLeadsLoading() => const Center(
            key: Key('user_assigned_leads_loading'),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(),
            ),
          ),
        UserAssignedLeadsNoLink() => _InfoPanel(
            key: const Key('user_assigned_leads_no_link'),
            icon: Icons.link_off,
            message:
                'Your account has not been linked to a lead assignee identity.',
            hint: 'Contact an administrator to configure your lead identity.',
          ),
        UserAssignedLeadsInvalidLink() => _InfoPanel(
            key: const Key('user_assigned_leads_invalid_link'),
            icon: Icons.warning_amber_rounded,
            message:
                'Lead assignment identity is not configured correctly for this account.',
            hint: 'Contact an administrator.',
            isWarning: true,
          ),
        UserAssignedLeadsEmpty() => _InfoPanel(
            key: const Key('user_assigned_leads_empty'),
            icon: Icons.inbox_outlined,
            message: 'No leads are currently assigned to you.',
            hint: 'Check back later or contact your administrator.',
          ),
        UserAssignedLeadsLoaded(:final leads) => _LeadList(leads: leads),
        UserAssignedLeadsFailure(:final message) => _FailurePanel(
            key: const Key('user_assigned_leads_failure'),
            message: message,
            onRetry: () =>
                context.read<UserAssignedLeadsCubit>().retry(),
          ),
      },
    );
  }
}

// ── Info / warning panels ──────────────────────────────────────────────────

class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String message;
  final String hint;
  final bool isWarning;

  const _InfoPanel({
    super.key,
    required this.icon,
    required this.message,
    required this.hint,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final color =
        isWarning ? colorScheme.error : colorScheme.onSurfaceVariant;
    final bg = isWarning
        ? colorScheme.errorContainer.withValues(alpha: 0.3)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWarning
              ? colorScheme.error.withValues(alpha: 0.4)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(hint,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FailurePanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FailurePanel({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoPanel(
          icon: Icons.error_outline,
          message: message,
          hint: 'Tap retry to try again.',
          isWarning: true,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('user_assigned_leads_retry'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

// ── Read-only lead list ────────────────────────────────────────────────────

class _LeadList extends StatelessWidget {
  final List<Lead> leads;
  const _LeadList({required this.leads});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('user_assigned_leads_list'),
      children: [
        for (final lead in leads) ...[
          _LeadCard(lead: lead),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Lead lead;
  const _LeadCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName =
        (lead.name?.trim().isNotEmpty ?? false) ? lead.name! : 'Unnamed Lead';

    return Card(
      key: Key('lead_card_${lead.id}'),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (lead.phone != null || lead.email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      lead.phone ?? lead.email ?? '',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            if (lead.status != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lead.status!.value,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable capability row ────────────────────────────────────────────────

class _CapabilityItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Key itemKey;
  final Color color;

  const _CapabilityItem({
    required this.icon,
    required this.label,
    required this.itemKey,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            key: itemKey,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
