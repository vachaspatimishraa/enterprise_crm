import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../../dashboard/presentation/screens/user_lead_details_screen.dart';
import '../../../dashboard/presentation/screens/user_lead_workspace_screen.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import '../../data/repositories/mock_lead_call_activity_repository.dart';
import '../../domain/entities/follow_up_timing.dart';
import '../../domain/policies/user_calling_policy.dart';
import '../../domain/repositories/lead_call_activity_repository.dart';
import '../../domain/repositories/lead_follow_up_repository.dart';
import '../bloc/calling_dashboard_cubit.dart';
import '../bloc/calling_dashboard_state.dart';
import '../bloc/follow_up_action_cubit.dart';
import '../bloc/follow_up_action_state.dart';
import '../models/follow_up_queue_item.dart';
import '../utils/calling_display_formatters.dart';

/// Workspace and dashboard screen for standard CRM users navigating into the Calling module.
///
/// Enforces Calling module + `calling.use` as a pre-Cubit production guard. When authorized,
/// initializes and provides [CallingDashboardCubit] and [FollowUpActionCubit].
class UserCallingWorkspaceScreen extends StatelessWidget {
  final CurrentUser user;
  final LeadRepository leadRepository;
  final UserLeadLinkRepository linkRepository;
  final LeadCallActivityRepository callActivityRepository;
  final LeadFollowUpRepository leadFollowUpRepository;
  final NowProvider? now;

  const UserCallingWorkspaceScreen({
    super.key,
    required this.user,
    required this.leadRepository,
    required this.linkRepository,
    required this.callActivityRepository,
    required this.leadFollowUpRepository,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Pre-Cubit production guard: zero Cubit initialization if unauthorized
    if (!UserCallingPolicy.canUseCalling(user)) {
      return const AccessRestrictedScreen();
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => CallingDashboardCubit(
            user: user,
            leadRepository: leadRepository,
            linkRepository: linkRepository,
            followUpRepository: leadFollowUpRepository,
            callActivityRepository: callActivityRepository,
            now: now,
          )..load(),
        ),
        BlocProvider(
          create: (_) => FollowUpActionCubit(
            user: user,
            linkRepository: linkRepository,
            leadRepository: leadRepository,
            followUpRepository: leadFollowUpRepository,
            now: now,
          ),
        ),
      ],
      child: _CallingDashboardView(
        user: user,
        leadRepository: leadRepository,
        linkRepository: linkRepository,
        callActivityRepository: callActivityRepository,
        leadFollowUpRepository: leadFollowUpRepository,
        now: now,
      ),
    );
  }
}

class _CallingDashboardView extends StatefulWidget {
  final CurrentUser user;
  final LeadRepository leadRepository;
  final UserLeadLinkRepository linkRepository;
  final LeadCallActivityRepository callActivityRepository;
  final LeadFollowUpRepository leadFollowUpRepository;
  final NowProvider? now;

  const _CallingDashboardView({
    required this.user,
    required this.leadRepository,
    required this.linkRepository,
    required this.callActivityRepository,
    required this.leadFollowUpRepository,
    this.now,
  });

  @override
  State<_CallingDashboardView> createState() => _CallingDashboardViewState();
}

class _CallingDashboardViewState extends State<_CallingDashboardView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openLeadDetails(BuildContext context, String leadId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserLeadDetailsScreen(
          leadId: leadId,
          user: widget.user,
          leadRepository: widget.leadRepository,
          linkRepository: widget.linkRepository,
          callActivityRepository: widget.callActivityRepository,
          leadFollowUpRepository: widget.leadFollowUpRepository,
        ),
      ),
    );
    if (context.mounted) {
      context.read<CallingDashboardCubit>().refresh();
    }
  }

  void _onCompleteFollowUp(BuildContext context, FollowUpQueueItem item) {
    context.read<FollowUpActionCubit>().completeFollowUp(
      followUpId: item.followUp.id,
      leadId: item.lead.id,
    );
  }

  void _onCancelFollowUp(BuildContext context, FollowUpQueueItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Follow-Up'),
          content: const Text('Cancel this scheduled follow-up?'),
          actions: [
            TextButton(
              key: const Key('calling_cancel_dialog_dismiss'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Follow-Up'),
            ),
            FilledButton(
              key: const Key('calling_cancel_dialog_confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm Cancel'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      context.read<FollowUpActionCubit>().cancelFollowUp(
        followUpId: item.followUp.id,
        leadId: item.lead.id,
      );
    }
  }

  void _onRescheduleFollowUp(
    BuildContext context,
    FollowUpQueueItem item,
  ) async {
    final now = widget.now != null ? widget.now!() : DateTime.now();

    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    String? validationError;

    final newDateTime = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reschedule Follow-Up'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lead: ${item.lead.name ?? 'Lead'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('calling_reschedule_pick_date_button'),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            selectedDate == null
                                ? 'Pick Date'
                                : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate ??
                                  now.add(const Duration(days: 1)),
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                                validationError = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('calling_reschedule_pick_time_button'),
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(
                            selectedTime == null
                                ? 'Pick Time'
                                : selectedTime!.format(context),
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime ??
                                  const TimeOfDay(hour: 10, minute: 0),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedTime = picked;
                                validationError = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      validationError!,
                      key: const Key('calling_reschedule_validation_error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  key: const Key('calling_reschedule_dialog_dismiss'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('calling_reschedule_dialog_confirm'),
                  onPressed: () {
                    if (selectedDate == null || selectedTime == null) {
                      setDialogState(() {
                        validationError = 'Both date and time are required.';
                      });
                      return;
                    }
                    final combined = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );
                    if (!combined.isAfter(now)) {
                      setDialogState(() {
                        validationError =
                            'Reschedule date and time must be in the future.';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(combined);
                  },
                  child: const Text('Confirm Reschedule'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newDateTime != null && context.mounted) {
      context.read<FollowUpActionCubit>().rescheduleFollowUp(
        followUpId: item.followUp.id,
        leadId: item.lead.id,
        scheduledAt: newDateTime,
      );
    }
  }

  void _openMyAssignedLeads(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserLeadWorkspaceScreen(
          user: widget.user,
          linkRepository: widget.linkRepository,
          leadRepository: widget.leadRepository,
          callActivityRepository: widget.callActivityRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calling'),
        leading: IconButton(
          key: const Key('user_calling_workspace_back_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            key: const Key('calling_dashboard_refresh_button'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<CallingDashboardCubit>().refresh(),
          ),
        ],
      ),
      body: BlocListener<FollowUpActionCubit, FollowUpActionState>(
        listener: (context, actionState) {
          if (actionState is FollowUpActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Follow-up updated successfully.')),
            );
            context.read<CallingDashboardCubit>().refresh();
          } else if (actionState is FollowUpActionFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(actionState.message)),
            );
          } else if (actionState is FollowUpActionAccessDenied) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(actionState.reason)),
            );
          }
        },
        child: BlocBuilder<CallingDashboardCubit, CallingDashboardState>(
          builder: (context, state) {
          if (state is CallingDashboardLoading ||
              state is CallingDashboardInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CallingDashboardNoLeadAccess) {
            return _buildInformationalCard(
              context,
              messageKey: 'user_calling_no_lead_access_message',
              message:
                  'Calling access is enabled, but no Lead viewing access has been assigned to your account.',
              icon: Icons.info_outline,
            );
          }

          if (state is CallingDashboardNoLink) {
            return _buildInformationalCard(
              context,
              messageKey: 'calling_dashboard_no_link_message',
              message:
                  'Lead assignment identity is not configured for this account. Contact an administrator.',
              icon: Icons.warning_amber_rounded,
            );
          }

          if (state is CallingDashboardInvalidLink) {
            return _buildInformationalCard(
              context,
              messageKey: 'calling_dashboard_invalid_link_message',
              message:
                  'Lead assignment identity is not configured for this account. Contact an administrator.',
              icon: Icons.error_outline,
            );
          }

          if (state is CallingDashboardFailure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  key: const Key('calling_dashboard_failure_view'),
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.error),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 40,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Unable to load scheduled follow-ups.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const Key('calling_dashboard_retry_button'),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        onPressed: () =>
                            context.read<CallingDashboardCubit>().retry(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final isNarrow = constraints.maxWidth < 400;

              final visibleItems = state is CallingDashboardLoaded
                  ? state.visibleItems
                  : const <FollowUpQueueItem>[];
              final overdueCount = state is CallingDashboardLoaded
                  ? state.overdueCount
                  : 0;
              final dueTodayCount = state is CallingDashboardLoaded
                  ? state.dueTodayCount
                  : 0;
              final upcomingCount = state is CallingDashboardLoaded
                  ? state.upcomingCount
                  : 0;
              final selectedFilter = state is CallingDashboardLoaded
                  ? state.selectedFilter
                  : FollowUpTimingFilter.all;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 32 : 16,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Header Card (Calling enabled & Open Assigned Leads)
                        _buildHeaderCard(context, isWide: isWide),
                        const SizedBox(height: 20),

                        // 2. Summary Metrics Cards
                        _buildSummaryMetrics(
                          context,
                          constraints: constraints,
                          isWide: isWide,
                          isNarrow: isNarrow,
                          overdueCount: overdueCount,
                          dueTodayCount: dueTodayCount,
                          upcomingCount: upcomingCount,
                          selectedFilter: selectedFilter,
                        ),
                        const SizedBox(height: 24),

                        // 3. Queue Section
                        if (state is CallingDashboardEmpty) ...[
                          _buildEmptyQueueCard(context),
                        ] else if (state is CallingDashboardLoaded) ...[
                          // Search & Filters
                          _buildSearchAndFilters(
                            context,
                            selectedFilter: selectedFilter,
                            isWide: isWide,
                          ),
                          const SizedBox(height: 16),

                          // Queue Items List
                          if (visibleItems.isEmpty) ...[
                            _buildSearchNoResultsCard(context),
                          ] else ...[
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: visibleItems.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                return _buildQueueItemCard(
                                  context,
                                  item: visibleItems[index],
                                );
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}

  Widget _buildHeaderCard(BuildContext context, {required bool isWide}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final openLeadsButton = FilledButton.tonalIcon(
      key: const Key('user_calling_open_leads_button'),
      icon: const Icon(Icons.people_outline, size: 18),
      label: const Text('Open My Assigned Leads'),
      onPressed: () => _openMyAssignedLeads(context),
    );

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(isWide ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWide)
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.phone_in_talk, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CALLING',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Calling access is enabled.',
                          key: const Key('user_calling_status_enabled'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  openLeadsButton,
                ],
              )
            else ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.phone_in_talk, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CALLING',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Calling access is enabled.',
                          key: const Key('user_calling_status_enabled'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: openLeadsButton),
            ],
            const SizedBox(height: 14),
            Text(
              'Call and follow-up activity is managed from your assigned Lead details.',
              key: const Key('user_calling_manage_from_leads_message'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetrics(
    BuildContext context, {
    required BoxConstraints constraints,
    required bool isWide,
    required bool isNarrow,
    required int overdueCount,
    required int dueTodayCount,
    required int upcomingCount,
    required FollowUpTimingFilter selectedFilter,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final cubit = context.read<CallingDashboardCubit>();

    final cardWidth = isWide
        ? (constraints.maxWidth - 24) / 3
        : (isNarrow ? constraints.maxWidth : (constraints.maxWidth - 12) / 2);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildMetricCard(
          context,
          key: const Key('calling_summary_card_overdue'),
          label: 'Overdue',
          count: overdueCount,
          width: cardWidth,
          color: colorScheme.errorContainer,
          onColor: colorScheme.onErrorContainer,
          isSelected: selectedFilter == FollowUpTimingFilter.overdue,
          onTap: () => cubit.setFilter(
            selectedFilter == FollowUpTimingFilter.overdue
                ? FollowUpTimingFilter.all
                : FollowUpTimingFilter.overdue,
          ),
        ),
        _buildMetricCard(
          context,
          key: const Key('calling_summary_card_due_today'),
          label: 'Due Today',
          count: dueTodayCount,
          width: cardWidth,
          color: colorScheme.tertiaryContainer,
          onColor: colorScheme.onTertiaryContainer,
          isSelected: selectedFilter == FollowUpTimingFilter.dueToday,
          onTap: () => cubit.setFilter(
            selectedFilter == FollowUpTimingFilter.dueToday
                ? FollowUpTimingFilter.all
                : FollowUpTimingFilter.dueToday,
          ),
        ),
        _buildMetricCard(
          context,
          key: const Key('calling_summary_card_upcoming'),
          label: 'Upcoming',
          count: upcomingCount,
          width: cardWidth,
          color: colorScheme.surfaceContainerHighest,
          onColor: colorScheme.onSurfaceVariant,
          isSelected: selectedFilter == FollowUpTimingFilter.upcoming,
          onTap: () => cubit.setFilter(
            selectedFilter == FollowUpTimingFilter.upcoming
                ? FollowUpTimingFilter.all
                : FollowUpTimingFilter.upcoming,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required Key key,
    required String label,
    required int count,
    required double width,
    required Color color,
    required Color onColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: width,
      child: Card(
        key: key,
        elevation: 0,
        color: isSelected ? color : colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected ? onColor : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? onColor
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: isSelected ? onColor : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
                  size: 16,
                  color: isSelected
                      ? onColor
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(
    BuildContext context, {
    required FollowUpTimingFilter selectedFilter,
    required bool isWide,
  }) {
    final cubit = context.read<CallingDashboardCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search bar
        TextField(
          key: const Key('calling_search_field'),
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search leads...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      cubit.setSearchQuery('');
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) {
            cubit.setSearchQuery(value);
            setState(() {});
          },
        ),
        const SizedBox(height: 12),

        // Filter chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              key: const Key('calling_filter_chip_all'),
              label: const Text('All'),
              selected: selectedFilter == FollowUpTimingFilter.all,
              onSelected: (_) => cubit.setFilter(FollowUpTimingFilter.all),
            ),
            FilterChip(
              key: const Key('calling_filter_chip_overdue'),
              label: const Text('Overdue'),
              selected: selectedFilter == FollowUpTimingFilter.overdue,
              onSelected: (_) => cubit.setFilter(FollowUpTimingFilter.overdue),
            ),
            FilterChip(
              key: const Key('calling_filter_chip_due_today'),
              label: const Text('Due Today'),
              selected: selectedFilter == FollowUpTimingFilter.dueToday,
              onSelected: (_) => cubit.setFilter(FollowUpTimingFilter.dueToday),
            ),
            FilterChip(
              key: const Key('calling_filter_chip_upcoming'),
              label: const Text('Upcoming'),
              selected: selectedFilter == FollowUpTimingFilter.upcoming,
              onSelected: (_) => cubit.setFilter(FollowUpTimingFilter.upcoming),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQueueItemCard(
    BuildContext context, {
    required FollowUpQueueItem item,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (timingBg, timingFg) = switch (item.timing) {
      FollowUpTiming.overdue => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
      FollowUpTiming.dueToday => (
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
      FollowUpTiming.upcoming => (
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
      ),
    };

    return Card(
      key: Key('calling_queue_item_card_${item.followUp.id}'),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openLeadDetails(context, item.lead.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            key: item.activity != null
                ? Key('calling_queue_item_card_${item.activity!.id}')
                : null,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.lead.name ?? 'Unnamed Lead',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.lead.phone != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.lead.phone!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  OutlinedButton.icon(
                    key: Key(
                      'calling_queue_item_view_lead_button_${item.followUp.id}',
                    ),
                    icon: item.activity != null
                        ? Icon(
                            Icons.visibility,
                            key: Key(
                              'calling_queue_item_view_lead_button_${item.activity!.id}',
                            ),
                            size: 16,
                          )
                        : const Icon(Icons.visibility, size: 16),
                    label: const Text('View Lead'),
                    onPressed: () => _openLeadDetails(context, item.lead.id),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (item.activity != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formatCallOutcome(item.activity!.outcome),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: timingBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      formatFollowUpTiming(item.timing),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: timingFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.event, size: 14, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      formatActivityDateTime(item.followUp.scheduledAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Recorded ${formatActivityDateTime(item.activity?.createdAt ?? item.followUp.createdAt)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Action buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: Key(
                      'calling_queue_item_complete_button_${item.followUp.id}',
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Complete'),
                    onPressed: () => _onCompleteFollowUp(context, item),
                  ),
                  OutlinedButton.icon(
                    key: Key(
                      'calling_queue_item_reschedule_button_${item.followUp.id}',
                    ),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                    label: const Text('Reschedule'),
                    onPressed: () => _onRescheduleFollowUp(context, item),
                  ),
                  OutlinedButton.icon(
                    key: Key(
                      'calling_queue_item_cancel_button_${item.followUp.id}',
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    onPressed: () => _onCancelFollowUp(context, item),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyQueueCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.event_available,
              size: 48,
              color: colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No scheduled follow-ups.',
              key: const Key('calling_queue_empty_message'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow-up reminders will appear here when call outcomes are recorded with a reschedule date.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchNoResultsCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'No follow-ups match your search.',
          key: const Key('calling_search_no_results'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildInformationalCard(
    BuildContext context, {
    required String messageKey,
    required String message,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                        child: const Icon(Icons.phone_in_talk, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CALLING',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Calling access is enabled.',
                              key: const Key('user_calling_status_enabled'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 24),
                  Container(
                    key: Key(messageKey),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          color: colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
