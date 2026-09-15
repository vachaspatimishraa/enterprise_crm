import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/lead_source.dart';
import '../bloc/lead_import_cubit.dart';
import '../bloc/lead_import_state.dart';
import '../models/lead_import_selected_file.dart';
import '../services/lead_import_file_picker.dart';

class LeadImportScreen extends StatelessWidget {
  const LeadImportScreen({
    super.key,
    this.filePicker,
    this.cubit,
    this.onContinue,
    this.onCancel,
  });

  final LeadImportFilePicker? filePicker;
  final LeadImportCubit? cubit;
  final ValueChanged<LeadImportSelectedFile>? onContinue;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _LeadImportView(onContinue: onContinue, onCancel: onCancel),
      );
    }

    return BlocProvider(
      create: (_) => LeadImportCubit(filePicker),
      child: _LeadImportView(onContinue: onContinue, onCancel: onCancel),
    );
  }
}

class _LeadImportView extends StatelessWidget {
  const _LeadImportView({this.onContinue, this.onCancel});

  final ValueChanged<LeadImportSelectedFile>? onContinue;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cubit = context.read<LeadImportCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Leads'),
        leading: IconButton(
          key: const Key('lead_import_back_button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: onCancel ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: BlocBuilder<LeadImportCubit, LeadImportState>(
                builder: (context, state) {
                  final isPicking = state is LeadImportPicking;
                  final currentFile = cubit.currentFile;
                  final hasValidFile = currentFile != null;
                  final errorMessage = state is LeadImportFileError
                      ? state.message
                      : null;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Upload a CSV or Excel (.xlsx) file to import leads.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Error banner if any
                      if (errorMessage != null) ...[
                        _ErrorBanner(
                          message: errorMessage,
                          onDismiss: () => cubit.clearError(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Picking indicator
                      if (isPicking) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: LinearProgressIndicator(),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Main file card (either selected file card or upload drop-zone)
                      if (currentFile != null)
                        _SelectedFileCard(
                          file: currentFile,
                          isPicking: isPicking,
                          onChangeFile: () => cubit.pickFile(),
                          onRemoveFile: () => cubit.removeFile(),
                        )
                      else
                        _UploadDropZone(
                          isPicking: isPicking,
                          onChooseFile: () => cubit.pickFile(),
                        ),

                      const SizedBox(height: 28),

                      // Continue action button
                      FilledButton(
                        key: const Key('lead_import_continue_button'),
                        onPressed: (hasValidFile && !isPicking)
                            ? () => onContinue?.call(currentFile)
                            : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadDropZone extends StatelessWidget {
  const _UploadDropZone({required this.isPicking, required this.onChooseFile});

  final bool isPicking;
  final VoidCallback onChooseFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('lead_import_upload_card'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 52,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Upload file',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'CSV or Excel (.xlsx)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('lead_import_choose_file_button'),
            onPressed: isPicking ? null : onChooseFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose File'),
          ),
        ],
      ),
    );
  }
}

class _SelectedFileCard extends StatelessWidget {
  const _SelectedFileCard({
    required this.file,
    required this.isPicking,
    required this.onChangeFile,
    required this.onRemoveFile,
  });

  final LeadImportSelectedFile file;
  final bool isPicking;
  final VoidCallback onChangeFile;
  final VoidCallback onRemoveFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isExcel = file.source == LeadSource.excel;
    final fileTypeLabel = isExcel ? 'Excel File' : 'CSV File';
    final fileIcon = isExcel
        ? Icons.table_view_outlined
        : Icons.description_outlined;

    return Container(
      key: const Key('lead_import_selected_file_card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected File',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  fileIcon,
                  size: 32,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      key: const Key('lead_import_file_name_text'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            fileTypeLabel,
                            key: const Key('lead_import_file_type_text'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        Text(
                          file.formattedSize,
                          key: const Key('lead_import_file_size_text'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('lead_import_change_file_button'),
                onPressed: isPicking ? null : onChangeFile,
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Change File'),
              ),
              TextButton.icon(
                key: const Key('lead_import_remove_file_button'),
                onPressed: isPicking ? null : onRemoveFile,
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: colorScheme.error,
                ),
                label: Text(
                  'Remove',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const Key('lead_import_error_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            key: const Key('lead_import_error_dismiss_button'),
            onTap: onDismiss,
            child: Icon(
              Icons.close,
              size: 18,
              color: colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}
