import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/lead_export_file_saver.dart';
import '../../domain/entities/lead_export.dart';
import '../../domain/entities/lead_query.dart';
import '../../domain/repositories/lead_repository.dart';
import '../bloc/lead_export_cubit.dart';
import '../bloc/lead_export_state.dart';

/// Opens the lead export modal dialog.
Future<bool?> showLeadExportDialog({
  required BuildContext context,
  required LeadRepository repository,
  required LeadExportFileSaver fileSaver,
  required LeadQuery query,
  required String contextExplanation,
  LeadExportCubit? cubit,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => LeadExportDialog(
      repository: repository,
      fileSaver: fileSaver,
      query: query,
      contextExplanation: contextExplanation,
      cubit: cubit,
    ),
  );
}

/// Reusable modal dialog for configuring and initiating lead export.
class LeadExportDialog extends StatelessWidget {
  final LeadRepository repository;
  final LeadExportFileSaver fileSaver;
  final LeadQuery query;
  final String contextExplanation;
  final LeadExportCubit? cubit;

  const LeadExportDialog({
    super.key,
    required this.repository,
    required this.fileSaver,
    required this.query,
    required this.contextExplanation,
    this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _LeadExportDialogContent(
          query: query,
          contextExplanation: contextExplanation,
        ),
      );
    }

    return BlocProvider(
      create: (_) =>
          LeadExportCubit(repository: repository, fileSaver: fileSaver),
      child: _LeadExportDialogContent(
        query: query,
        contextExplanation: contextExplanation,
      ),
    );
  }
}

class _LeadExportDialogContent extends StatelessWidget {
  final LeadQuery query;
  final String contextExplanation;

  const _LeadExportDialogContent({
    required this.query,
    required this.contextExplanation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocConsumer<LeadExportCubit, LeadExportState>(
      listener: (context, state) {
        if (state.isSuccess) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final cubit = context.read<LeadExportCubit>();
        final isBusy = state.isBusy;

        return PopScope(
          canPop: !isBusy,
          child: AlertDialog(
            key: const Key('lead_export_dialog'),
            title: Row(
              children: [
                Icon(
                  Icons.download_outlined,
                  size: 22,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Export Leads', overflow: TextOverflow.ellipsis),
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
                    contextExplanation,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Format',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  RadioGroup<LeadExportFormat>(
                    groupValue: state.selectedFormat,
                    onChanged: (format) {
                      if (!isBusy && format != null) {
                        cubit.selectFormat(format);
                      }
                    },
                    child: Column(
                      children: [
                        RadioListTile<LeadExportFormat>(
                          key: const Key('lead_export_format_excel'),
                          value: LeadExportFormat.excel,
                          title: const Text('Excel (.xlsx)'),
                          enabled: !isBusy,
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<LeadExportFormat>(
                          key: const Key('lead_export_format_csv'),
                          value: LeadExportFormat.csv,
                          title: const Text('CSV (.csv)'),
                          enabled: !isBusy,
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  if (state.isFailure && state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      key: const Key('lead_export_dialog_error'),
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
                              state.errorMessage!,
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
                key: const Key('lead_export_dialog_cancel_button'),
                onPressed: isBusy
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('lead_export_dialog_submit_button'),
                onPressed: isBusy ? null : () => cubit.export(query: query),
                child: isBusy
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            state.isExporting
                                ? 'Generating...'
                                : state.isSaving
                                ? 'Saving...'
                                : 'Exporting...',
                          ),
                        ],
                      )
                    : const Text('Export'),
              ),
            ],
          ),
        );
      },
    );
  }
}
