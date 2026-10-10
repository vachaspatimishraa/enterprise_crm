import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../data/repositories/mock_attendance_repository.dart';
import '../../data/repositories/mock_employee_kpi_repository.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employment_status.dart';
import '../../domain/policies/hr_access_policy.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../domain/repositories/employee_document_repository.dart';
import '../../domain/repositories/employee_kpi_repository.dart';
import '../../domain/repositories/employee_repository.dart';
import '../bloc/employee_directory_cubit.dart';
import '../bloc/employee_directory_state.dart';
import 'add_employee_screen.dart';
import 'attendance_list_screen.dart';
import 'employee_details_screen.dart';
import 'employee_kpi_list_screen.dart';

/// Main Employee Directory workspace screen in the HR module.
///
/// Responsive: renders structured table on desktop (>=600px) and cards on mobile (<600px).
/// Guards: enforces module and view authorization before executing directory queries.
class EmployeeDirectoryScreen extends StatelessWidget {
  final CurrentUser user;
  final EmployeeRepository repository;
  final EmployeeDocumentRepository? documentRepository;
  final AttendanceRepository? attendanceRepository;
  final EmployeeKpiRepository? kpiRepository;

  const EmployeeDirectoryScreen({
    super.key,
    required this.user,
    required this.repository,
    this.documentRepository,
    this.attendanceRepository,
    this.kpiRepository,
  });

  @override
  Widget build(BuildContext context) {
    // Route guard: Non-authorized users are blocked immediately
    if (!HrAccessPolicy.canAccessModule(user)) {
      return const AccessRestrictedScreen();
    }

    if (!user.isAdmin && !HrAccessPolicy.canViewHrRecords(user)) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider(
      create: (_) =>
          EmployeeDirectoryCubit(repository: repository)..loadEmployees(),
      child: _EmployeeDirectoryView(
        user: user,
        repository: repository,
        documentRepository: documentRepository,
        attendanceRepository: attendanceRepository,
        kpiRepository: kpiRepository,
      ),
    );
  }
}

class _EmployeeDirectoryView extends StatefulWidget {
  final CurrentUser user;
  final EmployeeRepository repository;
  final EmployeeDocumentRepository? documentRepository;
  final AttendanceRepository? attendanceRepository;
  final EmployeeKpiRepository? kpiRepository;

  const _EmployeeDirectoryView({
    required this.user,
    required this.repository,
    this.documentRepository,
    this.attendanceRepository,
    this.kpiRepository,
  });

  @override
  State<_EmployeeDirectoryView> createState() => _EmployeeDirectoryViewState();
}

class _EmployeeDirectoryViewState extends State<_EmployeeDirectoryView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAddEmployee = widget.user.isAdmin;

    return Scaffold(
      key: const Key('employee_directory_scaffold'),
      appBar: AppBar(
        title: const Text('Employee Directory'),
        actions: [
          IconButton(
            key: const Key('employee_directory_attendance_button'),
            tooltip: 'Attendance Management',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AttendanceListScreen(
                    user: widget.user,
                    repository:
                        widget.attendanceRepository ??
                        MockAttendanceRepository(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            key: const Key('employee_directory_kpi_button'),
            tooltip: 'KPI Management',
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EmployeeKpiListScreen(
                    user: widget.user,
                    kpiRepository:
                        widget.kpiRepository ?? MockEmployeeKpiRepository(),
                    employeeRepository: widget.repository,
                  ),
                ),
              );
            },
          ),
          IconButton(
            key: const Key('employee_directory_refresh_button'),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<EmployeeDirectoryCubit>().refresh(),
          ),
        ],
      ),
      floatingActionButton: canAddEmployee
          ? FloatingActionButton.extended(
              key: const Key('employee_directory_add_button'),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add Employee'),
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AddEmployeeScreen(
                      user: widget.user,
                      repository: widget.repository,
                    ),
                  ),
                );
                if (created == true && context.mounted) {
                  context.read<EmployeeDirectoryCubit>().refresh();
                }
              },
            )
          : null,
      body: BlocBuilder<EmployeeDirectoryCubit, EmployeeDirectoryState>(
        builder: (context, state) {
          return Column(
            children: [
              _buildFilterHeader(context, state),
              Expanded(child: _buildBody(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterHeader(
    BuildContext context,
    EmployeeDirectoryState state,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('employee_search_field'),
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, code, dept, designation...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              key: const Key('employee_search_clear_button'),
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                context
                                    .read<EmployeeDirectoryCubit>()
                                    .setSearchQuery('');
                              },
                            )
                          : null,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {});
                      context.read<EmployeeDirectoryCubit>().setSearchQuery(
                        val,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Sort Dropdown
                PopupMenuButton<EmployeeSortOption>(
                  key: const Key('employee_sort_menu_button'),
                  tooltip: 'Sort options',
                  icon: const Icon(Icons.sort),
                  initialValue: state.sortOption,
                  onSelected: (option) => context
                      .read<EmployeeDirectoryCubit>()
                      .setSortOption(option),
                  itemBuilder: (context) => [
                    for (final opt in EmployeeSortOption.values)
                      PopupMenuItem(
                        value: opt,
                        child: Row(
                          children: [
                            if (state.sortOption == opt)
                              Icon(
                                Icons.check,
                                size: 16,
                                color: colorScheme.primary,
                              )
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            Text(opt.label),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Filter Chips (Status & Department)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Status chips
                  FilterChip(
                    key: const Key('employee_status_chip_all'),
                    label: const Text('All Statuses'),
                    selected: state.selectedStatus == null,
                    onSelected: (_) => context
                        .read<EmployeeDirectoryCubit>()
                        .setStatusFilter(null),
                  ),
                  const SizedBox(width: 8),
                  for (final status in [
                    EmploymentStatus.active,
                    EmploymentStatus.probation,
                    EmploymentStatus.inactive,
                  ]) ...[
                    FilterChip(
                      key: Key(
                        'employee_status_chip_${status.value.toLowerCase()}',
                      ),
                      label: Text(status.value),
                      selected: state.selectedStatus == status,
                      onSelected: (selected) {
                        context.read<EmployeeDirectoryCubit>().setStatusFilter(
                          selected ? status : null,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Divider
                  const SizedBox(height: 24, child: VerticalDivider(width: 16)),

                  // Department filter
                  if (state.availableDepartments.isNotEmpty) ...[
                    for (final dept in state.availableDepartments) ...[
                      FilterChip(
                        key: Key(
                          'employee_dept_chip_${dept.replaceAll(' ', '_')}',
                        ),
                        label: Text(dept),
                        selected: state.selectedDepartment == dept,
                        onSelected: (selected) {
                          context
                              .read<EmployeeDirectoryCubit>()
                              .setDepartmentFilter(selected ? dept : null);
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],

                  if (state.searchQuery.isNotEmpty ||
                      state.selectedDepartment != null ||
                      state.selectedStatus != null)
                    TextButton.icon(
                      key: const Key('employee_reset_filters_button'),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reset'),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        context.read<EmployeeDirectoryCubit>().resetFilters();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, EmployeeDirectoryState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('employee_directory_loading_indicator'),
        ),
      );
    }

    if (state.isFailure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
                key: Key('employee_directory_error_icon'),
              ),
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? 'An error occurred loading employees.',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('employee_directory_retry_button'),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () =>
                    context.read<EmployeeDirectoryCubit>().refresh(),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_search_outlined,
                size: 48,
                color: Colors.grey,
                key: Key('employee_directory_empty_icon'),
              ),
              const SizedBox(height: 12),
              const Text(
                'No employees found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Try clearing your search or filter options.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;
        return isDesktop
            ? _buildDesktopTable(context, state.filteredEmployees)
            : _buildMobileCards(context, state.filteredEmployees);
      },
    );
  }

  Widget _buildMobileCards(BuildContext context, List<Employee> employees) {
    return ListView.separated(
      key: const Key('employee_mobile_list'),
      padding: const EdgeInsets.all(16.0),
      itemCount: employees.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final emp = employees[index];
        return _EmployeeCard(
          key: Key('employee_card_${emp.id}'),
          employee: emp,
          onTap: () => _openDetails(context, emp.id),
        );
      },
    );
  }

  Widget _buildDesktopTable(BuildContext context, List<Employee> employees) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      key: const Key('employee_desktop_table_scroll'),
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('Code')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Department')),
              DataColumn(label: Text('Designation')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Action')),
            ],
            rows: [
              for (final emp in employees)
                DataRow(
                  key: ValueKey('employee_row_${emp.id}'),
                  onSelectChanged: (_) => _openDetails(context, emp.id),
                  cells: [
                    DataCell(
                      Text(
                        emp.employeeCode ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(Text(emp.fullName)),
                    DataCell(Text(emp.department ?? '—')),
                    DataCell(Text(emp.designation ?? '—')),
                    DataCell(_StatusBadge(status: emp.employmentStatus)),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 14),
                        onPressed: () => _openDetails(context, emp.id),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetails(BuildContext context, String employeeId) async {
    final modified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmployeeDetailsScreen(
          user: widget.user,
          employeeId: employeeId,
          repository: widget.repository,
          documentRepository: widget.documentRepository,
          attendanceRepository: widget.attendanceRepository,
        ),
      ),
    );
    if (modified == true && context.mounted) {
      context.read<EmployeeDirectoryCubit>().refresh();
    }
  }
}

class _EmployeeCard extends StatelessWidget {
  final Employee employee;
  final VoidCallback onTap;

  const _EmployeeCard({super.key, required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      employee.fullName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StatusBadge(status: employee.employmentStatus),
                ],
              ),
              const SizedBox(height: 6),
              if (employee.employeeCode != null)
                Text(
                  employee.employeeCode!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${employee.department ?? "General"} • ${employee.designation ?? "Staff"}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final EmploymentStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status.value.toLowerCase()) {
      'active' => Colors.green,
      'probation' => Colors.orange,
      'inactive' => Colors.grey,
      _ => Colors.blueGrey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.value,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
