import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/policies/hr_access_policy.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../bloc/attendance_list_cubit.dart';
import '../bloc/attendance_list_state.dart';
import '../widgets/attendance_status_badge.dart';
import 'attendance_details_dialog.dart';

/// Main Attendance Management Screen supporting List and Calendar views.
class AttendanceListScreen extends StatelessWidget {
  final CurrentUser user;
  final AttendanceRepository repository;
  final String? initialEmployeeId;

  const AttendanceListScreen({
    super.key,
    required this.user,
    required this.repository,
    this.initialEmployeeId,
  });

  @override
  Widget build(BuildContext context) {
    if (!HrAccessPolicy.canViewHrRecords(user)) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider(
      create: (_) =>
          AttendanceListCubit(repository, initialEmployeeId: initialEmployeeId)
            ..loadAttendance(),
      child: _AttendanceListView(user: user, repository: repository),
    );
  }
}

class _AttendanceListView extends StatefulWidget {
  final CurrentUser user;
  final AttendanceRepository repository;

  const _AttendanceListView({required this.user, required this.repository});

  @override
  State<_AttendanceListView> createState() => _AttendanceListViewState();
}

class _AttendanceListViewState extends State<_AttendanceListView> {
  final TextEditingController _searchController = TextEditingController();
  DateTime _calendarMonth = DateTime.utc(2026, 9, 1);

  static const List<String> _statuses = [
    'All',
    'Present',
    'Absent',
    'Half-day',
    'On Leave',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<AttendanceListCubit>().setSearchQuery(query);
  }

  void _openDetails(AttendanceRecord record) {
    AttendanceDetailsDialog.show(context, record);
  }

  Future<void> _pickDateFilter() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          context.read<AttendanceListCubit>().state.selectedDate ??
          _calendarMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      context.read<AttendanceListCubit>().setSelectedDate(picked);
      setState(() {
        _calendarMonth = DateTime.utc(picked.year, picked.month, 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<AttendanceListCubit, AttendanceListState>(
      builder: (context, state) {
        return Scaffold(
          key: const Key('attendance_list_scaffold'),
          appBar: AppBar(
            title: const Text('Attendance Management'),
            actions: [
              IconButton(
                key: const Key('attendance_refresh_button'),
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => context.read<AttendanceListCubit>().refresh(),
              ),
            ],
          ),
          body: Column(
            children: [
              _buildHeaderControls(context, state, colorScheme),
              Expanded(child: _buildBody(context, state, theme, colorScheme)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderControls(
    BuildContext context,
    AttendanceListState state,
    ColorScheme colorScheme,
  ) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Search and View Mode toggle (responsive layout)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 560;
                final searchField = TextField(
                  key: const Key('attendance_search_field'),
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by employee, status, remarks...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                  ),
                );

                final viewModeToggle = SegmentedButton<AttendanceViewMode>(
                  key: const Key('attendance_view_mode_toggle'),
                  segments: const [
                    ButtonSegment(
                      value: AttendanceViewMode.list,
                      icon: Icon(Icons.list_alt, size: 18),
                      label: Text('List'),
                    ),
                    ButtonSegment(
                      value: AttendanceViewMode.calendar,
                      icon: Icon(Icons.calendar_month, size: 18),
                      label: Text('Calendar'),
                    ),
                  ],
                  selected: {state.viewMode},
                  onSelectionChanged: (selected) {
                    context.read<AttendanceListCubit>().setViewMode(
                      selected.first,
                    );
                  },
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: viewModeToggle,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 12),
                    viewModeToggle,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Bottom Row: Status Filter Chips & Date Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final status in _statuses)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        key: Key('attendance_filter_chip_$status'),
                        label: Text(status),
                        selected: status == 'All'
                            ? state.selectedStatus == null
                            : state.selectedStatus == status,
                        onSelected: (selected) {
                          context.read<AttendanceListCubit>().setStatusFilter(
                            status == 'All' || !selected ? null : status,
                          );
                        },
                      ),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: const Key('attendance_date_picker_button'),
                    icon: const Icon(Icons.event, size: 16),
                    label: Text(
                      state.selectedDate != null
                          ? '${state.selectedDate!.year}-${state.selectedDate!.month.toString().padLeft(2, '0')}-${state.selectedDate!.day.toString().padLeft(2, '0')}'
                          : 'Pick Date',
                    ),
                    onPressed: _pickDateFilter,
                  ),
                  if (state.hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      key: const Key('attendance_reset_filters_button'),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reset'),
                      onPressed: () {
                        _searchController.clear();
                        context.read<AttendanceListCubit>().resetFilters();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AttendanceListState state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('attendance_loading_indicator'),
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
              ),
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? 'An error occurred loading attendance.',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('attendance_retry_button'),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () => context.read<AttendanceListCubit>().refresh(),
              ),
            ],
          ),
        ),
      );
    }

    if (state.viewMode == AttendanceViewMode.calendar) {
      return _buildCalendarView(context, state, theme, colorScheme);
    }

    if (state.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_note_outlined,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              const Text(
                'No attendance records found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Try adjusting search or filter options.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return constraints.maxWidth >= 600
            ? _buildDesktopTable(context, state.filteredRecords, colorScheme)
            : _buildMobileList(context, state.filteredRecords);
      },
    );
  }

  Widget _buildMobileList(
    BuildContext context,
    List<AttendanceRecord> records,
  ) {
    return ListView.separated(
      key: const Key('attendance_mobile_list'),
      padding: const EdgeInsets.all(16.0),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final r = records[index];
        return _AttendanceCard(
          key: Key('attendance_card_${r.id}'),
          record: r,
          onTap: () => _openDetails(r),
        );
      },
    );
  }

  Widget _buildDesktopTable(
    BuildContext context,
    List<AttendanceRecord> records,
    ColorScheme colorScheme,
  ) {
    return SingleChildScrollView(
      key: const Key('attendance_desktop_table_scroll'),
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Employee ID')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Check In')),
              DataColumn(label: Text('Check Out')),
              DataColumn(label: Text('Remarks')),
              DataColumn(label: Text('Action')),
            ],
            rows: [
              for (final r in records)
                DataRow(
                  key: ValueKey('attendance_row_${r.id}'),
                  cells: [
                    DataCell(
                      Text(
                        r.formattedDate,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(Text(r.employeeId)),
                    DataCell(AttendanceStatusBadge(status: r.attendanceStatus)),
                    DataCell(Text(r.formattedCheckIn ?? '—')),
                    DataCell(Text(r.formattedCheckOut ?? '—')),
                    DataCell(Text(r.remarks ?? '—')),
                    DataCell(
                      TextButton(
                        key: Key('attendance_details_button_${r.id}'),
                        child: const Text('Details'),
                        onPressed: () => _openDetails(r),
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

  Widget _buildCalendarView(
    BuildContext context,
    AttendanceListState state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final year = _calendarMonth.year;
    final month = _calendarMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday % 7; // Sunday = 0

    final monthName = _monthName(month);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Month Header
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    key: const Key('calendar_prev_month_button'),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime.utc(
                          month == 1 ? year - 1 : year,
                          month == 1 ? 12 : month - 1,
                          1,
                        );
                      });
                    },
                  ),
                  Text(
                    '$monthName $year',
                    key: const Key('calendar_month_title'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    key: const Key('calendar_next_month_button'),
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime.utc(
                          month == 12 ? year + 1 : year,
                          month == 12 ? 1 : month + 1,
                          1,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Calendar Grid Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // Weekday Header
                  Row(
                    children: const [
                      _WeekdayLabel('Sun'),
                      _WeekdayLabel('Mon'),
                      _WeekdayLabel('Tue'),
                      _WeekdayLabel('Wed'),
                      _WeekdayLabel('Thu'),
                      _WeekdayLabel('Fri'),
                      _WeekdayLabel('Sat'),
                    ],
                  ),
                  const Divider(),
                  // Days Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 1.1,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                    itemCount: firstWeekday + daysInMonth,
                    itemBuilder: (context, index) {
                      if (index < firstWeekday) {
                        return const SizedBox.shrink();
                      }
                      final dayNum = index - firstWeekday + 1;
                      final date = DateTime.utc(year, month, dayNum);
                      final hasRecords = state.hasRecordsOnDay(date);
                      final isSelected =
                          state.selectedDate != null &&
                          state.selectedDate!.isAtSameMomentAs(date);

                      return InkWell(
                        onTap: () {
                          context.read<AttendanceListCubit>().setSelectedDate(
                            isSelected ? null : date,
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primaryContainer
                                : hasRecords
                                ? colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontWeight: isSelected || hasRecords
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? colorScheme.onPrimaryContainer
                                      : null,
                                ),
                              ),
                              if (hasRecords) ...[
                                const SizedBox(height: 2),
                                Container(
                                  key: Key('calendar_day_badge_$dayNum'),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Records for Selected Date
          Text(
            state.selectedDate != null
                ? 'Records for ${state.selectedDate!.year}-${state.selectedDate!.month.toString().padLeft(2, '0')}-${state.selectedDate!.day.toString().padLeft(2, '0')}'
                : 'All Filtered Records',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          if (state.filteredRecords.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'No attendance records found for this selection.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            for (final r in state.filteredRecords)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _AttendanceCard(
                  key: Key('calendar_attendance_card_${r.id}'),
                  record: r,
                  onTap: () => _openDetails(r),
                ),
              ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month - 1];
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String text;

  const _WeekdayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final AttendanceRecord record;
  final VoidCallback onTap;

  const _AttendanceCard({super.key, required this.record, required this.onTap});

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
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                      record.formattedDate,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AttendanceStatusBadge(status: record.attendanceStatus),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Employee: ${record.employeeId}',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login, size: 14, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'In: ${record.formattedCheckIn ?? '—'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.logout,
                        size: 14,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Out: ${record.formattedCheckOut ?? '—'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              if (record.remarks != null &&
                  record.remarks!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  record.remarks!,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
