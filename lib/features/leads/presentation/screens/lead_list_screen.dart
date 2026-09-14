import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/lead.dart';
import '../../domain/repositories/lead_repository.dart';
import '../bloc/lead_list_cubit.dart';
import '../bloc/lead_list_state.dart';
import '../widgets/lead_data_table.dart';
import '../widgets/lead_list_card.dart';

class LeadListScreen extends StatelessWidget {
  final LeadListCubit? cubit;
  final LeadRepository? repository;
  final void Function(Lead lead)? onViewLead;
  final VoidCallback? onAddLead;
  final VoidCallback? onImportLeads;

  const LeadListScreen({
    super.key,
    this.cubit,
    this.repository,
    this.onViewLead,
    this.onAddLead,
    this.onImportLeads,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _LeadListView(
          onViewLead: onViewLead,
          onAddLead: onAddLead,
          onImportLeads: onImportLeads,
        ),
      );
    }

    if (repository != null) {
      return BlocProvider(
        create: (_) => LeadListCubit(repository!)..loadLeads(),
        child: _LeadListView(
          onViewLead: onViewLead,
          onAddLead: onAddLead,
          onImportLeads: onImportLeads,
        ),
      );
    }

    return _LeadListView(
      onViewLead: onViewLead,
      onAddLead: onAddLead,
      onImportLeads: onImportLeads,
    );
  }
}

class _LeadListView extends StatefulWidget {
  final void Function(Lead lead)? onViewLead;
  final VoidCallback? onAddLead;
  final VoidCallback? onImportLeads;

  const _LeadListView({this.onViewLead, this.onAddLead, this.onImportLeads});

  @override
  State<_LeadListView> createState() => _LeadListViewState();
}

class _LeadListViewState extends State<_LeadListView> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<LeadListCubit>();
    if (cubit.state is LeadListInitial) {
      cubit.loadLeads();
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
        title: const Text('Leads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Leads',
            onPressed: () {
              context.read<LeadListCubit>().refreshLeads();
            },
          ),
          if (widget.onImportLeads != null)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Import Leads',
              onPressed: widget.onImportLeads,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              onPressed:
                  widget.onAddLead ??
                  () => _showComingSoon(context, 'Add Lead'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Lead'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: BlocBuilder<LeadListCubit, LeadListState>(
        builder: (context, state) {
          return switch (state) {
            LeadListInitial() => const Center(
              child: CircularProgressIndicator(),
            ),
            LeadListLoading() => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading leads...'),
                ],
              ),
            ),
            LeadListEmpty() => _buildEmptyState(context, theme),
            LeadListFailure(:final message) => _buildFailureState(
              context,
              theme,
              message,
            ),
            LeadListLoaded(:final leads) => _buildLoadedList(
              context,
              theme,
              colorScheme,
              leads,
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
              'No leads found',
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
                      widget.onAddLead ??
                      () => _showComingSoon(context, 'Add Lead'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Lead'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      widget.onImportLeads ??
                      () => _showComingSoon(context, 'Import Leads'),
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
              'Failed to load leads',
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
                context.read<LeadListCubit>().loadLeads();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedList(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    List<Lead> leads,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: leads.length,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return LeadListCard(
                lead: leads[index],
                onViewLead: widget.onViewLead,
              );
            },
          );
        }

        // Desktop / Tablet layout
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: double.infinity,
              child: LeadDataTable(leads: leads, onViewLead: widget.onViewLead),
            ),
          ),
        );
      },
    );
  }
}
