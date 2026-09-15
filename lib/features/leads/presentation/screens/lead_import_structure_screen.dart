import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/lead_source.dart';
import '../bloc/lead_import_structure_cubit.dart';
import '../bloc/lead_import_structure_state.dart';
import '../models/lead_import_parsed_file.dart';
import '../models/lead_import_structure_analysis.dart';
import '../services/lead_import_structure_analyzer.dart';

class LeadImportStructureScreen extends StatelessWidget {
  const LeadImportStructureScreen({
    super.key,
    required this.parsedFile,
    this.analyzer,
    this.cubit,
    this.onContinue,
    this.onCancel,
  });

  final LeadImportParsedFile parsedFile;
  final LeadImportStructureAnalyzer? analyzer;
  final LeadImportStructureCubit? cubit;
  final ValueChanged<LeadImportStructureAnalysis>? onContinue;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _LeadImportStructureView(
          onContinue: onContinue,
          onCancel: onCancel,
        ),
      );
    }

    return BlocProvider(
      create: (_) =>
          LeadImportStructureCubit(parsedFile: parsedFile, analyzer: analyzer),
      child: _LeadImportStructureView(
        onContinue: onContinue,
        onCancel: onCancel,
      ),
    );
  }
}

class _LeadImportStructureView extends StatelessWidget {
  const _LeadImportStructureView({this.onContinue, this.onCancel});

  final ValueChanged<LeadImportStructureAnalysis>? onContinue;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cubit = context.read<LeadImportStructureCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prepare Import'),
        leading: IconButton(
          key: const Key('lead_import_structure_back_button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: onCancel ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: BlocBuilder<LeadImportStructureCubit, LeadImportStructureState>(
              builder: (context, state) {
                final analysis = state.analysis;
                final sheets = state.parsedFile.sheets;
                final isMultiSheet = sheets.length > 1;
                final currentSheet = state.selectedSheetIndex < sheets.length
                    ? sheets[state.selectedSheetIndex]
                    : null;
                final availableRowsCount = currentSheet?.rows.length ?? 0;

                final blockingErrors = analysis.issues
                    .where(
                      (i) =>
                          i.severity == LeadImportStructureIssueSeverity.error,
                    )
                    .toList();
                final warnings = analysis.issues
                    .where(
                      (i) =>
                          i.severity ==
                          LeadImportStructureIssueSeverity.warning,
                    )
                    .toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // File metadata card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              analysis.source == LeadSource.excel
                                  ? Icons.table_view_outlined
                                  : Icons.description_outlined,
                              size: 28,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    analysis.fileName,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    analysis.source == LeadSource.excel
                                        ? 'Excel (.xlsx)'
                                        : 'CSV File',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sheet Selector (if multi-sheet XLSX)
                      if (isMultiSheet) ...[
                        Text(
                          'Sheet',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          key: const Key('lead_import_sheet_selector'),
                          isExpanded: true,
                          initialValue: state.selectedSheetIndex,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            for (var i = 0; i < sheets.length; i++)
                              DropdownMenuItem<int>(
                                value: i,
                                child: Text(
                                  sheets[i].name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (newIndex) {
                            if (newIndex != null) {
                              cubit.selectSheet(newIndex);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Sheet: ',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              analysis.sheetName ?? '—',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Header Row Selector
                      if (availableRowsCount > 0) ...[
                        Text(
                          'Header Row',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          key: const Key('lead_import_header_row_selector'),
                          isExpanded: true,
                          initialValue:
                              state.selectedHeaderRowIndex < availableRowsCount
                              ? state.selectedHeaderRowIndex
                              : 0,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            for (
                              var i = 0;
                              i <
                                  (availableRowsCount > 50
                                      ? 50
                                      : availableRowsCount);
                              i++
                            )
                              DropdownMenuItem<int>(
                                value: i,
                                child: Text('Row ${i + 1}'),
                              ),
                          ],
                          onChanged: (newRow) {
                            if (newRow != null) {
                              cubit.selectHeaderRow(newRow);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Blocking Errors Banner
                      if (blockingErrors.isNotEmpty) ...[
                        Container(
                          key: const Key('lead_import_errors_banner'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorScheme.error),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final err in blockingErrors)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2.0,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 18,
                                        color: colorScheme.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          err.message,
                                          style: TextStyle(
                                            color: colorScheme.onErrorContainer,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Warnings Banner
                      if (warnings.isNotEmpty) ...[
                        Container(
                          key: const Key('lead_import_warnings_banner'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorScheme.tertiary),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final w in warnings)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2.0,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.warning_amber_outlined,
                                        size: 18,
                                        color: colorScheme.tertiary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          w.message,
                                          style: TextStyle(
                                            color:
                                                colorScheme.onTertiaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Detected Columns Card
                      if (analysis.columns.isNotEmpty) ...[
                        Container(
                          key: const Key('lead_import_detected_columns_card'),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'Detected Columns (${analysis.columns.length})',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    'Data rows: ${analysis.dataRowCount}',
                                    key: const Key(
                                      'lead_import_data_rows_text',
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                key: const Key(
                                  'lead_import_detected_columns_list',
                                ),
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final col in analysis.columns)
                                    Chip(
                                      avatar: CircleAvatar(
                                        backgroundColor:
                                            colorScheme.secondaryContainer,
                                        child: Text(
                                          '${col.index + 1}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme
                                                .onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                      label: Text(
                                        col.displayHeader,
                                        style: TextStyle(
                                          fontStyle: col.isBlankHeader
                                              ? FontStyle.italic
                                              : FontStyle.normal,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Continue Button
                      FilledButton(
                        key: const Key('lead_import_structure_continue_button'),
                        onPressed: analysis.isValid
                            ? () => onContinue?.call(analysis)
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
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
