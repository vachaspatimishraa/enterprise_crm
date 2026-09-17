import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/lead.dart';
import '../../domain/repositories/lead_repository.dart';
import '../bloc/lead_assignment_cubit.dart';
import '../bloc/lead_assignment_state.dart';
import '../bloc/lead_details_cubit.dart';
import '../bloc/lead_details_state.dart';
import '../utils/lead_display_formatters.dart';
import '../widgets/lead_assignee_selector.dart';

class LeadDetailsScreen extends StatelessWidget {
  final String leadId;
  final LeadDetailsCubit? cubit;
  final LeadRepository? repository;
  final void Function(Lead lead)? onEditLead;
  final VoidCallback? onLeadAssigned;

  const LeadDetailsScreen({
    super.key,
    required this.leadId,
    this.cubit,
    this.repository,
    this.onEditLead,
    this.onLeadAssigned,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        key: ValueKey(leadId),
        value: cubit!,
        child: _LeadDetailsView(
          leadId: leadId,
          repository: repository,
          onEditLead: onEditLead,
          onLeadAssigned: onLeadAssigned,
        ),
      );
    }

    if (repository != null) {
      return BlocProvider(
        key: ValueKey(leadId),
        create: (_) => LeadDetailsCubit(repository!)..loadLead(leadId),
        child: _LeadDetailsView(
          leadId: leadId,
          repository: repository,
          onEditLead: onEditLead,
          onLeadAssigned: onLeadAssigned,
        ),
      );
    }

    return _LeadDetailsView(
      key: ValueKey(leadId),
      leadId: leadId,
      repository: repository,
      onEditLead: onEditLead,
      onLeadAssigned: onLeadAssigned,
    );
  }
}

class _LeadDetailsView extends StatefulWidget {
  final String leadId;
  final LeadRepository? repository;
  final void Function(Lead lead)? onEditLead;
  final VoidCallback? onLeadAssigned;

  const _LeadDetailsView({
    super.key,
    required this.leadId,
    this.repository,
    this.onEditLead,
    this.onLeadAssigned,
  });

  @override
  State<_LeadDetailsView> createState() => _LeadDetailsViewState();
}

class _LeadDetailsViewState extends State<_LeadDetailsView> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<LeadDetailsCubit>();
    if (cubit.state is LeadDetailsInitial) {
      cubit.loadLead(widget.leadId);
    }
  }

  @override
  void didUpdateWidget(covariant _LeadDetailsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leadId != widget.leadId) {
      context.read<LeadDetailsCubit>().loadLead(widget.leadId);
    }
  }

  void _showComingSoon(BuildContext context, String actionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$actionName will be connected in upcoming phases.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openAssignLeadDialog(Lead lead) async {
    LeadRepository? repo = widget.repository;
    if (repo == null) {
      try {
        repo = context.read<LeadRepository>();
      } catch (_) {}
    }

    if (repo == null) {
      _showComingSoon(context, 'Assign Lead');
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BlocProvider(
          create: (_) => LeadAssignmentCubit(repo!)..loadAssignableUsers(),
          child: _AssignLeadDialog(lead: lead),
        );
      },
    );

    if (result == true && mounted) {
      widget.onLeadAssigned?.call();
      context.read<LeadDetailsCubit>().loadLead(widget.leadId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead Details'),
        actions: [
          BlocBuilder<LeadDetailsCubit, LeadDetailsState>(
            builder: (context, state) {
              if (state is LeadDetailsLoaded) {
                return IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Lead',
                  onPressed: widget.onEditLead != null
                      ? () => widget.onEditLead!(state.lead)
                      : () => _showComingSoon(context, 'Edit Lead'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<LeadDetailsCubit, LeadDetailsState>(
        builder: (context, state) {
          return switch (state) {
            LeadDetailsInitial() => const Center(
              child: CircularProgressIndicator(),
            ),
            LeadDetailsLoading() => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading lead details...'),
                ],
              ),
            ),
            LeadDetailsNotFound(:final leadId) => _buildNotFoundState(
              context,
              theme,
              leadId,
            ),
            LeadDetailsFailure(:final message) => _buildFailureState(
              context,
              theme,
              message,
            ),
            LeadDetailsLoaded(:final lead) => _buildLoadedView(
              context,
              theme,
              colorScheme,
              lead,
            ),
          };
        },
      ),
    );
  }

  Widget _buildNotFoundState(
    BuildContext context,
    ThemeData theme,
    String leadId,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
            ),
            const SizedBox(height: 16),
            Text(
              'Lead not found',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The requested lead could not be found.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'ID: $leadId',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                context.read<LeadDetailsCubit>().loadLead(widget.leadId);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureState(
    BuildContext context,
    ThemeData theme,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load lead',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                context.read<LeadDetailsCubit>().loadLead(widget.leadId);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedView(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    Lead lead,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final maxBadgeWidth = constraints.maxWidth > 72
            ? constraints.maxWidth - 72
            : 250.0;

        final headerCard = Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMobile) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          formatLeadName(lead.name),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: widget.onEditLead != null
                            ? () => widget.onEditLead!(lead)
                            : () => _showComingSoon(context, 'Edit Lead'),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Lead'),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    formatLeadName(lead.name),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DetailBadge(
                      label: formatLeadSource(lead.source),
                      icon: Icons.source_outlined,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      foregroundColor: colorScheme.onSurfaceVariant,
                      maxWidth: maxBadgeWidth,
                    ),
                    _DetailBadge(
                      label: formatLeadStatus(lead.status),
                      icon: Icons.flag_outlined,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      foregroundColor: colorScheme.onSurfaceVariant,
                      maxWidth: maxBadgeWidth,
                    ),
                    _DetailBadge(
                      label: formatLeadAssignee(lead),
                      icon: lead.isAssigned
                          ? Icons.person
                          : Icons.person_outline,
                      backgroundColor: lead.isAssigned
                          ? colorScheme.secondaryContainer
                          : colorScheme.surfaceContainerHighest,
                      foregroundColor: lead.isAssigned
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurfaceVariant,
                      maxWidth: maxBadgeWidth,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        final basicSection = _DetailSection(
          title: 'Basic Information',
          icon: Icons.badge_outlined,
          children: [
            _DetailRow(label: 'Lead Name', value: formatLeadName(lead.name)),
            _DetailRow(label: 'Lead ID', value: lead.id),
          ],
        );

        final contactSection = _DetailSection(
          title: 'Contact Information',
          icon: Icons.contact_phone_outlined,
          children: [
            _DetailRow(
              label: 'Phone',
              value: formatLeadPhone(lead.phone),
              icon: Icons.phone_outlined,
            ),
            _DetailRow(
              label: 'Email',
              value: formatLeadEmail(lead.email),
              icon: Icons.email_outlined,
            ),
          ],
        );

        final leadInfoSection = _DetailSection(
          title: 'Lead Information',
          icon: Icons.info_outline,
          children: [
            _DetailRow(label: 'Source', value: formatLeadSource(lead.source)),
            _DetailRow(label: 'Status', value: formatLeadStatus(lead.status)),
          ],
        );

        final assignmentSection = _DetailSection(
          title: 'Assignment',
          icon: Icons.assignment_ind_outlined,
          children: [
            _DetailRow(label: 'Assigned To', value: formatLeadAssignee(lead)),
            _DetailRow(
              label: 'Assignment State',
              value: lead.isAssigned ? 'Assigned' : 'Unassigned',
            ),
            if (!lead.isAssigned) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('assign_lead_button'),
                  onPressed: () => _openAssignLeadDialog(lead),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Assign Lead'),
                ),
              ),
            ],
          ],
        );

        final recordSection = _DetailSection(
          title: 'Record Information',
          icon: Icons.history_outlined,
          children: [
            _DetailRow(
              label: 'Created At',
              value: formatLeadDate(lead.createdAt),
            ),
            _DetailRow(
              label: 'Updated At',
              value: formatLeadDate(lead.updatedAt),
            ),
          ],
        );

        if (isMobile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                headerCard,
                const SizedBox(height: 16),
                basicSection,
                const SizedBox(height: 16),
                contactSection,
                const SizedBox(height: 16),
                leadInfoSection,
                const SizedBox(height: 16),
                assignmentSection,
                const SizedBox(height: 16),
                recordSection,
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onEditLead != null
                        ? () => widget.onEditLead!(lead)
                        : () => _showComingSoon(context, 'Edit Lead'),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Lead'),
                  ),
                ),
              ],
            ),
          );
        }

        // Desktop / Tablet layout: 2-column view
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              headerCard,
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        basicSection,
                        const SizedBox(height: 16),
                        contactSection,
                        const SizedBox(height: 16),
                        leadInfoSection,
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        assignmentSection,
                        const SizedBox(height: 16),
                        recordSection,
                      ],
                    ),
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

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const _DetailRow({required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final double? maxWidth;

  const _DetailBadge({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: maxWidth != null
          ? BoxConstraints(maxWidth: maxWidth!)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignLeadDialog extends StatelessWidget {
  final Lead lead;

  const _AssignLeadDialog({required this.lead});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocConsumer<LeadAssignmentCubit, LeadAssignmentState>(
      listenWhen: (prev, curr) =>
          prev.submissionStatus != curr.submissionStatus,
      listener: (context, state) {
        if (state.isSubmissionSuccess) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final cubit = context.read<LeadAssignmentCubit>();
        final isSubmitting = state.isSubmitting;

        return PopScope(
          canPop: !isSubmitting,
          child: AlertDialog(
            key: const Key('assign_lead_dialog'),
            title: Row(
              children: [
                Icon(
                  Icons.person_add_outlined,
                  size: 22,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Assign Lead', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select an agent to assign this lead to:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LeadAssigneeSelector(cubit: cubit, enabled: !isSubmitting),
                  if (state.hasSubmissionError) ...[
                    const SizedBox(height: 12),
                    Container(
                      key: const Key('assign_dialog_error'),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.submissionErrorMessage ??
                                  'Unable to assign the Lead.',
                              style: TextStyle(
                                color: colorScheme.error,
                                fontSize: 13,
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
            actions: [
              TextButton(
                key: const Key('assign_dialog_cancel_button'),
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('assign_dialog_submit_button'),
                onPressed: (state.canSubmit && !isSubmitting)
                    ? () => cubit.assignLead(lead: lead)
                    : null,
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Assign'),
              ),
            ],
          ),
        );
      },
    );
  }
}
