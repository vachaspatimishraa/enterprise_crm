import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/lead_export_file_saver.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_assignee.dart';
import '../../domain/entities/lead_query.dart';
import '../../domain/repositories/lead_repository.dart';
import '../utils/lead_sort_display.dart';
import '../bloc/lead_filter_cubit.dart';
import '../bloc/lead_filter_state.dart';
import '../bloc/lead_list_cubit.dart';
import '../bloc/lead_list_state.dart';
import '../widgets/bulk_assign_leads_dialog.dart';
import '../widgets/lead_active_filters.dart';
import '../widgets/lead_data_table.dart';
import '../widgets/lead_export_dialog.dart';
import '../widgets/lead_filter_sheet.dart';
import '../widgets/lead_list_card.dart';
import '../widgets/lead_pagination_controls.dart';
import '../services/lead_import_file_picker.dart';
import 'lead_import_workflow_screen.dart';

class LeadListScreen extends StatelessWidget {
  final LeadListCubit? cubit;
  final LeadRepository? repository;
  final LeadFilterCubit? filterCubit;
  final void Function(Lead lead)? onViewLead;
  final VoidCallback? onAddLead;
  final VoidCallback? onImportLeads;
  final LeadImportFilePicker? filePicker;
  final LeadExportFileSaver? exportFileSaver;
  final bool isDistributionMode;
  final LeadQuery? initialQuery;

  const LeadListScreen({
    super.key,
    this.cubit,
    this.repository,
    this.filterCubit,
    this.onViewLead,
    this.onAddLead,
    this.onImportLeads,
    this.filePicker,
    this.exportFileSaver,
    this.isDistributionMode = false,
    this.initialQuery,
  });

  @override
  Widget build(BuildContext context) {
    final listCubit = cubit;
    final repo = repository;
    final filterC = filterCubit;

    if (listCubit != null) {
      if (filterC != null) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: listCubit),
            BlocProvider.value(value: filterC),
          ],
          child: _LeadListView(
            onViewLead: onViewLead,
            onAddLead: onAddLead,
            onImportLeads: onImportLeads,
            repository: repo,
            filePicker: filePicker,
            exportFileSaver: exportFileSaver,
            isDistributionMode: isDistributionMode,
            initialQuery: initialQuery,
          ),
        );
      }
      if (repo != null) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: listCubit),
            BlocProvider(
              create: (_) => LeadFilterCubit(repo)..loadAssignableUsers(),
            ),
          ],
          child: _LeadListView(
            onViewLead: onViewLead,
            onAddLead: onAddLead,
            onImportLeads: onImportLeads,
            repository: repo,
            filePicker: filePicker,
            exportFileSaver: exportFileSaver,
            isDistributionMode: isDistributionMode,
            initialQuery: initialQuery,
          ),
        );
      }
      return BlocProvider.value(
        value: listCubit,
        child: _LeadListView(
          onViewLead: onViewLead,
          onAddLead: onAddLead,
          onImportLeads: onImportLeads,
          repository: repo,
          filePicker: filePicker,
          exportFileSaver: exportFileSaver,
          isDistributionMode: isDistributionMode,
          initialQuery: initialQuery,
        ),
      );
    }

    if (repo != null) {
      final effectiveInitialQuery =
          initialQuery ??
          (isDistributionMode
              ? const LeadQuery(isAssigned: false)
              : const LeadQuery());
      return MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                LeadListCubit(repo, initialQuery: effectiveInitialQuery)
                  ..loadLeads(),
          ),
          BlocProvider(
            create: (_) =>
                filterC ?? (LeadFilterCubit(repo)..loadAssignableUsers()),
          ),
        ],
        child: _LeadListView(
          onViewLead: onViewLead,
          onAddLead: onAddLead,
          onImportLeads: onImportLeads,
          repository: repo,
          filePicker: filePicker,
          exportFileSaver: exportFileSaver,
          isDistributionMode: isDistributionMode,
          initialQuery: initialQuery,
        ),
      );
    }

    return _LeadListView(
      onViewLead: onViewLead,
      onAddLead: onAddLead,
      onImportLeads: onImportLeads,
      repository: repo,
      filePicker: filePicker,
      exportFileSaver: exportFileSaver,
      isDistributionMode: isDistributionMode,
      initialQuery: initialQuery,
    );
  }
}

class _LeadListView extends StatefulWidget {
  final void Function(Lead lead)? onViewLead;
  final VoidCallback? onAddLead;
  final VoidCallback? onImportLeads;
  final LeadRepository? repository;
  final LeadImportFilePicker? filePicker;
  final LeadExportFileSaver? exportFileSaver;
  final bool isDistributionMode;
  final LeadQuery? initialQuery;

  const _LeadListView({
    this.onViewLead,
    this.onAddLead,
    this.onImportLeads,
    this.repository,
    this.filePicker,
    this.exportFileSaver,
    this.isDistributionMode = false,
    this.initialQuery,
  });

  @override
  State<_LeadListView> createState() => _LeadListViewState();
}

class _LeadListViewState extends State<_LeadListView> {
  late final TextEditingController _searchController;
  bool _isSelectionMode = false;
  final Set<String> _selectedLeadIds = {};
  bool _didAssignAnyLeads = false;

  @override
  void initState() {
    super.initState();
    _isSelectionMode = widget.isDistributionMode;
    final cubit = context.read<LeadListCubit>();
    _searchController = TextEditingController(
      text: cubit.currentQuery.searchText ?? '',
    );
    _searchController.addListener(_onSearchInputChanged);

    if (widget.isDistributionMode && cubit.currentQuery.isAssigned != false) {
      cubit.applyQuery(cubit.currentQuery.copyWith(isAssigned: false));
    } else if (widget.initialQuery != null &&
        cubit.currentQuery != widget.initialQuery) {
      cubit.applyQuery(widget.initialQuery!);
    } else if (cubit.state is LeadListInitial) {
      cubit.loadLeads();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchInputChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchInputChanged() {
    setState(() {});
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedLeadIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedLeadIds.clear();
    });
  }

  void _clearSelection() {
    if (_selectedLeadIds.isNotEmpty) {
      setState(() {
        _selectedLeadIds.clear();
      });
    }
  }

  void _toggleLeadSelection(Lead lead) {
    if (lead.isAssigned) return;
    setState(() {
      if (_selectedLeadIds.contains(lead.id)) {
        _selectedLeadIds.remove(lead.id);
      } else {
        _selectedLeadIds.add(lead.id);
      }
    });
  }

  void _toggleSelectAll(List<Lead> visibleLeads) {
    final eligible = visibleLeads.where((l) => !l.isAssigned).toList();
    if (eligible.isEmpty) return;

    final allSelected = eligible.every((l) => _selectedLeadIds.contains(l.id));
    setState(() {
      if (allSelected) {
        for (final l in eligible) {
          _selectedLeadIds.remove(l.id);
        }
      } else {
        for (final l in eligible) {
          _selectedLeadIds.add(l.id);
        }
      }
    });
  }

  bool _isAllEligibleSelected(List<Lead> visibleLeads) {
    final eligible = visibleLeads.where((l) => !l.isAssigned).toList();
    if (eligible.isEmpty) return false;
    return eligible.every((l) => _selectedLeadIds.contains(l.id));
  }

  Future<void> _openBulkAssignDialog(List<Lead> visibleLeads) async {
    final selectedLeads = visibleLeads
        .where((l) => _selectedLeadIds.contains(l.id))
        .toList();

    if (selectedLeads.isEmpty) return;

    // Defensive check: ensure no assigned leads slip into the batch
    if (selectedLeads.any((l) => l.isAssigned)) {
      setState(() {
        _selectedLeadIds.removeWhere((id) {
          final l = visibleLeads.where((lead) => lead.id == id).firstOrNull;
          return l == null || l.isAssigned;
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot assign already-assigned Leads.')),
      );
      return;
    }

    LeadRepository? repo = widget.repository;
    if (repo == null) {
      try {
        repo = context.read<LeadRepository>();
      } catch (_) {}
    }

    if (repo == null) {
      _showComingSoon(context, 'Assign Leads');
      return;
    }

    final leadsSnapshot = List<Lead>.unmodifiable(selectedLeads);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          BulkAssignLeadsDialog(leads: leadsSnapshot, repository: repo!),
    );

    if (result == true && mounted) {
      _didAssignAnyLeads = true;
      if (widget.isDistributionMode) {
        _clearSelection();
      } else {
        _exitSelectionMode();
      }
      context.read<LeadListCubit>().refreshLeads();
    }
  }

  void _performSearch() {
    _clearSelection();
    final raw = _searchController.text;
    final trimmed = raw.trim();
    final cubit = context.read<LeadListCubit>();

    if (trimmed.isEmpty) {
      _clearSearch();
      return;
    }

    final newQuery = cubit.currentQuery.copyWith(
      searchText: trimmed,
      page: 1,
      isAssigned: widget.isDistributionMode ? false : null,
    );
    cubit.applyQuery(newQuery);
  }

  void _clearSearch() {
    _clearSelection();
    _searchController.clear();
    final cubit = context.read<LeadListCubit>();
    final newQuery = cubit.currentQuery.copyWith(
      clearSearch: true,
      page: 1,
      isAssigned: widget.isDistributionMode ? false : null,
    );
    cubit.applyQuery(newQuery);
  }

  void _clearFilters() {
    _clearSelection();
    final cubit = context.read<LeadListCubit>();
    final newQuery = cubit.currentQuery.copyWith(
      clearSource: true,
      clearIsAssigned: !widget.isDistributionMode,
      isAssigned: widget.isDistributionMode ? false : null,
      clearAssignedUser: true,
      page: 1,
    );
    cubit.applyQuery(newQuery);
  }

  void _removeSourceFilter() {
    _clearSelection();
    final cubit = context.read<LeadListCubit>();
    final newQuery = cubit.currentQuery.copyWith(clearSource: true, page: 1);
    cubit.applyQuery(newQuery);
  }

  void _removeAssignmentFilter() {
    if (widget.isDistributionMode) return;
    _clearSelection();
    final cubit = context.read<LeadListCubit>();
    final newQuery = cubit.currentQuery.copyWith(
      clearIsAssigned: true,
      page: 1,
    );
    cubit.applyQuery(newQuery);
  }

  void _removeAssigneeFilter() {
    _clearSelection();
    final cubit = context.read<LeadListCubit>();
    final newQuery = cubit.currentQuery.copyWith(
      clearAssignedUser: true,
      page: 1,
    );
    cubit.applyQuery(newQuery);
  }

  void _onPreviousPage(int currentPage) {
    if (currentPage <= 1) return;
    _clearSelection();
    final cubit = context.read<LeadListCubit>();
    final newQuery = cubit.currentQuery.copyWith(page: currentPage - 1);
    cubit.applyQuery(newQuery);
  }

  void _onNextPage(int currentPage) {
    _clearSelection();
    final cubit = context.read<LeadListCubit>();
    final newQuery = cubit.currentQuery.copyWith(page: currentPage + 1);
    cubit.applyQuery(newQuery);
  }

  void _openFilterModal() {
    LeadFilterCubit? filterCubit;
    try {
      filterCubit = context.read<LeadFilterCubit>();
    } catch (_) {}

    if (filterCubit == null) return;

    final cubit = context.read<LeadListCubit>();
    showLeadFilterModal(
      context: context,
      currentQuery: cubit.currentQuery,
      filterCubit: filterCubit,
      lockAssignmentToUnassigned: widget.isDistributionMode,
      onApply: (newQuery) {
        _clearSelection();
        cubit.applyQuery(
          widget.isDistributionMode
              ? newQuery.copyWith(isAssigned: false, clearAssignedUser: true)
              : newQuery,
        );
      },
    );
  }

  int _getActiveFilterCount(LeadQuery query) {
    var count = 0;
    if (query.source != null) count++;
    if (query.isAssigned != null) count++;
    if (query.assignedUserId != null) count++;
    return count;
  }

  void _showComingSoon(BuildContext context, String actionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$actionName will be connected in upcoming phases.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openImportWorkflow(BuildContext context) async {
    LeadRepository? repo = widget.repository;
    if (repo == null) {
      try {
        repo = context.read<LeadRepository>();
      } catch (_) {}
    }
    if (repo == null) {
      _showComingSoon(context, 'Import Leads');
      return;
    }

    final listCubit = context.read<LeadListCubit>();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LeadImportWorkflowScreen(
          repository: repo!,
          filePicker: widget.filePicker,
        ),
      ),
    );
    if (result == true && mounted) {
      listCubit.refreshLeads();
    }
  }

  Future<void> _openExportDialog() async {
    LeadRepository? repo = widget.repository;
    if (repo == null) {
      try {
        repo = context.read<LeadRepository>();
      } catch (_) {}
    }
    if (repo == null) {
      _showComingSoon(context, 'Export Leads');
      return;
    }

    LeadExportFileSaver? saver = widget.exportFileSaver;
    if (saver == null) {
      try {
        saver = context.read<LeadExportFileSaver>();
      } catch (_) {}
    }
    saver ??= const DefaultLeadExportFileSaver();

    final currentQuerySnapshot = _getQueryFromState(
      context.read<LeadListCubit>().state,
    );

    final result = await showLeadExportDialog(
      context: context,
      repository: repo,
      fileSaver: saver,
      query: currentQuerySnapshot,
      contextExplanation:
          'All Leads matching the current search and filters will be exported across all pages.',
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lead export saved.')));
    }
  }

  LeadQuery _getQueryFromState(LeadListState state) {
    return switch (state) {
      LeadListInitial() => context.read<LeadListCubit>().currentQuery,
      LeadListLoading(:final query) => query,
      LeadListLoaded(:final query) => query,
      LeadListEmpty(:final query) => query,
      LeadListFailure(:final query) => query,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: !widget.isDistributionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(_didAssignAnyLeads);
        }
      },
      child: Scaffold(
        appBar: _isSelectionMode
            ? AppBar(
                leadingWidth: 36,
                leading: IconButton(
                  key: const Key('lead_list_cancel_selection_button'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel Selection',
                  onPressed: _exitSelectionMode,
                ),
                titleSpacing: 4,
                title: Text(
                  '${_selectedLeadIds.length} selected',
                  key: const Key('lead_list_selected_count'),
                  style: const TextStyle(fontSize: 14),
                ),
                actions: [
                  BlocBuilder<LeadListCubit, LeadListState>(
                    builder: (context, state) {
                      final leads = state is LeadListLoaded
                          ? state.leads
                          : <Lead>[];
                      final hasEligible = leads.any((l) => !l.isAssigned);
                      final allSelected = _isAllEligibleSelected(leads);

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            key: const Key('lead_list_select_all_button'),
                            onPressed: hasEligible
                                ? () => _toggleSelectAll(leads)
                                : null,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              allSelected ? 'Deselect All' : 'Select All',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8, left: 2),
                            child: FilledButton(
                              key: const Key('lead_list_assign_leads_button'),
                              onPressed: _selectedLeadIds.isNotEmpty
                                  ? () => _openBulkAssignDialog(leads)
                                  : null,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text(
                                'Assign Leads',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              )
            : AppBar(
                titleSpacing: 4,
                title: Text(
                  widget.isDistributionMode ? 'Distribute Leads' : 'Leads',
                ),
                actions: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh Leads',
                    onPressed: () {
                      context.read<LeadListCubit>().refreshLeads();
                    },
                  ),
                  IconButton(
                    key: const Key('lead_list_select_mode_button'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: const Icon(Icons.checklist),
                    tooltip: 'Select Leads',
                    onPressed: _enterSelectionMode,
                  ),
                  if (!widget.isDistributionMode) ...[
                    IconButton(
                      key: const Key('lead_list_import_button'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(Icons.upload_file),
                      tooltip: 'Import Leads',
                      onPressed:
                          widget.onImportLeads ??
                          () => _openImportWorkflow(context),
                    ),
                    IconButton(
                      key: const Key('lead_list_export_button'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(Icons.download_outlined),
                      tooltip: 'Export Leads',
                      onPressed: _openExportDialog,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 2, right: 4),
                      child: FilledButton.icon(
                        onPressed:
                            widget.onAddLead ??
                            () => _showComingSoon(context, 'Add Lead'),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Lead'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
        body: BlocConsumer<LeadListCubit, LeadListState>(
          listener: (context, state) {
            final queryText = _getQueryFromState(state).searchText ?? '';
            if (_searchController.text != queryText && queryText.isEmpty) {
              _searchController.text = '';
            }
            if (state is LeadListLoaded) {
              _selectedLeadIds.removeWhere((id) {
                final lead = state.leads.where((l) => l.id == id).firstOrNull;
                return lead == null || lead.isAssigned;
              });
            } else {
              _clearSelection();
            }
          },
          builder: (context, state) {
            final currentQuery = _getQueryFromState(state);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchAndFilterBar(
                  context,
                  theme,
                  colorScheme,
                  currentQuery,
                ),
                Expanded(
                  child: switch (state) {
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
                    LeadListEmpty(:final query) => _buildEmptyState(
                      context,
                      theme,
                      query,
                    ),
                    LeadListFailure(:final message) => _buildFailureState(
                      context,
                      theme,
                      message,
                    ),
                    LeadListLoaded() => _buildLoadedList(
                      context,
                      theme,
                      colorScheme,
                      state,
                    ),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    LeadQuery query,
  ) {
    final activeSearch = query.searchText?.trim();
    final hasActiveSearch = activeSearch != null && activeSearch.isNotEmpty;
    final filterCount = _getActiveFilterCount(query);

    List<LeadAssignee> assignees = const [];
    try {
      final filterState = context.watch<LeadFilterCubit>().state;
      if (filterState is LeadFilterReady) {
        assignees = filterState.assignees;
      }
    } catch (_) {}

    return LayoutBuilder(
      builder: (context, constraints) {
        final filterButton = OutlinedButton.icon(
          key: const Key('lead_filter_button'),
          onPressed: _openFilterModal,
          icon: Badge(
            isLabelVisible: filterCount > 0,
            label: Text('$filterCount'),
            child: const Icon(Icons.tune, size: 18),
          ),
          label: Text(filterCount > 0 ? 'Filters ($filterCount)' : 'Filters'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            visualDensity: VisualDensity.compact,
          ),
        );

        final currentSortIndex = leadSortOptions.indexOf(query.sort);
        final sortButton = PopupMenuButton<int>(
          key: const Key('lead_sort_button'),
          initialValue: currentSortIndex >= 0 ? currentSortIndex : 0,
          tooltip: 'Sort Leads',
          onSelected: (int selectedIndex) {
            _clearSelection();
            final selectedSort = leadSortOptions[selectedIndex];
            final cubit = context.read<LeadListCubit>();
            final newQuery = cubit.currentQuery.copyWith(
              sort: selectedSort,
              clearSort: selectedSort == null,
              page: 1,
            );
            cubit.applyQuery(newQuery);
          },
          itemBuilder: (context) => [
            for (var i = 0; i < leadSortOptions.length; i++)
              PopupMenuItem<int>(
                key: Key(
                  'lead_sort_option_${leadSortToDisplayName(leadSortOptions[i])}',
                ),
                value: i,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(leadSortToDisplayName(leadSortOptions[i])),
                    ),
                    if (query.sort == leadSortOptions[i])
                      Icon(Icons.check, size: 18, color: colorScheme.primary),
                  ],
                ),
              ),
          ],
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline.withAlpha(128)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sort, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Sort: ${leadSortToDisplayName(query.sort)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        );

        final searchField = TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _performSearch(),
          decoration: InputDecoration(
            hintText: 'Search leads by name, phone, or email',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: _performSearch,
            ),
            suffixIcon: (_searchController.text.isNotEmpty || hasActiveSearch)
                ? IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear Search',
                    onPressed: _clearSearch,
                  )
                : null,
          ),
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, hasActiveSearch ? 4 : 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (constraints.maxWidth >= 900)
                Row(
                  children: [
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: searchField,
                      ),
                    ),
                    const SizedBox(width: 12),
                    filterButton,
                    const SizedBox(width: 12),
                    sortButton,
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    if (constraints.maxWidth < 600)
                      Row(
                        children: [
                          Expanded(child: filterButton),
                          const SizedBox(width: 8),
                          Expanded(child: sortButton),
                        ],
                      )
                    else
                      Row(
                        children: [
                          filterButton,
                          const SizedBox(width: 8),
                          sortButton,
                        ],
                      ),
                  ],
                ),
              if (hasActiveSearch)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Results for "$activeSearch"',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _clearSearch,
                        child: Text(
                          'Clear',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              LeadActiveFilters(
                query: query,
                assignees: assignees,
                isAssignmentLocked: widget.isDistributionMode,
                onRemoveSource: _removeSourceFilter,
                onRemoveAssignment: _removeAssignmentFilter,
                onRemoveAssignee: _removeAssigneeFilter,
                onClearAll: _clearFilters,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
    LeadQuery query,
  ) {
    final isSearchActive =
        query.searchText != null && query.searchText!.trim().isNotEmpty;
    final hasFiltersActive =
        query.source != null ||
        (!widget.isDistributionMode && query.isAssigned != null) ||
        query.assignedUserId != null;

    if (widget.isDistributionMode && !hasFiltersActive && !isSearchActive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
              ),
              const SizedBox(height: 16),
              Text(
                'No unassigned leads available',
                key: const Key('empty_unassigned_leads_title'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'All leads have been assigned or no leads are available.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (isSearchActive && hasFiltersActive) {
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
                'No leads match your search and filters',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Try changing your search terms or clearing filters.',
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
                  OutlinedButton.icon(
                    key: const Key('empty_clear_filters_button'),
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off),
                    label: const Text('Clear Filters'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('empty_clear_search_button'),
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Search'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (hasFiltersActive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_off_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
              ),
              const SizedBox(height: 16),
              Text(
                'No leads match these filters',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Try changing or clearing your filters.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const Key('empty_clear_filters_button'),
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Clear Filters'),
              ),
            ],
          ),
        ),
      );
    }

    if (isSearchActive) {
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
                'No matching leads',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No leads match "${query.searchText}".\nTry a different name, phone number, or email.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const Key('empty_clear_search_button'),
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear),
                label: const Text('Clear Search'),
              ),
            ],
          ),
        ),
      );
    }

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
                      () => _openImportWorkflow(context),
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
                context.read<LeadListCubit>().refreshLeads();
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
    LeadListLoaded state,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final contentWidget = isMobile
            ? ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.leads.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final lead = state.leads[index];
                  return LeadListCard(
                    lead: lead,
                    onViewLead: widget.onViewLead,
                    isSelectionMode: _isSelectionMode,
                    isSelected: _selectedLeadIds.contains(lead.id),
                    onSelectChanged: (_) => _toggleLeadSelection(lead),
                  );
                },
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: double.infinity,
                    child: LeadDataTable(
                      leads: state.leads,
                      onViewLead: widget.onViewLead,
                      isSelectionMode: _isSelectionMode,
                      selectedLeadIds: _selectedLeadIds,
                      onToggleSelect: _toggleLeadSelection,
                      onSelectAll: (_) => _toggleSelectAll(state.leads),
                      allEligibleSelected: _isAllEligibleSelected(state.leads),
                    ),
                  ),
                ),
              );

        return Column(
          children: [
            Expanded(child: contentWidget),
            LeadPaginationControls(
              currentPage: state.currentPage,
              pageSize: state.pageSize,
              totalItems: state.totalItems,
              hasNext: state.hasNext,
              onPrevious: state.currentPage > 1
                  ? () => _onPreviousPage(state.currentPage)
                  : null,
              onNext: state.hasNext
                  ? () => _onNextPage(state.currentPage)
                  : null,
            ),
          ],
        );
      },
    );
  }
}
