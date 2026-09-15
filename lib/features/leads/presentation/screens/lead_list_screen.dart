import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_assignee.dart';
import '../../domain/entities/lead_query.dart';
import '../../domain/repositories/lead_repository.dart';
import '../utils/lead_sort_display.dart';
import '../bloc/lead_filter_cubit.dart';
import '../bloc/lead_filter_state.dart';
import '../bloc/lead_list_cubit.dart';
import '../bloc/lead_list_state.dart';
import '../widgets/lead_active_filters.dart';
import '../widgets/lead_data_table.dart';
import '../widgets/lead_filter_sheet.dart';
import '../widgets/lead_list_card.dart';
import '../widgets/lead_pagination_controls.dart';

class LeadListScreen extends StatelessWidget {
  final LeadListCubit? cubit;
  final LeadRepository? repository;
  final LeadFilterCubit? filterCubit;
  final void Function(Lead lead)? onViewLead;
  final VoidCallback? onAddLead;
  final VoidCallback? onImportLeads;

  const LeadListScreen({
    super.key,
    this.cubit,
    this.repository,
    this.filterCubit,
    this.onViewLead,
    this.onAddLead,
    this.onImportLeads,
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
          ),
        );
      }
      return BlocProvider.value(
        value: listCubit,
        child: _LeadListView(
          onViewLead: onViewLead,
          onAddLead: onAddLead,
          onImportLeads: onImportLeads,
        ),
      );
    }

    if (repo != null) {
      return MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => LeadListCubit(repo)..loadLeads()),
          BlocProvider(
            create: (_) =>
                filterC ?? (LeadFilterCubit(repo)..loadAssignableUsers()),
          ),
        ],
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
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<LeadListCubit>();
    _searchController = TextEditingController(
      text: cubit.currentQuery.searchText ?? '',
    );
    _searchController.addListener(_onSearchInputChanged);

    if (cubit.state is LeadListInitial) {
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

  void _performSearch() {
    final raw = _searchController.text;
    final trimmed = raw.trim();
    final cubit = context.read<LeadListCubit>();

    if (trimmed.isEmpty) {
      _clearSearch();
      return;
    }

    final newQuery = cubit.currentQuery.copyWith(searchText: trimmed, page: 1);
    cubit.applyQuery(newQuery);
  }

  void _clearSearch() {
    _searchController.clear();
    final cubit = context.read<LeadListCubit>();
    final newQuery = cubit.currentQuery.copyWith(clearSearch: true, page: 1);
    cubit.applyQuery(newQuery);
  }

  void _clearFilters() {
    final cubit = context.read<LeadListCubit>();
    final newQuery = cubit.currentQuery.copyWith(
      clearSource: true,
      clearIsAssigned: true,
      clearAssignedUser: true,
      page: 1,
    );
    cubit.applyQuery(newQuery);
  }

  void _removeSourceFilter() {
    final cubit = context.read<LeadListCubit>();
    final newQuery = cubit.currentQuery.copyWith(clearSource: true, page: 1);
    cubit.applyQuery(newQuery);
  }

  void _removeAssignmentFilter() {
    final cubit = context.read<LeadListCubit>();
    final newQuery = cubit.currentQuery.copyWith(
      clearIsAssigned: true,
      page: 1,
    );
    cubit.applyQuery(newQuery);
  }

  void _removeAssigneeFilter() {
    final cubit = context.read<LeadListCubit>();
    final newQuery = cubit.currentQuery.copyWith(
      clearAssignedUser: true,
      page: 1,
    );
    cubit.applyQuery(newQuery);
  }

  void _onPreviousPage(int currentPage) {
    if (currentPage <= 1) return;
    final cubit = context.read<LeadListCubit>();
    final newQuery = cubit.currentQuery.copyWith(page: currentPage - 1);
    cubit.applyQuery(newQuery);
  }

  void _onNextPage(int currentPage) {
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
      onApply: (newQuery) {
        cubit.applyQuery(newQuery);
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
      body: BlocConsumer<LeadListCubit, LeadListState>(
        listener: (context, state) {
          final queryText = _getQueryFromState(state).searchText ?? '';
          if (_searchController.text != queryText && queryText.isEmpty) {
            _searchController.text = '';
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
        query.isAssigned != null ||
        query.assignedUserId != null;

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
                  return LeadListCard(
                    lead: state.leads[index],
                    onViewLead: widget.onViewLead,
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
