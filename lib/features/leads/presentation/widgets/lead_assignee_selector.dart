import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/lead_assignee.dart';
import '../bloc/lead_assignment_cubit.dart';
import '../bloc/lead_assignment_state.dart';

/// Reusable presentation widget for selecting an assignee.
class LeadAssigneeSelector extends StatelessWidget {
  final LeadAssignmentCubit? cubit;
  final void Function(LeadAssignee? assignee)? onChanged;
  final bool enabled;

  const LeadAssigneeSelector({
    super.key,
    this.cubit,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final assignmentCubit = cubit ?? context.read<LeadAssignmentCubit>();

    return BlocBuilder<LeadAssignmentCubit, LeadAssignmentState>(
      bloc: assignmentCubit,
      builder: (context, state) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        // 1. Initial / Loading state when no assignees are cached
        if (state.isLoadingAssignees && state.assignees.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              key: const Key('assignee_selector_loading'),
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Loading assignable users...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // 2. Load failure state when no assignees are available
        if (state.hasLoadError && state.assignees.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              key: const Key('assignee_selector_failure'),
              children: [
                Icon(Icons.error_outline, size: 20, color: colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.loadErrorMessage ??
                        'Unable to load assignable users.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const Key('assignee_selector_retry_button'),
                  onPressed: () {
                    assignmentCubit.loadAssignableUsers();
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // 3. Truthful empty state
        if (state.assignees.isEmpty && !state.isLoadingAssignees) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              key: const Key('assignee_selector_empty'),
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No assignable users available.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // 4. Assignee dropdown with loaded options
        final isInteractive = enabled && !state.isSubmitting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String?>(
              key: const Key('lead_assignee_dropdown'),
              isExpanded: true,
              initialValue: state.selectedAssignee?.id,
              decoration: InputDecoration(
                labelText: 'Assignee',
                hintText: 'Select an assignee',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  key: Key('assignee_item_none'),
                  value: null,
                  child: Text('Select an assignee'),
                ),
                ...state.assignees.map(
                  (assignee) => DropdownMenuItem<String?>(
                    key: Key('assignee_item_${assignee.id}'),
                    value: assignee.id,
                    child: Text(
                      assignee.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: isInteractive
                  ? (value) {
                      if (value == null) {
                        assignmentCubit.clearSelectedAssignee();
                        onChanged?.call(null);
                      } else {
                        final matched = state.assignees
                            .where((a) => a.id == value)
                            .firstOrNull;
                        if (matched != null) {
                          assignmentCubit.selectAssignee(matched);
                          onChanged?.call(matched);
                        }
                      }
                    }
                  : null,
            ),
            // Surface retry if a reload failed while preserving cached assignees
            if (state.hasLoadError && state.assignees.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                key: const Key('assignee_selector_reload_failure'),
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.loadErrorMessage ??
                          'Unable to reload assignable users.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => assignmentCubit.loadAssignableUsers(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
