import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../notifications/domain/services/notification_dispatcher.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_source.dart';
import '../../domain/repositories/lead_comment_repository.dart';
import '../../domain/repositories/lead_repository.dart';
import '../bloc/lead_assignment_cubit.dart';
import '../bloc/lead_assignment_state.dart';
import '../bloc/lead_details_cubit.dart';
import '../bloc/lead_details_state.dart';
import '../bloc/lead_reassignment_cubit.dart';
import '../bloc/lead_reassignment_state.dart';
import '../utils/lead_display_formatters.dart';
import '../widgets/lead_assignee_selector.dart';
import '../widgets/lead_comments_section.dart';
import '../widgets/lead_reassignment_assignee_selector.dart';

class LeadDetailsScreen extends StatelessWidget {
  final String leadId;
  final LeadDetailsCubit? cubit;
  final LeadRepository? repository;
  final LeadCommentRepository? commentRepository;
  final void Function(Lead lead)? onEditLead;
  final VoidCallback? onLeadAssigned;

  const LeadDetailsScreen({
    super.key,
    required this.leadId,
    this.cubit,
    this.repository,
    this.commentRepository,
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
          commentRepository: commentRepository,
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
          commentRepository: commentRepository,
          onEditLead: onEditLead,
          onLeadAssigned: onLeadAssigned,
        ),
      );
    }

    return _LeadDetailsView(
      key: ValueKey(leadId),
      leadId: leadId,
      repository: repository,
      commentRepository: commentRepository,
      onEditLead: onEditLead,
      onLeadAssigned: onLeadAssigned,
    );
  }
}

class _LeadDetailsView extends StatefulWidget {
  final String leadId;
  final LeadRepository? repository;
  final LeadCommentRepository? commentRepository;
  final void Function(Lead lead)? onEditLead;
  final VoidCallback? onLeadAssigned;

  const _LeadDetailsView({
    super.key,
    required this.leadId,
    this.repository,
    this.commentRepository,
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

  String _resolveAuthorName(BuildContext context) {
    try {
      final authState = context.read<AuthCubit?>()?.state;
      if (authState is AuthAuthenticated) {
        return authState.user.displayName;
      }
    } catch (_) {}
    return 'Admin';
  }

  String? _resolveAuthorId(BuildContext context) {
    try {
      final authState = context.read<AuthCubit?>()?.state;
      if (authState is AuthAuthenticated) {
        return authState.user.id;
      }
    } catch (_) {}
    return null;
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

    NotificationDispatcher? dispatcher;
    try {
      dispatcher = context.read<NotificationDispatcher>();
    } catch (_) {}

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BlocProvider(
          create: (_) => LeadAssignmentCubit(
            repo!,
            notificationDispatcher: dispatcher,
          )..loadAssignableUsers(),
          child: _AssignLeadDialog(lead: lead),
        );
      },
    );

    if (result == true && mounted) {
      widget.onLeadAssigned?.call();
      context.read<LeadDetailsCubit>().loadLead(widget.leadId);
    }
  }

  Future<void> _openReassignLeadDialog(Lead lead) async {
    LeadRepository? repo = widget.repository;
    if (repo == null) {
      try {
        repo = context.read<LeadRepository>();
      } catch (_) {}
    }

    if (repo == null) {
      _showComingSoon(context, 'Reassign Lead');
      return;
    }

    NotificationDispatcher? dispatcher;
    try {
      dispatcher = context.read<NotificationDispatcher>();
    } catch (_) {}

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BlocProvider(
          create: (_) => LeadReassignmentCubit(
            repo!,
            notificationDispatcher: dispatcher,
          )..loadAssignableUsers(),
          child: _ReassignLeadDialog(lead: lead),
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
      appBar: AppBar(title: const Text('Lead Details')),
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

        final isDark = theme.brightness == Brightness.dark;
        Color sourceBg;
        Color sourceFg;
        IconData sourceIcon;
        switch (lead.source) {
          case LeadSource.portal:
            sourceBg = isDark
                ? Colors.teal.shade900.withAlpha(120)
                : Colors.teal.shade50;
            sourceFg = isDark ? Colors.teal.shade200 : Colors.teal.shade800;
            sourceIcon = Icons.language_outlined;
            break;
          case LeadSource.metaCampaign:
            sourceBg = isDark
                ? Colors.indigo.shade900.withAlpha(120)
                : Colors.indigo.shade50;
            sourceFg =
                isDark ? Colors.indigo.shade200 : Colors.indigo.shade800;
            sourceIcon = Icons.campaign_outlined;
            break;
          case LeadSource.excel:
            sourceBg = isDark
                ? Colors.green.shade900.withAlpha(120)
                : Colors.green.shade50;
            sourceFg = isDark ? Colors.green.shade200 : Colors.green.shade800;
            sourceIcon = Icons.table_chart_outlined;
            break;
          case LeadSource.csv:
            sourceBg = isDark
                ? Colors.blue.shade900.withAlpha(120)
                : Colors.blue.shade50;
            sourceFg = isDark ? Colors.blue.shade200 : Colors.blue.shade800;
            sourceIcon = Icons.insert_drive_file_outlined;
            break;
          case LeadSource.manual:
            sourceBg = colorScheme.surfaceContainerHighest;
            sourceFg = colorScheme.onSurfaceVariant;
            sourceIcon = Icons.edit_note_outlined;
            break;
        }

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
                      icon: sourceIcon,
                      backgroundColor: sourceBg,
                      foregroundColor: sourceFg,
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
                    if (lead.metadata?['priority'] != null &&
                        lead.metadata!['priority']!.trim().isNotEmpty) ...[
                      _DetailBadge(
                        label: lead.metadata!['priority']!.trim(),
                        icon: Icons.flag,
                        backgroundColor: lead.metadata!['priority']!
                                .toLowerCase()
                                .contains('hot')
                            ? (isDark
                                ? Colors.red.shade900.withAlpha(120)
                                : Colors.red.shade50)
                            : (lead.metadata!['priority']!
                                    .toLowerCase()
                                    .contains('warm')
                                ? (isDark
                                    ? Colors.orange.shade900.withAlpha(120)
                                    : Colors.orange.shade50)
                                : colorScheme.surfaceContainerHighest),
                        foregroundColor: lead.metadata!['priority']!
                                .toLowerCase()
                                .contains('hot')
                            ? (isDark
                                ? Colors.red.shade200
                                : Colors.red.shade800)
                            : (lead.metadata!['priority']!
                                    .toLowerCase()
                                    .contains('warm')
                                ? (isDark
                                    ? Colors.orange.shade200
                                    : Colors.orange.shade800)
                                : colorScheme.onSurfaceVariant),
                        maxWidth: maxBadgeWidth,
                      ),
                    ],
                    if (lead.metadata?['source_detail'] != null &&
                        lead.metadata!['source_detail']!.trim().isNotEmpty) ...[
                      _DetailBadge(
                        label: lead.metadata!['source_detail']!.trim(),
                        icon: Icons.explore_outlined,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurfaceVariant,
                        maxWidth: maxBadgeWidth,
                      ),
                    ],
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
            if (lead.businessName != null && lead.businessName!.trim().isNotEmpty)
              _DetailRow(label: 'Business Name', value: lead.businessName!.trim()),
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
            if ((lead.city != null && lead.city!.trim().isNotEmpty) ||
                (lead.state != null && lead.state!.trim().isNotEmpty) ||
                (lead.metadata?['country'] != null &&
                    lead.metadata!['country']!.trim().isNotEmpty))
              _DetailRow(
                label: 'Location',
                value: [
                  lead.city?.trim(),
                  lead.state?.trim(),
                  lead.metadata?['country']?.trim(),
                ]
                    .where((e) => e != null && e.isNotEmpty)
                    .join(', '),
                icon: Icons.location_on_outlined,
              ),
          ],
        );

        final hasMetadata =
            lead.metadata != null && lead.metadata!.isNotEmpty;
        final metadataSection = hasMetadata
            ? _DetailSection(
                title: 'Attribution & Ingestion Details',
                icon: lead.source == LeadSource.metaCampaign
                    ? Icons.campaign_outlined
                    : Icons.hub_outlined,
                children: _buildMetadataRows(lead.metadata!),
              )
            : null;

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
            if (lead.isAssigned) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('reassign_lead_button'),
                  onPressed: () => _openReassignLeadDialog(lead),
                  icon: const Icon(Icons.sync_alt_outlined, size: 18),
                  label: const Text('Reassign Lead'),
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
              value: formatLeadDateTime(lead.createdAt),
            ),
            _DetailRow(
              label: 'Updated At',
              value: formatLeadDateTime(lead.updatedAt),
            ),
          ],
        );

        final commentsSection = LeadCommentsSection(
          leadId: lead.id,
          currentUserName: _resolveAuthorName(context),
          currentUserId: _resolveAuthorId(context),
          repository: widget.commentRepository,
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
                if (metadataSection != null) ...[
                  const SizedBox(height: 16),
                  metadataSection,
                ],
                const SizedBox(height: 16),
                leadInfoSection,
                const SizedBox(height: 16),
                assignmentSection,
                const SizedBox(height: 16),
                recordSection,
                const SizedBox(height: 16),
                commentsSection,
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
                        if (metadataSection != null) ...[
                          const SizedBox(height: 16),
                          metadataSection,
                        ],
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
                        const SizedBox(height: 16),
                        commentsSection,
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

  List<Widget> _buildMetadataRows(Map<String, String> metadata) {
    const keyLabels = <String, String>{
      'channel': 'Channel',
      'campaignName': 'Campaign Name',
      'campaign_name': 'Campaign Name',
      'campaignId': 'Campaign ID',
      'campaign_id': 'Campaign ID',
      'adName': 'Ad Name',
      'ad_name': 'Ad Name',
      'adId': 'Ad ID',
      'ad_id': 'Ad ID',
      'formId': 'Form ID',
      'form_id': 'Form ID',
      'platform': 'Ad Platform',
      'leadId': 'Ad Lead ID',
      'lead_id': 'Ad Lead ID',
      'leadgenId': 'Meta Lead ID',
      'leadgen_id': 'Meta Lead ID',
      'portalName': 'Portal Name',
      'portal_name': 'Portal Name',
      'portalUrl': 'Portal URL',
      'portal_url': 'Portal URL',
      'utmSource': 'UTM Source',
      'utm_source': 'UTM Source',
      'utmMedium': 'UTM Medium',
      'utm_medium': 'UTM Medium',
      'utmCampaign': 'UTM Campaign',
      'utm_campaign': 'UTM Campaign',
      'utmTerm': 'UTM Term',
      'utm_term': 'UTM Term',
      'utmContent': 'UTM Content',
      'utm_content': 'UTM Content',
      'submittedAt': 'Submission Time',
      'submitted_at': 'Submission Time',
      'createdTime': 'Meta Ingestion Time',
      'created_time': 'Meta Ingestion Time',
      'source_detail': 'Source Detail',
      'sourceDetail': 'Source Detail',
      'priority': 'Lead Priority',
      'requirement': 'Requirement / Interest',
      'estimated_value': 'Estimated Value / Budget',
      'estimatedValue': 'Estimated Value / Budget',
      'notes': 'Notes / Remarks',
      'country': 'Country',
    };

    final rows = <Widget>[];
    for (final entry in metadata.entries) {
      if (entry.value.trim().isEmpty) continue;
      final label = keyLabels[entry.key] ?? _formatGenericKey(entry.key);
      rows.add(
        _DetailRow(
          label: label,
          value: entry.value.trim(),
          icon: _getMetadataIcon(entry.key),
        ),
      );
    }
    return rows;
  }

  static String _formatGenericKey(String key) {
    final spaced = key.replaceAllMapped(
      RegExp(r'(?<=[a-z])[A-Z]'),
      (m) => ' ${m.group(0)}',
    );
    return spaced
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  static IconData? _getMetadataIcon(String key) {
    final lower = key.toLowerCase().replaceAll('_', '');
    switch (lower) {
      case 'campaignname':
      case 'utmcampaign':
        return Icons.campaign_outlined;
      case 'adname':
        return Icons.ad_units_outlined;
      case 'portalname':
      case 'portalurl':
        return Icons.link_outlined;
      case 'utmsource':
        return Icons.track_changes_outlined;
      case 'leadgenid':
      case 'formid':
        return Icons.tag_outlined;
      case 'channel':
        return Icons.hub_outlined;
      case 'submittedat':
      case 'createdtime':
        return Icons.schedule_outlined;
      case 'notes':
        return Icons.notes_outlined;
      case 'requirement':
        return Icons.shopping_bag_outlined;
      case 'estimatedvalue':
        return Icons.payments_outlined;
      case 'priority':
        return Icons.flag_outlined;
      case 'sourcedetail':
        return Icons.explore_outlined;
      case 'country':
        return Icons.public_outlined;
      default:
        return Icons.info_outline;
    }
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

class _ReassignLeadDialog extends StatefulWidget {
  final Lead lead;

  const _ReassignLeadDialog({required this.lead});

  @override
  State<_ReassignLeadDialog> createState() => _ReassignLeadDialogState();
}

class _ReassignLeadDialogState extends State<_ReassignLeadDialog> {
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lead = widget.lead;

    return BlocConsumer<LeadReassignmentCubit, LeadReassignmentState>(
      listenWhen: (prev, curr) =>
          prev.submissionStatus != curr.submissionStatus,
      listener: (context, state) {
        if (state.isSubmissionSuccess) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final cubit = context.read<LeadReassignmentCubit>();
        final isSubmitting = state.isSubmitting;
        final currentAssigneeName = lead.assignedUserName ?? 'Unknown';

        final canSubmit =
            state.canSubmit &&
            state.selectedAssignee?.id != lead.assignedUserId &&
            !isSubmitting;

        return PopScope(
          canPop: !isSubmitting,
          child: AlertDialog(
            key: const Key('reassign_lead_dialog'),
            title: Row(
              children: [
                Icon(
                  Icons.sync_alt_outlined,
                  size: 22,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Reassign Lead', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Current Assignee
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current assignee:',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  currentAssigneeName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // New Assignee selector
                    Text(
                      'New assignee:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    LeadReassignmentAssigneeSelector(
                      cubit: cubit,
                      currentAssigneeId: lead.assignedUserId,
                      enabled: !isSubmitting,
                    ),
                    const SizedBox(height: 16),
                    // Reason (optional)
                    TextField(
                      key: const Key('reassign_dialog_reason_input'),
                      controller: _reasonController,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Reason (optional)',
                        hintText: 'e.g. Workload balancing, territory change',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 2,
                      minLines: 1,
                    ),
                    if (state.hasSubmissionError) ...[
                      const SizedBox(height: 12),
                      Container(
                        key: const Key('reassign_dialog_error'),
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
                                    'Unable to reassign the Lead.',
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
            ),
            actions: [
              TextButton(
                key: const Key('reassign_dialog_cancel_button'),
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('reassign_dialog_submit_button'),
                onPressed: canSubmit
                    ? () => cubit.reassignLead(
                        lead: lead,
                        reason: _reasonController.text,
                      )
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
                    : const Text('Reassign'),
              ),
            ],
          ),
        );
      },
    );
  }
}
