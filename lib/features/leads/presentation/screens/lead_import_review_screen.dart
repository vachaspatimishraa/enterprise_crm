import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/lead_source.dart';
import '../bloc/lead_import_review_cubit.dart';
import '../bloc/lead_import_review_state.dart';
import '../models/lead_import_preview.dart';
import '../models/lead_import_review.dart';
import '../services/lead_import_duplicate_detector.dart';

class LeadImportReviewScreen extends StatelessWidget {
  const LeadImportReviewScreen({
    super.key,
    required this.preview,
    this.duplicateDetector,
    this.cubit,
    this.onContinue,
    this.onCancel,
  });

  final LeadImportPreview preview;
  final LeadImportDuplicateDetector? duplicateDetector;
  final LeadImportReviewCubit? cubit;
  final ValueChanged<LeadImportReviewDecision>? onContinue;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _LeadImportReviewView(
          onContinue: onContinue,
          onCancel: onCancel,
        ),
      );
    }

    return BlocProvider(
      create: (_) => LeadImportReviewCubit(
        preview: preview,
        duplicateDetector: duplicateDetector,
      ),
      child: _LeadImportReviewView(onContinue: onContinue, onCancel: onCancel),
    );
  }
}

class _LeadImportReviewView extends StatelessWidget {
  const _LeadImportReviewView({this.onContinue, this.onCancel});

  final ValueChanged<LeadImportReviewDecision>? onContinue;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cubit = context.read<LeadImportReviewCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Final Import Review'),
        leading: IconButton(
          key: const Key('lead_import_review_back_button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: onCancel ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<LeadImportReviewCubit, LeadImportReviewState>(
          builder: (context, state) {
            final preview = state.preview;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: CustomScrollView(
                  key: const Key('lead_import_review_scroll_view'),
                  slivers: [
                    // Top Summary and Duplicate Warnings
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // File summary card
                            Container(
                              key: const Key('lead_import_review_file_card'),
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
                              key: const Key('lead_import_review_summary_card'),
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
                                    label: 'Total rows',
                                    value: '${preview.totalRowCount}',
                                    key: const Key(
                                      'lead_import_review_stat_total_rows',
                                    ),
                                  ),
                                  _buildStatItem(
                                    context: context,
                                    label: 'Valid',
                                    value: '${preview.validRowCount}',
                                    textColor: Colors.green.shade700,
                                    key: const Key(
                                      'lead_import_review_stat_valid_rows',
                                    ),
                                  ),
                                  _buildStatItem(
                                    context: context,
                                    label: 'Invalid',
                                    value: '${preview.invalidRowCount}',
                                    textColor: colorScheme.error,
                                    key: const Key(
                                      'lead_import_review_stat_invalid_rows',
                                    ),
                                  ),
                                  _buildStatItem(
                                    context: context,
                                    label: 'Blank',
                                    value: '${preview.blankRowCount}',
                                    textColor: colorScheme.onSurfaceVariant,
                                    key: const Key(
                                      'lead_import_review_stat_blank_rows',
                                    ),
                                  ),
                                  _buildStatItem(
                                    context: context,
                                    label: 'Selected for import',
                                    value: '${state.includedValidRowCount}',
                                    textColor: colorScheme.primary,
                                    key: const Key(
                                      'lead_import_review_stat_selected_rows',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Duplicate Statistics Section (if duplicates exist)
                            if (state.duplicateGroupCount > 0) ...[
                              const SizedBox(height: 16),
                              Container(
                                key: const Key(
                                  'lead_import_review_duplicate_stats_card',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
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
                                      label: 'Exact duplicate groups',
                                      value: '${state.duplicateGroupCount}',
                                      textColor: Colors.amber.shade800,
                                      key: const Key(
                                        'lead_import_review_stat_duplicate_groups',
                                      ),
                                    ),
                                    _buildStatItem(
                                      context: context,
                                      label: 'Rows in duplicate groups',
                                      value: '${state.rowsInDuplicateGroups}',
                                      textColor: Colors.amber.shade800,
                                      key: const Key(
                                        'lead_import_review_stat_rows_in_duplicate_groups',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Duplicate Warning Banner
                              Container(
                                key: const Key(
                                  'lead_import_review_duplicate_banner',
                                ),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber.shade300,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.amber.shade900,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Exact duplicate rows were found in this file.',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'They remain selected by default. Review and uncheck any rows you do not want to import.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Bulk Selection Controls
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Candidate Rows',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    TextButton(
                                      key: const Key(
                                        'lead_import_review_include_all_button',
                                      ),
                                      onPressed: () => cubit.includeAllValid(),
                                      child: const Text('Include all valid'),
                                    ),
                                    TextButton(
                                      key: const Key(
                                        'lead_import_review_exclude_all_button',
                                      ),
                                      onPressed: () => cubit.excludeAllValid(),
                                      child: const Text('Exclude all valid'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Lazy List of Preview Rows with Checkboxes
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      sliver: SliverList.builder(
                        itemCount: preview.rows.length,
                        itemBuilder: (context, index) {
                          final row = preview.rows[index];
                          final duplicateGroup = state.duplicateGroupFor(
                            row.sourceRowIndex,
                          );

                          return _buildRowCard(
                            context: context,
                            row: row,
                            isIncluded: state.includedSourceRowIndices.contains(
                              row.sourceRowIndex,
                            ),
                            duplicateGroup: duplicateGroup,
                            onToggle:
                                row.status == LeadImportPreviewRowStatus.valid
                                ? () => cubit.toggleRow(row.sourceRowIndex)
                                : null,
                          );
                        },
                      ),
                    ),

                    // Bottom Continue Action Area
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!state.canContinue)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Text(
                                  'Select at least one valid Lead row to continue.',
                                  key: const Key(
                                    'lead_import_review_no_selection_text',
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
                                'lead_import_review_continue_button',
                              ),
                              onPressed: state.canContinue
                                  ? () =>
                                        onContinue?.call(cubit.createDecision())
                                  : null,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: const Text(
                                'Continue to Import',
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
    required bool isIncluded,
    required LeadImportExactDuplicateGroup? duplicateGroup,
    required VoidCallback? onToggle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isValid = row.status == LeadImportPreviewRowStatus.valid;

    final (badgeBg, badgeFg, statusLabel) = switch (row.status) {
      LeadImportPreviewRowStatus.valid => (
        Colors.green.shade100,
        Colors.green.shade900,
        'Ready',
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
      key: Key('lead_import_review_row_${row.displayRowNumber}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isIncluded ? colorScheme.primary : colorScheme.outlineVariant,
          width: isIncluded ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Checkbox for valid rows, disabled checkbox for invalid/blank
              Checkbox(
                key: Key('lead_import_review_checkbox_${row.displayRowNumber}'),
                value: isValid ? isIncluded : false,
                onChanged: isValid ? (_) => onToggle?.call() : null,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Row ${row.displayRowNumber}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: badgeFg,
                        ),
                      ),
                    ),
                    if (isValid && duplicateGroup != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Exact duplicate in file',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    if (!isValid)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Excluded from import',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Duplicate group context
          if (isValid && duplicateGroup != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 44.0, bottom: 4.0),
              child: Text(
                'Duplicate group: Rows ${duplicateGroup.sourceRowIndices.map((i) => i + 1).join(', ')}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],

          // Mapped Field Values
          Padding(
            padding: const EdgeInsets.only(left: 44.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

                // Issues list for invalid or blank rows
                if (row.issues.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  for (final issue in row.issues)
                    Text(
                      '• ${issue.message}',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            issue.severity ==
                                LeadImportPreviewIssueSeverity.error
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
