import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/lead_source.dart';
import '../bloc/lead_import_mapping_cubit.dart';
import '../bloc/lead_import_mapping_state.dart';
import '../models/lead_import_column_mapping.dart';
import '../models/lead_import_parsed_file.dart';
import '../models/lead_import_structure_analysis.dart';

class LeadImportMappingScreen extends StatelessWidget {
  const LeadImportMappingScreen({
    super.key,
    required this.parsedFile,
    required this.analysis,
    this.cubit,
    this.onContinue,
    this.onCancel,
  });

  final LeadImportParsedFile parsedFile;
  final LeadImportStructureAnalysis analysis;
  final LeadImportMappingCubit? cubit;
  final ValueChanged<LeadImportColumnMapping>? onContinue;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _LeadImportMappingView(
          onContinue: onContinue,
          onCancel: onCancel,
        ),
      );
    }

    return BlocProvider(
      create: (_) =>
          LeadImportMappingCubit(parsedFile: parsedFile, analysis: analysis),
      child: _LeadImportMappingView(onContinue: onContinue, onCancel: onCancel),
    );
  }
}

class _LeadImportMappingView extends StatelessWidget {
  const _LeadImportMappingView({this.onContinue, this.onCancel});

  final ValueChanged<LeadImportColumnMapping>? onContinue;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cubit = context.read<LeadImportMappingCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Lead Fields'),
        leading: IconButton(
          key: const Key('lead_import_mapping_back_button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: onCancel ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: BlocBuilder<LeadImportMappingCubit, LeadImportMappingState>(
              builder: (context, state) {
                final analysis = state.analysis;
                final mapping = state.mapping;
                final hasWarnings = analysis.issues.any(
                  (i) => i.severity == LeadImportStructureIssueSeverity.warning,
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // File & Sheet Summary Card
                      Container(
                        key: const Key('lead_import_mapping_file_card'),
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
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        analysis.source == LeadSource.excel
                                            ? 'Excel (.xlsx)'
                                            : 'CSV File',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                      Text(
                                        'Sheet: ${analysis.sheetName ?? "—"}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                      Text(
                                        'Header: Row ${analysis.headerRowIndex + 1}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
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
                      const SizedBox(height: 20),

                      // Section Title & Guidance
                      Text(
                        'Choose which spreadsheet column should fill each Lead field.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Blocking Errors Banner (if any)
                      if (analysis.hasBlockingErrors) ...[
                        Container(
                          key: const Key('lead_import_mapping_errors_banner'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorScheme.error),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final err in analysis.issues.where(
                                (i) =>
                                    i.severity ==
                                    LeadImportStructureIssueSeverity.error,
                              ))
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

                      // Non-blocking Structure Warning Reminder
                      if (hasWarnings) ...[
                        Container(
                          key: const Key('lead_import_mapping_warnings_banner'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorScheme.tertiary),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: colorScheme.tertiary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This file contains blank or duplicate column headers. Each column remains distinct by column number.',
                                  style: TextStyle(
                                    color: colorScheme.onTertiaryContainer,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Mapping Fields
                      _buildFieldMapping(
                        context: context,
                        label: 'Lead Name',
                        fieldKey: const Key('lead_import_field_name_dropdown'),
                        currentValue: mapping.nameColumnIndex,
                        columns: analysis.columns,
                        onChanged: (colIndex) => cubit.mapNameTo(colIndex),
                      ),
                      const SizedBox(height: 16),

                      _buildFieldMapping(
                        context: context,
                        label: 'Phone',
                        fieldKey: const Key('lead_import_field_phone_dropdown'),
                        currentValue: mapping.phoneColumnIndex,
                        columns: analysis.columns,
                        onChanged: (colIndex) => cubit.mapPhoneTo(colIndex),
                      ),
                      const SizedBox(height: 16),

                      _buildFieldMapping(
                        context: context,
                        label: 'Email',
                        fieldKey: const Key('lead_import_field_email_dropdown'),
                        currentValue: mapping.emailColumnIndex,
                        columns: analysis.columns,
                        onChanged: (colIndex) => cubit.mapEmailTo(colIndex),
                      ),
                      const SizedBox(height: 24),

                      // Minimum Mapping Validation Note
                      if (!mapping.hasAnyMapping && !analysis.hasBlockingErrors)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            'Map at least one Lead field to continue.',
                            key: const Key(
                              'lead_import_mapping_validation_text',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      // Continue Button
                      FilledButton(
                        key: const Key('lead_import_mapping_continue_button'),
                        onPressed: state.canContinue
                            ? () => onContinue?.call(mapping)
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

  Widget _buildFieldMapping({
    required BuildContext context,
    required String label,
    required Key fieldKey,
    required int? currentValue,
    required List<LeadImportDiscoveredColumn> columns,
    required ValueChanged<int?> onChanged,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              key: fieldKey,
              value: currentValue,
              isExpanded: true,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Not mapped'),
                ),
                for (final col in columns)
                  DropdownMenuItem<int?>(
                    value: col.index,
                    child: Text(
                      'Column ${col.index + 1} — ${col.displayHeader}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
