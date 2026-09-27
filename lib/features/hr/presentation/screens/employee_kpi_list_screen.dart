import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../data/repositories/mock_employee_repository.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_kpi.dart';
import '../../domain/policies/hr_access_policy.dart';
import '../../domain/repositories/employee_kpi_repository.dart';
import '../../domain/repositories/employee_repository.dart';
import '../bloc/employee_kpi_list_cubit.dart';
import '../bloc/employee_kpi_list_state.dart';
import 'add_employee_kpi_screen.dart';
import 'employee_kpi_details_screen.dart';

/// Screen displaying Employee Key Performance Indicators (KPIs).
///
/// Responsive: renders compact cards on mobile (<600px) and a structured table on desktop (>=600px).
/// Features:
/// - Repository-backed KPI listing (HR-5.3)
/// - Employee name resolution using [EmployeeRepository] (HR-5.3.4)
/// - Period selection with Q3 2026 and Custom Range (HR-5.4.2)
/// - Real-time case-insensitive search by metric or employee (HR-5.4.3)
/// - Employee and Metric filtering (HR-5.4.4)
/// - Clear/reset filter actions and distinguishable empty/no-results states (HR-5.4.6)
/// - Strict authorization route guard via [HrAccessPolicy] (HR-5.3.6)
class EmployeeKpiListScreen extends StatelessWidget {
  final CurrentUser user;
  final EmployeeKpiRepository kpiRepository;
  final EmployeeRepository? employeeRepository;
  final String? initialEmployeeId;

  const EmployeeKpiListScreen({
    super.key,
    required this.user,
    required this.kpiRepository,
    this.employeeRepository,
    this.initialEmployeeId,
  });

  @override
  Widget build(BuildContext context) {
    if (!HrAccessPolicy.canAccessModule(user) ||
        (!user.isAdmin && !HrAccessPolicy.canViewHrRecords(user))) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider(
      create: (_) => EmployeeKpiListCubit(
        repository: kpiRepository,
        initialEmployeeId: initialEmployeeId,
      )..loadKpis(),
      child: _EmployeeKpiListView(
        user: user,
        kpiRepository: kpiRepository,
        employeeRepository: employeeRepository ?? MockEmployeeRepository(),
      ),
    );
  }
}

class _EmployeeKpiListView extends StatefulWidget {
  final CurrentUser user;
  final EmployeeKpiRepository kpiRepository;
  final EmployeeRepository employeeRepository;

  const _EmployeeKpiListView({
    required this.user,
    required this.kpiRepository,
    required this.employeeRepository,
  });

  @override
  State<_EmployeeKpiListView> createState() => _EmployeeKpiListViewState();
}

class _EmployeeKpiListViewState extends State<_EmployeeKpiListView> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, String> _employeeNames = {};
  List<Employee> _employees = [];
  bool _isLoadingEmployees = true;

  // Pre-configured period definitions (HR-5.4.2)
  static final DateTime _q3Start = DateTime.utc(2026, 7, 1);
  static final DateTime _q3End = DateTime.utc(2026, 9, 30);

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final list = await widget.employeeRepository.getEmployees();
      if (!mounted) return;
      setState(() {
        _employees = list;
        _employeeNames = {for (final e in list) e.id: e.fullName};
        _isLoadingEmployees = false;
      });
      context.read<EmployeeKpiListCubit>().updateEmployeeNameMap(
        _employeeNames,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingEmployees = false);
      }
    }
  }

  String _resolveEmployeeName(String employeeId) {
    return _employeeNames[employeeId] ?? employeeId;
  }

  Future<void> _pickCustomDateRange() async {
    final cubit = context.read<EmployeeKpiListCubit>();
    final currentStart = cubit.state.startDate ?? DateTime.utc(2026, 7, 1);
    final currentEnd = cubit.state.endDate ?? DateTime.utc(2026, 9, 30);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: currentStart, end: currentEnd),
    );

    if (picked != null && mounted) {
      final normalizedStart = DateTime.utc(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      final normalizedEnd = DateTime.utc(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      );
      cubit.setDateRangeFilter(
        startDate: normalizedStart,
        endDate: normalizedEnd,
      );
    }
  }

  void _onSearchChanged(String query) {
    context.read<EmployeeKpiListCubit>().setSearchQuery(query);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<EmployeeKpiListCubit>().setSearchQuery('');
  }

  Future<void> _navigateToDetails(String kpiId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmployeeKpiDetailsScreen(
          user: widget.user,
          kpiId: kpiId,
          kpiRepository: widget.kpiRepository,
          employeeRepository: widget.employeeRepository,
        ),
      ),
    );
    if (mounted) {
      context.read<EmployeeKpiListCubit>().reload();
    }
  }

  Future<void> _navigateToAddKpi() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddEmployeeKpiScreen(
          user: widget.user,
          kpiRepository: widget.kpiRepository,
          employeeRepository: widget.employeeRepository,
        ),
      ),
    );
    if (result == true && mounted) {
      context.read<EmployeeKpiListCubit>().reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      key: const Key('employee_kpi_list_scaffold'),
      appBar: AppBar(
        title: const Text('KPI Management'),
        actions: [
          if (widget.user.isAdmin)
            IconButton(
              key: const Key('kpi_add_button'),
              tooltip: 'Add KPI',
              icon: const Icon(Icons.add),
              onPressed: _navigateToAddKpi,
            ),
          IconButton(
            key: const Key('kpi_refresh_button'),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<EmployeeKpiListCubit>().reload(),
          ),
        ],
      ),
      floatingActionButton: widget.user.isAdmin
          ? FloatingActionButton(
              key: const Key('kpi_add_fab'),
              tooltip: 'Add KPI',
              onPressed: _navigateToAddKpi,
              child: const Icon(Icons.add),
            )
          : null,
      body: BlocBuilder<EmployeeKpiListCubit, EmployeeKpiListState>(
        builder: (context, state) {
          return Column(
            children: [
              // Search & Filter Header
              _buildFilterSection(context, state, isDesktop),

              // Active Filters Chip Row
              _buildActiveFiltersRow(context, state),

              const Divider(height: 1),

              // Main Content Area
              Expanded(
                child: _buildBody(context, state, isDesktop, colorScheme),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterSection(
    BuildContext context,
    EmployeeKpiListState state,
    bool isDesktop,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          TextField(
            key: const Key('kpi_search_field'),
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by metric or employee...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      key: const Key('kpi_search_clear_button'),
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSearch,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          // Period & Filter Controls Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Period selection button
              OutlinedButton.icon(
                key: const Key('kpi_period_filter_button'),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  _formatActivePeriodLabel(state),
                  style: theme.textTheme.labelMedium,
                ),
                onPressed: () => _showPeriodSelectionModal(context, state),
              ),

              // Employee filter dropdown
              if (!_isLoadingEmployees && _employees.isNotEmpty)
                _buildEmployeeDropdown(context, state),

              // Reset filters button (if any filter is active)
              if (_hasActiveFilters(state))
                TextButton.icon(
                  key: const Key('kpi_reset_filters_button'),
                  icon: const Icon(Icons.filter_alt_off, size: 16),
                  label: const Text('Reset'),
                  onPressed: () {
                    _searchController.clear();
                    context.read<EmployeeKpiListCubit>().resetFilters();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatActivePeriodLabel(EmployeeKpiListState state) {
    if (state.startDate == null && state.endDate == null) {
      return 'All Periods';
    }
    if (state.startDate == _q3Start && state.endDate == _q3End) {
      return 'Q3 2026 (Jul–Sep)';
    }
    final s = state.startDate != null
        ? '${state.startDate!.year}-${state.startDate!.month.toString().padLeft(2, '0')}-${state.startDate!.day.toString().padLeft(2, '0')}'
        : 'Start';
    final e = state.endDate != null
        ? '${state.endDate!.year}-${state.endDate!.month.toString().padLeft(2, '0')}-${state.endDate!.day.toString().padLeft(2, '0')}'
        : 'End';
    return '$s – $e';
  }

  void _showPeriodSelectionModal(
    BuildContext context,
    EmployeeKpiListState state,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final cubit = context.read<EmployeeKpiListCubit>();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Evaluation Period',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  key: const Key('kpi_period_all'),
                  leading: const Icon(Icons.all_inclusive),
                  title: const Text('All Periods'),
                  selected: state.startDate == null && state.endDate == null,
                  onTap: () {
                    Navigator.pop(ctx);
                    cubit.setDateRangeFilter(startDate: null, endDate: null);
                  },
                ),
                ListTile(
                  key: const Key('kpi_period_q3_2026'),
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Q3 2026'),
                  subtitle: const Text('2026-07-01 – 2026-09-30'),
                  selected:
                      state.startDate == _q3Start && state.endDate == _q3End,
                  onTap: () {
                    Navigator.pop(ctx);
                    cubit.setDateRangeFilter(
                      startDate: _q3Start,
                      endDate: _q3End,
                    );
                  },
                ),
                ListTile(
                  key: const Key('kpi_period_custom'),
                  leading: const Icon(Icons.date_range),
                  title: const Text('Custom Date Range...'),
                  subtitle: const Text('Pick start and end dates'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickCustomDateRange();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmployeeDropdown(
    BuildContext context,
    EmployeeKpiListState state,
  ) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<String?>(
          key: const Key('kpi_employee_filter'),
          value: state.selectedEmployeeId,
          hint: const Text('All Employees'),
          isDense: true,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Employees'),
            ),
            ..._employees.map((e) {
              return DropdownMenuItem<String?>(
                key: Key('kpi_employee_item_${e.id}'),
                value: e.id,
                child: Text(e.fullName),
              );
            }),
          ],
          onChanged: (val) {
            context.read<EmployeeKpiListCubit>().setEmployeeFilter(val);
          },
        ),
      ),
    );
  }

  bool _hasActiveFilters(EmployeeKpiListState state) {
    return state.searchQuery.isNotEmpty ||
        state.selectedEmployeeId != null ||
        state.selectedMetric != null ||
        state.startDate != null ||
        state.endDate != null;
  }

  Widget _buildActiveFiltersRow(
    BuildContext context,
    EmployeeKpiListState state,
  ) {
    if (!_hasActiveFilters(state)) {
      return const SizedBox.shrink();
    }

    final cubit = context.read<EmployeeKpiListCubit>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          if (state.searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text('Query: "${state.searchQuery}"'),
                onDeleted: _clearSearch,
              ),
            ),
          if (state.selectedEmployeeId != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(
                  'Employee: ${_resolveEmployeeName(state.selectedEmployeeId!)}',
                ),
                onDeleted: () => cubit.setEmployeeFilter(null),
              ),
            ),
          if (state.startDate != null || state.endDate != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text('Period: ${_formatActivePeriodLabel(state)}'),
                onDeleted: () =>
                    cubit.setDateRangeFilter(startDate: null, endDate: null),
              ),
            ),
          if (state.selectedMetric != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text('Metric: ${state.selectedMetric}'),
                onDeleted: () => cubit.setSelectedMetric(null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    EmployeeKpiListState state,
    bool isDesktop,
    ColorScheme colorScheme,
  ) {
    switch (state.status) {
      case EmployeeKpiListStatus.initial:
      case EmployeeKpiListStatus.loading:
        return const Center(
          child: CircularProgressIndicator(key: Key('kpi_loading_indicator')),
        );

      case EmployeeKpiListStatus.failure:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  state.errorMessage ??
                      'Failed to load employee KPI records. Please try again.',
                  key: const Key('kpi_error_state'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  key: const Key('kpi_retry_button'),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: () =>
                      context.read<EmployeeKpiListCubit>().reload(),
                ),
              ],
            ),
          ),
        );

      case EmployeeKpiListStatus.loaded:
        if (state.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assessment_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No KPI records available.',
                    key: const Key('kpi_empty_state'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.isFilteredEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list_off,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No KPI records match your filters.',
                    key: const Key('kpi_no_results_state'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: const Key('kpi_clear_filters_button'),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Filters'),
                    onPressed: () {
                      _searchController.clear();
                      context.read<EmployeeKpiListCubit>().resetFilters();
                    },
                  ),
                ],
              ),
            ),
          );
        }

        if (isDesktop) {
          return _buildDesktopTable(context, state.filteredKpis, colorScheme);
        } else {
          return _buildMobileCardList(context, state.filteredKpis, colorScheme);
        }
    }
  }

  Widget _buildMobileCardList(
    BuildContext context,
    List<EmployeeKpi> kpis,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);

    return ListView.separated(
      key: const Key('kpi_mobile_list_view'),
      padding: const EdgeInsets.all(16),
      itemCount: kpis.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final kpi = kpis[index];
        final empName = _resolveEmployeeName(kpi.employeeId);

        return Card(
          key: Key('kpi_card_${kpi.id}'),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: InkWell(
            key: Key('kpi_card_tap_${kpi.id}'),
            onTap: () => _navigateToDetails(kpi.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Metric Name
                  Text(
                    kpi.metricName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Employee Name
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
                          empName,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Period
                  Row(
                    children: [
                      Icon(
                        Icons.date_range_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          kpi.formattedPeriod,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Metric Values Badge Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricStat('Target', '${kpi.targetValue}'),
                        _buildMetricStat('Actual', '${kpi.actualValue}'),
                        _buildMetricStat(
                          'Score',
                          kpi.score != null ? '${kpi.score}' : '—',
                        ),
                      ],
                    ),
                  ),

                  // Remarks if present
                  if (kpi.remarks != null &&
                      kpi.remarks!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Remarks: ${kpi.remarks}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(
    BuildContext context,
    List<EmployeeKpi> kpis,
    ColorScheme colorScheme,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          key: const Key('kpi_desktop_table_view'),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth - 32),
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
                columns: const [
                  DataColumn(label: Text('Metric')),
                  DataColumn(label: Text('Employee')),
                  DataColumn(label: Text('Period')),
                  DataColumn(label: Text('Target'), numeric: true),
                  DataColumn(label: Text('Actual'), numeric: true),
                  DataColumn(label: Text('Score'), numeric: true),
                  DataColumn(label: Text('Remarks')),
                ],
                rows: kpis.map((kpi) {
                  final empName = _resolveEmployeeName(kpi.employeeId);

                  return DataRow(
                    key: ValueKey('kpi_row_${kpi.id}'),
                    onSelectChanged: (_) => _navigateToDetails(kpi.id),
                    cells: [
                      DataCell(
                        Text(
                          kpi.metricName,
                          key: Key('kpi_row_${kpi.id}'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () => _navigateToDetails(kpi.id),
                      ),
                      DataCell(Text(empName)),
                      DataCell(Text(kpi.formattedPeriod)),
                      DataCell(Text('${kpi.targetValue}')),
                      DataCell(Text('${kpi.actualValue}')),
                      DataCell(Text(kpi.score != null ? '${kpi.score}' : '—')),
                      DataCell(
                        Text(
                          kpi.remarks ?? '—',
                          style: TextStyle(
                            fontStyle: kpi.remarks != null
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: kpi.remarks == null
                                ? colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
