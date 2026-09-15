import 'package:flutter/material.dart';
import '../../domain/entities/lead_assignee.dart';
import '../../domain/entities/lead_query.dart';
import '../utils/lead_display_formatters.dart';

class LeadActiveFilters extends StatelessWidget {
  final LeadQuery query;
  final List<LeadAssignee> assignees;
  final VoidCallback onRemoveSource;
  final VoidCallback onRemoveAssignment;
  final VoidCallback onRemoveAssignee;
  final VoidCallback onClearAll;

  const LeadActiveFilters({
    super.key,
    required this.query,
    this.assignees = const [],
    required this.onRemoveSource,
    required this.onRemoveAssignment,
    required this.onRemoveAssignee,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final hasSource = query.source != null;
    final hasAssignment = query.isAssigned != null;
    final hasAssignee = query.assignedUserId != null;

    if (!hasSource && !hasAssignment && !hasAssignee) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String assigneeName = 'User: ${query.assignedUserId}';
    if (hasAssignee) {
      final match = assignees.where((a) => a.id == query.assignedUserId);
      if (match.isNotEmpty) {
        assigneeName = match.first.displayName;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hasSource)
            InputChip(
              key: const Key('active_filter_source_chip'),
              label: Text(formatLeadSource(query.source!)),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: onRemoveSource,
              deleteIconColor: colorScheme.onSurfaceVariant,
              visualDensity: VisualDensity.compact,
            ),
          if (hasAssignment)
            InputChip(
              key: const Key('active_filter_assignment_chip'),
              label: Text(query.isAssigned! ? 'Assigned' : 'Unassigned'),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: onRemoveAssignment,
              deleteIconColor: colorScheme.onSurfaceVariant,
              visualDensity: VisualDensity.compact,
            ),
          if (hasAssignee)
            InputChip(
              key: const Key('active_filter_assignee_chip'),
              label: Text(assigneeName),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: onRemoveAssignee,
              deleteIconColor: colorScheme.onSurfaceVariant,
              visualDensity: VisualDensity.compact,
            ),
          InkWell(
            key: const Key('active_filters_clear_all'),
            onTap: onClearAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'Clear all',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
