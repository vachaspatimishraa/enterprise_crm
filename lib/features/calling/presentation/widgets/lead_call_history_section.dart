import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/lead_call_activity.dart';
import '../bloc/lead_call_history_cubit.dart';
import '../bloc/lead_call_history_state.dart';
import '../utils/calling_display_formatters.dart';

/// Presentation section displaying recorded call activities for an authorized lead.
class LeadCallHistorySection extends StatelessWidget {
  const LeadCallHistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CALL HISTORY',
          key: const Key('lead_call_history_section_title'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        BlocBuilder<LeadCallHistoryCubit, LeadCallHistoryState>(
          builder: (context, state) {
            return switch (state) {
              LeadCallHistoryInitial() ||
              LeadCallHistoryLoading() => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    key: Key('lead_call_history_loading'),
                  ),
                ),
              ),
              LeadCallHistoryAccessDenied() => const SizedBox.shrink(),
              LeadCallHistoryEmpty() => Container(
                key: const Key('lead_call_history_empty_card'),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Center(
                  child: Text(
                    'No call activity recorded for this lead.',
                    key: const Key('lead_call_history_empty_message'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              LeadCallHistoryFailure(:final message) => Container(
                key: const Key('lead_call_history_failure_card'),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      message,
                      key: const Key('lead_call_history_failure_message'),
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('lead_call_history_retry_button'),
                      onPressed: () =>
                          context.read<LeadCallHistoryCubit>().loadHistory(),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              LeadCallHistoryLoaded(:final activities) => ListView.separated(
                key: const Key('lead_call_history_list'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return _CallActivityCard(activity: activity);
                },
              ),
            };
          },
        ),
      ],
    );
  }
}

class _CallActivityCard extends StatelessWidget {
  final LeadCallActivity activity;

  const _CallActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.phone_in_talk_outlined,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                formatCallOutcome(activity.outcome),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (activity.rescheduleAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 14,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Rescheduled: ${formatActivityDateTime(activity.rescheduleAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: colorScheme.outline),
              const SizedBox(width: 6),
              Text(
                'Recorded: ${formatActivityDateTime(activity.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
