import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/lead_source.dart';
import '../bloc/lead_import_preview_cubit.dart';
import '../bloc/lead_import_preview_state.dart';
import '../models/lead_import_column_mapping.dart';
import '../models/lead_import_parsed_file.dart';
import '../models/lead_import_preview.dart';
import '../models/lead_import_structure_analysis.dart';
import '../services/lead_import_preview_builder.dart';

class LeadImportPreviewScreen extends StatelessWidget {
  const LeadImportPreviewScreen({
    super.key,
    required this.parsedFile,
    required this.analysis,
    required this.mapping,
    this.builder,
    this.cubit,
    this.onContinue,
    this.onCancel,
  });

  final LeadImportParsedFile parsedFile;
  final LeadImportStructureAnalysis analysis;
  final LeadImportColumnMapping mapping;
  final LeadImportPreviewBuilder? builder;
  final LeadImportPreviewCubit? cubit;
  final ValueChanged<LeadImportPreview>? onContinue;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _LeadImportPreviewView(
          onContinue: onContinue,
          onCancel: onCancel,
        ),
      );
    }

    return BlocProvider(
      create: (_) => LeadImportPreviewCubit(
        parsedFile: parsedFile,
        analysis: analysis,
        mapping: mapping,
        builder: builder,
      ),
      child: _LeadImportPreviewView(onContinue: onContinue, onCancel: onCancel),
    );
  }
}

class _LeadImportPreviewView extends StatelessWidget {
  const _LeadImportPreviewView({this.onContinue, this.onCancel});

  final ValueChanged<LeadImportPreview>? onContinue;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Preview'),
        leading: IconButton(
          key: const Key('lead_import_preview_back_button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: onCancel ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<LeadImportPreviewCubit, LeadImportPreviewState>(
          builder: (context, state) {
            if (state is LeadImportPreviewFailure) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    key: const Key('lead_import_preview_failure_card'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.error),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 36,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.message,
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed:
                              onCancel ??
                              () => Navigator.of(context).maybePop(),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (state is! LeadImportPreviewReady) {
              return const SizedBox.shrink();
            }

            final preview = state.preview;
            final hasWarnings = preview.rows.any(
              (r) => r.status == LeadImportPreviewRowStatus.blank,
            );

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: CustomScrollView(
                  key: const Key('lead_import_preview_scroll_view'),
                  slivers: [
                    // Top Summary and Metadata
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // File summary card
                            Container(
                              key: const Key('lead_import_preview_file_card'),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    preview.source == LeadSource.excel
                                        ? Icons.table_view_outlined
                                        : Icons.description_outlined,
                                    size: 28,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          preview.fileName,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              preview.source == LeadSource.excel
                                                  ? 'Excel (.xlsx)'
                                                  : 'CSV File',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                            Text(
                                              'Sheet: ${preview.sheetName}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                            Text(
                                              'Header: Row ${preview.headerRowIndex + 1}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Summary Statistics Card
                            Container(
                              key: const Key(
                                'lead_import_preview_summary_card',
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.spaceAround,
                                spacing: 16,
                                runSpacing: 10,
                                children: [
                                  _buildStatItem(
                                    context: context,
                                    label: 'Rows',
                                    value: '${preview.totalRowCount}',
                                    key: const Key(
                                      'lead_import_stat_total_rows',
                                    ),
                                  ),
                                  _buildStatItem(
                                    context: context,
                                    label: 'Valid',
                                    value: '${preview.validRowCount}',
                                    textColor: Colors.green.shade700,
                                    key: const Key(
                                      'lead_import_stat_valid_rows',
                                    ),
                                  ),
                                  _buildStatItem(
                                    context: context,
                                    label: 'Invalid',
                                    value: '${preview.invalidRowCount}',
                                    textColor: colorScheme.error,
                                    key: const Key(
                                      'lead_import_stat_invalid_rows',
                                    ),
                                  ),
                                  _buildStatItem(
                                    context: context,
                                    label: 'Blank',
                                    value: '${preview.blankRowCount}',
                                    textColor: colorScheme.onSurfaceVariant,
                                    key: const Key(
                                      'lead_import_stat_blank_rows',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Informational note for blank/invalid rows
                            if (hasWarnings)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Text(
                                  'Blank or invalid rows will be reviewed in the next step.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),

                            Text(
                              'Preview',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // True Lazy List of Preview Rows
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      sliver: SliverList.builder(
                        itemCount: preview.rows.length,
                        itemBuilder: (context, index) {
                          final row = preview.rows[index];
                          return _buildRowCard(context: context, row: row);
                        },
                      ),
                    ),

                    // Bottom Action Area
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (preview.validRowCount == 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Text(
                                  'No valid Lead rows are available to continue.',
                                  key: const Key(
                                    'lead_import_preview_no_valid_rows_text',
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            FilledButton(
                              key: const Key(
                                'lead_import_preview_continue_button',
                              ),
                              onPressed: preview.validRowCount > 0
                                  ? () => onContinue?.call(preview)
                                  : null,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required String label,
    required String value,
    Color? textColor,
    Key? key,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      key: key,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: textColor ?? colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildRowCard({
    required BuildContext context,
    required LeadImportPreviewRow row,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (badgeBg, badgeFg, statusLabel) = switch (row.status) {
      LeadImportPreviewRowStatus.valid => (
        Colors.green.shade100,
        Colors.green.shade900,
        'Valid',
      ),
      LeadImportPreviewRowStatus.invalid => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        'Invalid',
      ),
      LeadImportPreviewRowStatus.blank => (
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
        'Blank',
      ),
    };

    return Container(
      key: Key('lead_import_preview_row_${row.displayRowNumber}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Row ${row.displayRowNumber}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Mapped Field Values
          if (row.name != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.0),
              child: Text(
                'Name: ${row.name!.isEmpty ? '—' : row.name!}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (row.phone != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.0),
              child: Text(
                'Phone: ${row.phone!.isEmpty ? '—' : row.phone!}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (row.email != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.0),
              child: Text(
                'Email: ${row.email!.isEmpty ? '—' : row.email!}',
                style: theme.textTheme.bodySmall,
              ),
            ),

          // Issues list
          if (row.issues.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final issue in row.issues)
              Text(
                '• ${issue.message}',
                style: TextStyle(
                  fontSize: 12,
                  color: issue.severity == LeadImportPreviewIssueSeverity.error
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
