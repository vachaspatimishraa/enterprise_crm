import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../../leads/domain/entities/lead.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import '../../../leads/presentation/utils/lead_display_formatters.dart';
import '../bloc/user_lead_details_cubit.dart';
import '../bloc/user_lead_details_state.dart';
import 'user_edit_lead_screen.dart';

/// User-safe read-only Lead Details screen.
///
/// Driven entirely by [UserLeadDetailsCubit]. Renders [AccessRestrictedScreen]
/// if module, view permission, identity link, or assignee ownership checks fail.
/// Displays an [Edit Lead] action button only if `state.canEdit` is true.
class UserLeadDetailsScreen extends StatelessWidget {
  final CurrentUser user;
  final String leadId;
  final UserLeadLinkRepository linkRepository;
  final LeadRepository leadRepository;
  final UserLeadDetailsCubit? cubit;

  const UserLeadDetailsScreen({
    super.key,
    required this.user,
    required this.leadId,
    required this.linkRepository,
    required this.leadRepository,
    this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _UserLeadDetailsView(
          user: user,
          linkRepository: linkRepository,
          leadRepository: leadRepository,
        ),
      );
    }

    return BlocProvider(
      create: (_) => UserLeadDetailsCubit(
        user: user,
        linkRepository: linkRepository,
        leadRepository: leadRepository,
        leadId: leadId,
      )..loadLead(),
      child: _UserLeadDetailsView(
        user: user,
        linkRepository: linkRepository,
        leadRepository: leadRepository,
      ),
    );
  }
}

class _UserLeadDetailsView extends StatelessWidget {
  final CurrentUser user;
  final UserLeadLinkRepository linkRepository;
  final LeadRepository leadRepository;

  const _UserLeadDetailsView({
    required this.user,
    required this.linkRepository,
    required this.leadRepository,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserLeadDetailsCubit, UserLeadDetailsState>(
      builder: (context, state) {
        return switch (state) {
          UserLeadDetailsInitial() ||
          UserLeadDetailsLoading() => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                key: Key('user_lead_details_loading'),
              ),
            ),
          ),
          UserLeadDetailsAccessDenied() => const AccessRestrictedScreen(),
          UserLeadDetailsFailure(:final message) => Scaffold(
            appBar: AppBar(title: const Text('Lead Details')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          context.read<UserLeadDetailsCubit>().loadLead(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          UserLeadDetailsLoaded(:final lead, :final canEdit) =>
            _UserLeadDetailsContent(
              user: user,
              lead: lead,
              canEdit: canEdit,
              linkRepository: linkRepository,
              leadRepository: leadRepository,
            ),
        };
      },
    );
  }
}

class _UserLeadDetailsContent extends StatelessWidget {
  final CurrentUser user;
  final Lead lead;
  final bool canEdit;
  final UserLeadLinkRepository linkRepository;
  final LeadRepository leadRepository;

  const _UserLeadDetailsContent({
    required this.user,
    required this.lead,
    required this.canEdit,
    required this.linkRepository,
    required this.leadRepository,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = (lead.name?.trim().isNotEmpty ?? false)
        ? lead.name!
        : 'Unnamed Lead';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead Details'),
        leading: IconButton(
          key: const Key('user_lead_details_back_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (canEdit)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                key: const Key('user_lead_edit_button'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Lead'),
                onPressed: () async {
                  final updatedLead = await Navigator.of(context).push<Lead>(
                    MaterialPageRoute(
                      builder: (_) => UserEditLeadScreen(
                        user: user,
                        leadId: lead.id,
                        initialLead: lead,
                        linkRepository: linkRepository,
                        leadRepository: leadRepository,
                      ),
                    ),
                  );
                  if (updatedLead != null && context.mounted) {
                    context.read<UserLeadDetailsCubit>().refreshLead(
                      updatedLead,
                    );
                  }
                },
              ),
            ),
        ],
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
                constraints: const BoxConstraints(maxWidth: 720),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isWide ? 28 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Name + Status Badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimaryContainer,
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'L',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    key: const Key('user_lead_details_name'),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${lead.id}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (lead.status != null)
                              Container(
                                key: const Key('user_lead_details_status'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  lead.status!.value,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 20),

                        // Contact section
                        Text(
                          'Contact Information',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: lead.phone ?? 'Not provided',
                          valueKey: const Key('user_lead_details_phone'),
                        ),
                        const SizedBox(height: 8),
                        _DetailRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: lead.email ?? 'Not provided',
                          valueKey: const Key('user_lead_details_email'),
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 20),

                        // Assignment & Source section
                        Text(
                          'Assignment & Origin',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.person_outline,
                          label: 'Assigned To',
                          value: formatLeadAssignee(lead),
                          valueKey: const Key('user_lead_details_assignee'),
                        ),
                        const SizedBox(height: 8),
                        _DetailRow(
                          icon: Icons.source_outlined,
                          label: 'Source',
                          value: formatLeadSource(lead.source),
                          valueKey: const Key('user_lead_details_source'),
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 20),

                        // Timestamps section
                        Text(
                          'Record Timestamps',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Created',
                          value: formatLeadDate(lead.createdAt),
                          valueKey: const Key('user_lead_details_created'),
                        ),
                        const SizedBox(height: 8),
                        _DetailRow(
                          icon: Icons.update_outlined,
                          label: 'Last Updated',
                          value: formatLeadDate(lead.updatedAt),
                          valueKey: const Key('user_lead_details_updated'),
                        ),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Key? valueKey;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            key: valueKey,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
