import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/follow_up_event.dart';
import '../../domain/entities/follow_up_status.dart';
import '../bloc/lead_follow_up_history_cubit.dart';
import '../bloc/lead_follow_up_history_state.dart';
import '../utils/calling_display_formatters.dart';

/// Widget rendering the lifecycle history of follow-ups for a Lead.
///
/// Driven entirely by [LeadFollowUpHistoryCubit].
class LeadFollowUpHistorySection extends StatelessWidget {
  const LeadFollowUpHistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<LeadFollowUpHistoryCubit, LeadFollowUpHistoryState>(
      builder: (context, state) {
        if (state is LeadFollowUpHistoryLoading ||
            state is LeadFollowUpHistoryInitial) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state is LeadFollowUpHistoryAccessDenied) {
          return const SizedBox.shrink();
        }

        if (state is LeadFollowUpHistoryFailure) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              state.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          );
        }

        if (state is LeadFollowUpHistoryEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Follow-Up History',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No follow-ups recorded for this lead.',
                key: const Key('lead_follow_up_history_empty_message'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }

        if (state is LeadFollowUpHistoryLoaded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Follow-Up History',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  final fu = item.followUp;

                  final (statusBg, statusFg, statusLabel) = switch (fu.status) {
                    FollowUpStatus.pending => (
                      colorScheme.tertiaryContainer,
                      colorScheme.onTertiaryContainer,
                      'Pending',
                    ),
                    FollowUpStatus.completed => (
                      colorScheme.primaryContainer,
                      colorScheme.onPrimaryContainer,
                      'Completed',
                    ),
                    FollowUpStatus.cancelled => (
                      colorScheme.errorContainer,
                      colorScheme.onErrorContainer,
                      'Cancelled',
                    ),
                  };

                  return Container(
                    key: Key('lead_follow_up_history_card_${fu.id}'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.35,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatActivityDateTime(fu.scheduledAt),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: statusFg,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (item.events.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          ...item.events.map((e) => _buildEventRow(context, e)),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEventRow(BuildContext context, FollowUpEvent event) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final description = switch (event.type) {
      FollowUpEventType.created => 'Created',
      FollowUpEventType.rescheduled =>
        'Rescheduled to ${formatActivityDateTime(event.newScheduledAt)}',
      FollowUpEventType.completed => 'Completed',
      FollowUpEventType.cancelled => 'Cancelled',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$description • ${formatActivityDateTime(event.createdAt)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
