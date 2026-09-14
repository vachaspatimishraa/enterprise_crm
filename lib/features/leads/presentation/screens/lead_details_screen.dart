import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/lead.dart';
import '../../domain/repositories/lead_repository.dart';
import '../bloc/lead_details_cubit.dart';
import '../bloc/lead_details_state.dart';
import '../utils/lead_display_formatters.dart';

class LeadDetailsScreen extends StatelessWidget {
  final String leadId;
  final LeadDetailsCubit? cubit;
  final LeadRepository? repository;
  final void Function(Lead lead)? onEditLead;

  const LeadDetailsScreen({
    super.key,
    required this.leadId,
    this.cubit,
    this.repository,
    this.onEditLead,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _LeadDetailsView(leadId: leadId, onEditLead: onEditLead),
      );
    }

    if (repository != null) {
      return BlocProvider(
        create: (_) => LeadDetailsCubit(repository!)..loadLead(leadId),
        child: _LeadDetailsView(leadId: leadId, onEditLead: onEditLead),
      );
    }

    return _LeadDetailsView(leadId: leadId, onEditLead: onEditLead);
  }
}

class _LeadDetailsView extends StatefulWidget {
  final String leadId;
  final void Function(Lead lead)? onEditLead;

  const _LeadDetailsView({required this.leadId, this.onEditLead});

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

  void _showComingSoon(BuildContext context, String actionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$actionName will be connected in upcoming phases.'),
        duration: const Duration(seconds: 2),
      ),
    );
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
