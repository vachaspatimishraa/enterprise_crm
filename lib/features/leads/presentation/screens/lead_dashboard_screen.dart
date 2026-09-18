import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/lead_repository.dart';
import '../bloc/lead_dashboard_cubit.dart';
import '../bloc/lead_dashboard_state.dart';
import '../widgets/lead_quick_action.dart';
import '../widgets/lead_summary_card.dart';
import 'lead_import_workflow_screen.dart';
import 'lead_list_screen.dart';

class LeadDashboardScreen extends StatelessWidget {
  final LeadDashboardCubit? cubit;
  final LeadRepository? repository;
  final VoidCallback? onViewLeads;
  final VoidCallback? onAddLead;
  final VoidCallback? onImportLeads;
  final VoidCallback? onDistributeLeads;
  final VoidCallback? onExportLeads;

  const LeadDashboardScreen({
    super.key,
    this.cubit,
    this.repository,
    this.onViewLeads,
    this.onAddLead,
    this.onImportLeads,
    this.onDistributeLeads,
    this.onExportLeads,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _LeadDashboardView(
          onViewLeads: onViewLeads,
          onAddLead: onAddLead,
          onImportLeads: onImportLeads,
          onDistributeLeads: onDistributeLeads,
          onExportLeads: onExportLeads,
          repository: repository,
        ),
      );
    }

    if (repository != null) {
      return BlocProvider(
        create: (_) => LeadDashboardCubit(repository!)..loadDashboard(),
        child: _LeadDashboardView(
          onViewLeads: onViewLeads,
          onAddLead: onAddLead,
          onImportLeads: onImportLeads,
          onDistributeLeads: onDistributeLeads,
          onExportLeads: onExportLeads,
          repository: repository,
        ),
      );
    }

    // Attempt to use already provided Cubit from ancestor context
    return _LeadDashboardView(
      onViewLeads: onViewLeads,
      onAddLead: onAddLead,
      onImportLeads: onImportLeads,
      onDistributeLeads: onDistributeLeads,
      onExportLeads: onExportLeads,
      repository: repository,
    );
  }
}

class _LeadDashboardView extends StatelessWidget {
  final VoidCallback? onViewLeads;
  final VoidCallback? onAddLead;
  final VoidCallback? onImportLeads;
  final VoidCallback? onDistributeLeads;
  final VoidCallback? onExportLeads;
  final LeadRepository? repository;

  const _LeadDashboardView({
    this.onViewLeads,
    this.onAddLead,
    this.onImportLeads,
    this.onDistributeLeads,
    this.onExportLeads,
    this.repository,
  });

  void _showComingSoon(BuildContext context, String actionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$actionName will be connected in upcoming phases.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openImportWorkflow(BuildContext context) async {
    LeadRepository? repo = repository;
    if (repo == null) {
      try {
        repo = context.read<LeadRepository>();
      } catch (_) {}
    }
    if (repo == null) {
      _showComingSoon(context, 'Import Leads');
      return;
    }

    final dashboardCubit = context.read<LeadDashboardCubit>();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LeadImportWorkflowScreen(repository: repo!),
      ),
    );
    if (result == true && context.mounted) {
      dashboardCubit.loadDashboard();
    }
  }

  Future<void> _openDistributeLeads(BuildContext context) async {
    LeadRepository? repo = repository;
    if (repo == null) {
      try {
        repo = context.read<LeadRepository>();
      } catch (_) {}
    }
    if (repo == null) {
      _showComingSoon(context, 'Distribute Leads');
      return;
    }

    final dashboardCubit = context.read<LeadDashboardCubit>();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            LeadListScreen(repository: repo, isDistributionMode: true),
      ),
    );
    if (result == true && context.mounted) {
      dashboardCubit.loadDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Dashboard',
            onPressed: () {
              context.read<LeadDashboardCubit>().loadDashboard();
            },
          ),
        ],
      ),
      body: BlocBuilder<LeadDashboardCubit, LeadDashboardState>(
        builder: (context, state) {
          return switch (state) {
            LeadDashboardInitial() => const Center(
              child: CircularProgressIndicator(),
            ),
            LeadDashboardLoading() => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading lead summary...'),
                ],
              ),
            ),
            LeadDashboardEmpty() => _buildEmptyState(context, theme),
            LeadDashboardFailure(:final message) => _buildFailureState(
              context,
              theme,
              message,
            ),
            LeadDashboardLoaded(:final metrics) => _buildLoadedDashboard(
              context,
              theme,
              metrics,
            ),
          };
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
            ),
            const SizedBox(height: 16),
            Text(
              'No leads yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a lead manually or import leads from Excel/CSV.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed:
                      onAddLead ?? () => _showComingSoon(context, 'Add Lead'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Lead'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      onImportLeads ?? () => _openImportWorkflow(context),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import Leads'),
                ),
              ],
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
              'Failed to load metrics',
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
                context.read<LeadDashboardCubit>().loadDashboard();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedDashboard(
    BuildContext context,
    ThemeData theme,
    LeadSummaryMetrics metrics,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 960;
        final columns = isMobile
            ? 2
            : isTablet
            ? 3
            : 3;
        final childAspectRatio = constraints.maxWidth < 360
            ? 1.15
            : isMobile
            ? 1.3
            : isTablet
            ? 1.35
            : 1.6;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Overview & Summary',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Real-time distribution of leads and intake channels',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Summary Cards Grid
              GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
                children: [
                  LeadSummaryCard(
                    title: 'Total Leads',
                    count: metrics.totalLeads,
                    icon: Icons.people_alt_outlined,
                    accentColor: theme.colorScheme.primary,
                  ),
                  LeadSummaryCard(
                    title: 'Assigned Leads',
                    count: metrics.assignedLeads,
                    icon: Icons.assignment_ind_outlined,
                    accentColor: Colors.teal,
                  ),
                  LeadSummaryCard(
                    title: 'Unassigned Leads',
                    count: metrics.unassignedLeads,
                    icon: Icons.person_add_disabled_outlined,
                    accentColor: Colors.deepOrange,
                  ),
                  LeadSummaryCard(
                    title: 'Manual Leads',
                    count: metrics.manualLeads,
                    icon: Icons.edit_note_outlined,
                    accentColor: Colors.purple,
                  ),
                  LeadSummaryCard(
                    title: 'Excel Leads',
                    count: metrics.excelLeads,
                    icon: Icons.table_chart_outlined,
                    accentColor: Colors.green,
                  ),
                  LeadSummaryCard(
                    title: 'CSV Leads',
                    count: metrics.csvLeads,
                    icon: Icons.insert_drive_file_outlined,
                    accentColor: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Quick Actions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  LeadQuickAction(
                    label: 'View Leads',
                    icon: Icons.list_alt_outlined,
                    isPrimary: true,
                    onPressed:
                        onViewLeads ??
                        () => _showComingSoon(context, 'View Leads'),
                  ),
                  LeadQuickAction(
                    label: 'Add Lead',
                    icon: Icons.add_outlined,
                    onPressed:
                        onAddLead ?? () => _showComingSoon(context, 'Add Lead'),
                  ),
                  LeadQuickAction(
                    label: 'Import Leads',
                    icon: Icons.upload_file_outlined,
                    onPressed:
                        onImportLeads ?? () => _openImportWorkflow(context),
                  ),
                  LeadQuickAction(
                    label: 'Distribute Leads',
                    icon: Icons.alt_route_outlined,
                    onPressed:
                        onDistributeLeads ??
                        () => _openDistributeLeads(context),
                  ),
                  LeadQuickAction(
                    label: 'Export Leads',
                    icon: Icons.download_outlined,
                    onPressed:
                        onExportLeads ??
                        () => _showComingSoon(context, 'Export Leads'),
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
