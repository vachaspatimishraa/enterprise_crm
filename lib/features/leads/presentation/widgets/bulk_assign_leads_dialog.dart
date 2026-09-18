import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/lead.dart';
import '../../domain/repositories/lead_repository.dart';
import '../bloc/lead_assignment_cubit.dart';
import '../bloc/lead_assignment_state.dart';
import 'lead_assignee_selector.dart';

/// Modal dialog for assigning multiple unassigned leads to a selected agent in bulk.
class BulkAssignLeadsDialog extends StatelessWidget {
  final List<Lead> leads;
  final LeadRepository repository;

  const BulkAssignLeadsDialog({
    super.key,
    required this.leads,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LeadAssignmentCubit(repository)..loadAssignableUsers(),
      child: _BulkAssignDialogContent(leads: leads),
    );
  }
}

class _BulkAssignDialogContent extends StatelessWidget {
  final List<Lead> leads;

  const _BulkAssignDialogContent({required this.leads});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocConsumer<LeadAssignmentCubit, LeadAssignmentState>(
      listener: (context, state) {
        if (state.submissionStatus == AssignmentSubmissionStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final cubit = context.read<LeadAssignmentCubit>();
        final isSubmitting = state.isSubmitting;
        final count = leads.length;
        final leadWord = count == 1 ? 'Lead' : 'Leads';

        final hasAssignedLead = leads.any((l) => l.isAssigned);

        return PopScope(
          canPop: !isSubmitting,
          child: AlertDialog(
            key: const Key('bulk_assign_dialog'),
            title: Row(
              children: [
                Icon(
                  Icons.group_add_outlined,
                  size: 22,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Assign $count $leadWord',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Assigning $count unassigned $leadWord to:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LeadAssigneeSelector(cubit: cubit, enabled: !isSubmitting),
                  if (hasAssignedLead) ...[
                    const SizedBox(height: 12),
                    Container(
                      key: const Key('bulk_assign_dialog_assigned_error'),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                              'One or more selected Leads are already assigned.',
                              style: TextStyle(
                                color: colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (state.hasSubmissionError) ...[
                    const SizedBox(height: 12),
                    Container(
                      key: const Key('bulk_assign_dialog_error'),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                              state.submissionErrorMessage ??
                                  'Unable to assign the selected Leads.',
                              style: TextStyle(
                                color: colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                key: const Key('bulk_assign_dialog_cancel_button'),
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('bulk_assign_dialog_submit_button'),
                onPressed:
                    (state.canSubmit && !isSubmitting && !hasAssignedLead)
                    ? () => cubit.assignLeads(leads: leads)
                    : null,
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Assign Leads ($count)'),
              ),
            ],
          ),
        );
      },
    );
  }
}
