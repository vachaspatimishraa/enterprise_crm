import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/lead_query.dart';
import '../../domain/entities/lead_source.dart';
import '../bloc/lead_filter_cubit.dart';
import '../bloc/lead_filter_state.dart';
import '../utils/lead_display_formatters.dart';

Future<void> showLeadFilterModal({
  required BuildContext context,
  required LeadQuery currentQuery,
  required ValueChanged<LeadQuery> onApply,
  required LeadFilterCubit filterCubit,
  bool lockAssignmentToUnassigned = false,
}) async {
  final isMobile = MediaQuery.sizeOf(context).width < 600;

  final content = BlocProvider.value(
    value: filterCubit,
    child: LeadFilterSheet(
      initialQuery: currentQuery,
      onApply: onApply,
      lockAssignmentToUnassigned: lockAssignmentToUnassigned,
    ),
  );

  if (isMobile) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => content,
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: content,
        ),
      ),
    );
  }
}

class LeadFilterSheet extends StatefulWidget {
  final LeadQuery initialQuery;
  final ValueChanged<LeadQuery> onApply;
  final bool lockAssignmentToUnassigned;

  const LeadFilterSheet({
    super.key,
    required this.initialQuery,
    required this.onApply,
    this.lockAssignmentToUnassigned = false,
  });

  @override
  State<LeadFilterSheet> createState() => _LeadFilterSheetState();
}

class _LeadFilterSheetState extends State<LeadFilterSheet> {
  late LeadSource? _draftSource;
  late bool? _draftIsAssigned;
  late String? _draftAssignedUserId;

  @override
  void initState() {
    super.initState();
    _draftSource = widget.initialQuery.source;
    _draftIsAssigned = widget.lockAssignmentToUnassigned
        ? false
        : widget.initialQuery.isAssigned;
    _draftAssignedUserId = widget.lockAssignmentToUnassigned
        ? null
        : widget.initialQuery.assignedUserId;

    // Trigger loading assignees if still in initial state
    final cubit = context.read<LeadFilterCubit>();
    if (cubit.state is LeadFilterInitial) {
      cubit.loadAssignableUsers();
    }
  }

  void _onSourceChanged(LeadSource? source) {
    setState(() {
      _draftSource = source;
    });
  }

  void _onAssignmentChanged(bool? isAssigned) {
    if (widget.lockAssignmentToUnassigned) return;
    setState(() {
      _draftIsAssigned = isAssigned;
      if (isAssigned == false) {
        // Unassigned selected -> clear specific assignee
        _draftAssignedUserId = null;
      }
    });
  }

  void _onAssigneeChanged(String? assigneeId) {
    if (widget.lockAssignmentToUnassigned) return;
    setState(() {
      _draftAssignedUserId = assigneeId;
      if (assigneeId != null) {
        // Selecting a specific assignee implies an assigned lead
        _draftIsAssigned = true;
      }
    });
  }

  void _apply() {
    final effectiveIsAssigned = widget.lockAssignmentToUnassigned
        ? false
        : (_draftAssignedUserId != null ? true : _draftIsAssigned);
    final effectiveAssignedUserId = widget.lockAssignmentToUnassigned
        ? null
        : _draftAssignedUserId;

    final updatedQuery = widget.initialQuery.copyWith(
      source: _draftSource,
      clearSource: _draftSource == null,
      isAssigned: effectiveIsAssigned,
      clearIsAssigned: effectiveIsAssigned == null,
      assignedUserId: effectiveAssignedUserId,
      clearAssignedUser: effectiveAssignedUserId == null,
      page: 1,
    );

    widget.onApply(updatedQuery);
    Navigator.of(context).pop();
  }

  void _clear() {
    final clearedQuery = widget.initialQuery.copyWith(
      clearSource: true,
      clearIsAssigned: !widget.lockAssignmentToUnassigned,
      isAssigned: widget.lockAssignmentToUnassigned ? false : null,
      clearAssignedUser: true,
      page: 1,
    );

    widget.onApply(clearedQuery);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                key: const Key('filter_close_button'),
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(height: 16),

          // Lead Source Section
          Text(
            'Lead Source',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          RadioGroup<LeadSource?>(
            groupValue: _draftSource,
            onChanged: _onSourceChanged,
            child: Column(
              children: [
                RadioListTile<LeadSource?>(
                  key: const Key('filter_source_all'),
                  title: const Text('All'),
                  value: null,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<LeadSource?>(
                  key: const Key('filter_source_manual'),
                  title: Text(formatLeadSource(LeadSource.manual)),
                  value: LeadSource.manual,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<LeadSource?>(
                  key: const Key('filter_source_excel'),
                  title: Text(formatLeadSource(LeadSource.excel)),
                  value: LeadSource.excel,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<LeadSource?>(
                  key: const Key('filter_source_csv'),
                  title: Text(formatLeadSource(LeadSource.csv)),
                  value: LeadSource.csv,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Assignment State Section
          Text(
            'Assignment',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          if (widget.lockAssignmentToUnassigned) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Locked to Unassigned in distribution mode.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ] else ...[
            RadioGroup<bool?>(
              groupValue: _draftIsAssigned,
              onChanged: _onAssignmentChanged,
              child: Column(
                children: [
                  RadioListTile<bool?>(
                    key: const Key('filter_assignment_all'),
                    title: const Text('All'),
                    value: null,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<bool?>(
                    key: const Key('filter_assignment_assigned'),
                    title: const Text('Assigned'),
                    value: true,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<bool?>(
                    key: const Key('filter_assignment_unassigned'),
                    title: const Text('Unassigned'),
                    value: false,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Assigned User Section
            Text(
              'Assigned User',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            BlocBuilder<LeadFilterCubit, LeadFilterState>(
              builder: (context, state) {
                if (state is LeadFilterLoading || state is LeadFilterInitial) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Loading assignees...'),
                      ],
                    ),
                  );
                }

                if (state is LeadFilterFailure) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.message,
                            style: TextStyle(
                              color: colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            context
                                .read<LeadFilterCubit>()
                                .retryAssignableUsers();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (state is LeadFilterReady) {
                  final hasCurrentSelection =
                      _draftAssignedUserId == null ||
                      state.assignees.any((a) => a.id == _draftAssignedUserId);

                  return DropdownButtonFormField<String?>(
                    key: const Key('filter_assignee_dropdown'),
                    initialValue: _draftAssignedUserId,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Assignees'),
                      ),
                      if (!hasCurrentSelection && _draftAssignedUserId != null)
                        DropdownMenuItem<String?>(
                          value: _draftAssignedUserId,
                          child: Text('User: $_draftAssignedUserId'),
                        ),
                      ...state.assignees.map(
                        (assignee) => DropdownMenuItem<String?>(
                          value: assignee.id,
                          child: Text(assignee.displayName),
                        ),
                      ),
                    ],
                    onChanged: _onAssigneeChanged,
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ],
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('filter_clear_button'),
                  onPressed: _clear,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Clear Filters'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('filter_apply_button'),
                  onPressed: _apply,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
