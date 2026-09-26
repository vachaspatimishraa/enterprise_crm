import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/entities/inventory_import_models.dart';
import '../../domain/policies/inventory_import_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/inventory_import_cubit.dart';
import '../bloc/inventory_import_state.dart';
import '../services/inventory_import_file_picker.dart';
import '../services/inventory_import_parser.dart';
import '../services/inventory_import_preview_builder.dart';
import '../utils/inventory_display_formatters.dart';

/// Admin-only screen coordinating the full CSV/XLSX Inventory Import workflow.
class InventoryImportScreen extends StatelessWidget {
  const InventoryImportScreen({
    super.key,
    required this.user,
    required this.repository,
    this.filePicker,
    this.parser,
    this.previewBuilder,
    this.cubit,
  });

  final CurrentUser user;
  final InventoryRepository repository;
  final InventoryImportFilePicker? filePicker;
  final InventoryImportParser? parser;
  final InventoryImportPreviewBuilder? previewBuilder;
  final InventoryImportCubit? cubit;

  @override
  Widget build(BuildContext context) {
    // Pre-Cubit route guard: zero Cubit initialization if unauthorized.
    if (!InventoryImportPolicy.canImport(user)) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider<InventoryImportCubit>(
      create: (_) =>
          cubit ??
          InventoryImportCubit(
            user: user,
            repository: repository,
            filePicker: filePicker ?? const DefaultInventoryImportFilePicker(),
            parser: parser ?? const DefaultInventoryImportParser(),
            previewBuilder:
                previewBuilder ?? const InventoryImportPreviewBuilder(),
          ),
      child: const _InventoryImportView(),
    );
  }
}

class _InventoryImportView extends StatelessWidget {
  const _InventoryImportView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Inventory'),
        leading: IconButton(
          key: const Key('inventory_import_back_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<InventoryImportCubit, InventoryImportState>(
          builder: (context, state) {
            return switch (state) {
              InventoryImportInitial() => const _FilePickerView(),
              InventoryImportLoading(:final message) => _LoadingView(
                message: message,
              ),
              InventoryImportSheetSelect() => _SheetSelectView(state: state),
              InventoryImportHeaderSelect() => _HeaderSelectView(state: state),
              InventoryImportMappingState() => _MappingView(state: state),
              InventoryImportPreviewState() => _PreviewView(state: state),
              InventoryImportSubmitting() => const _LoadingView(
                message: 'Importing items...',
              ),
              InventoryImportSuccessState(:final result) => _ResultView(
                result: result,
              ),
              InventoryImportErrorState(:final message, :final fallbackState) =>
                _ErrorView(message: message, fallbackState: fallbackState),
            };
          },
        ),
      ),
    );
  }
}

class _FilePickerView extends StatelessWidget {
  const _FilePickerView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Upload Inventory File',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supported file formats: .csv, .xlsx\nRequired fields: Name, SKU\nOptional field: Opening Stock',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('inventory_import_select_file_button'),
                    icon: const Icon(Icons.file_open),
                    label: const Text('Select File'),
                    onPressed: () => context
                        .read<InventoryImportCubit>()
                        .selectFileAndParse(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              key: Key('inventory_import_loading_indicator'),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.fallbackState});

  final String message;
  final InventoryImportState? fallbackState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                message,
                key: const Key('inventory_import_error_message'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('inventory_import_error_retry_button'),
                onPressed: () =>
                    context.read<InventoryImportCubit>().backToFileSelection(),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetSelectView extends StatelessWidget {
  const _SheetSelectView({required this.state});

  final InventoryImportSheetSelect state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<InventoryImportCubit>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Worksheet',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This Excel workbook contains multiple sheets. Choose the sheet to import.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: RadioGroup<int>(
                  groupValue: state.selectedSheetIndex,
                  onChanged: (val) {
                    if (val != null) cubit.selectSheetIndex(val);
                  },
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.file.sheets.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final sheet = state.file.sheets[index];
                      return RadioListTile<int>(
                        key: Key('inventory_import_sheet_$index'),
                        value: index,
                        title: Text(sheet.name),
                        subtitle: Text('${sheet.rows.length} rows'),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => cubit.backToFileSelection(),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    key: const Key('inventory_import_confirm_sheet_button'),
                    onPressed: () => cubit.confirmSheet(),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSelectView extends StatelessWidget {
  const _HeaderSelectView({required this.state});

  final InventoryImportHeaderSelect state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<InventoryImportCubit>();
    final sheet = state.sheet;
    final rowCountToPreview = sheet.rows.length < 5 ? sheet.rows.length : 5;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Header Row',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select which row contains the column titles. Data rows follow the header.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: RadioGroup<int>(
                  groupValue: state.selectedHeaderRowIndex,
                  onChanged: (val) {
                    if (val != null) cubit.selectHeaderRowIndex(val);
                  },
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rowCountToPreview,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = sheet.rows[index];
                      final previewText = row
                          .take(4)
                          .map((c) => c.isEmpty ? '[blank]' : c)
                          .join(' | ');

                      return RadioListTile<int>(
                        key: Key('inventory_import_header_row_$index'),
                        value: index,
                        title: Text(
                          'Row ${index + 1}: $previewText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => cubit.backToSheetSelection(),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    key: const Key('inventory_import_confirm_header_button'),
                    onPressed: () => cubit.confirmHeaderRow(),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MappingView extends StatelessWidget {
  const _MappingView({required this.state});

  final InventoryImportMappingState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cubit = context.read<InventoryImportCubit>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Map Columns',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Map columns from your file to the destination inventory fields. Name and SKU are required.',
                style: theme.textTheme.bodyMedium,
              ),
              if (state.validationError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.validationError!,
                    key: const Key('inventory_import_mapping_error'),
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildFieldRow(
                        context,
                        field: InventoryImportField.name,
                        currentColumn: state.mapping.nameColumnIndex,
                        dropdownKey: const Key(
                          'inventory_import_map_name_dropdown',
                        ),
                        onChanged: (idx) => cubit.setFieldMapping(
                          InventoryImportField.name,
                          idx,
                        ),
                      ),
                      const Divider(height: 24),
                      _buildFieldRow(
                        context,
                        field: InventoryImportField.sku,
                        currentColumn: state.mapping.skuColumnIndex,
                        dropdownKey: const Key(
                          'inventory_import_map_sku_dropdown',
                        ),
                        onChanged: (idx) => cubit.setFieldMapping(
                          InventoryImportField.sku,
                          idx,
                        ),
                      ),
                      const Divider(height: 24),
                      _buildFieldRow(
                        context,
                        field: InventoryImportField.openingStock,
                        currentColumn: state.mapping.openingStockColumnIndex,
                        dropdownKey: const Key(
                          'inventory_import_map_opening_stock_dropdown',
                        ),
                        onChanged: (idx) => cubit.setFieldMapping(
                          InventoryImportField.openingStock,
                          idx,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => cubit.backToHeaderSelection(),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    key: const Key('inventory_import_confirm_mapping_button'),
                    onPressed: () => cubit.confirmMapping(),
                    child: const Text('Preview Import'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldRow(
    BuildContext context, {
    required InventoryImportField field,
    required int? currentColumn,
    required Key dropdownKey,
    required ValueChanged<int?> onChanged,
  }) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 450;
        final labelWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field.label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              field.isRequired ? 'Required' : 'Optional',
              style: theme.textTheme.bodySmall?.copyWith(
                color: field.isRequired
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

        final dropdownWidget = DropdownButton<int?>(
          key: dropdownKey,
          value: currentColumn,
          isExpanded: true,
          hint: const Text('Select source column...'),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('(Not mapped)'),
            ),
            ...List.generate(state.availableColumns.length, (i) {
              return DropdownMenuItem<int?>(
                value: i,
                child: Text(
                  state.availableColumns[i],
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: onChanged,
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [labelWidget, const SizedBox(height: 8), dropdownWidget],
          );
        }

        return Row(
          children: [
            Expanded(flex: 2, child: labelWidget),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: dropdownWidget),
          ],
        );
      },
    );
  }
}

class _PreviewView extends StatelessWidget {
  const _PreviewView({required this.state});

  final InventoryImportPreviewState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cubit = context.read<InventoryImportCubit>();
    final preview = state.preview;

    return Column(
      children: [
        // Summary & Actions Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryChip(
                    key: const Key('inventory_import_summary_total'),
                    label: 'Total: ${preview.totalRows}',
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  _SummaryChip(
                    key: const Key('inventory_import_summary_valid'),
                    label: 'Valid: ${preview.validCount}',
                    color: Colors.green.withValues(alpha: 0.2),
                  ),
                  _SummaryChip(
                    key: const Key('inventory_import_summary_invalid'),
                    label: 'Invalid: ${preview.invalidCount}',
                    color: colorScheme.errorContainer,
                  ),
                  _SummaryChip(
                    key: const Key('inventory_import_summary_duplicate'),
                    label: 'Duplicate: ${preview.duplicateCount}',
                    color: Colors.orange.withValues(alpha: 0.2),
                  ),
                  _SummaryChip(
                    key: const Key('inventory_import_summary_selected'),
                    label: 'Selected: ${preview.selectedCount}',
                    color: colorScheme.primaryContainer,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    key: const Key('inventory_import_select_all_button'),
                    onPressed: () => cubit.selectAllValid(),
                    child: const Text('Select All Valid'),
                  ),
                  TextButton(
                    key: const Key('inventory_import_deselect_all_button'),
                    onPressed: () => cubit.deselectAll(),
                    child: const Text('Deselect All'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Rows List / Table
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 650;
              if (isCompact) {
                return _buildMobilePreviewList(context, preview, cubit);
              }
              return _buildDesktopPreviewTable(context, preview, cubit);
            },
          ),
        ),

        const Divider(height: 1),
        // Action Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: () => cubit.backToMapping(),
                child: const Text('Back'),
              ),
              FilledButton.icon(
                key: const Key('inventory_import_submit_button'),
                icon: const Icon(Icons.download),
                label: Text('Import ${preview.selectedCount} Items'),
                onPressed: preview.selectedCount > 0
                    ? () => cubit.executeImport()
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobilePreviewList(
    BuildContext context,
    InventoryImportPreview preview,
    InventoryImportCubit cubit,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: preview.rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = preview.rows[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  key: Key(
                    'inventory_import_row_checkbox_${row.sourceRowNumber}',
                  ),
                  value: row.isSelected,
                  onChanged: row.isSelectable
                      ? (_) => cubit.toggleRowSelection(row.sourceRowNumber)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Row ${row.sourceRowNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          _StatusBadge(status: row.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Name: ${row.name.isEmpty ? "(blank)" : row.name}'),
                      Text('SKU: ${row.sku.isEmpty ? "(blank)" : row.sku}'),
                      if (row.openingStock != null)
                        Text(
                          'Opening Stock: ${InventoryDisplayFormatters.formatQuantity(row.openingStock!)}',
                        ),
                      if (row.errorMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          row.errorMessage!,
                          key: Key(
                            'inventory_import_row_error_${row.sourceRowNumber}',
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopPreviewTable(
    BuildContext context,
    InventoryImportPreview preview,
    InventoryImportCubit cubit,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        padding: const EdgeInsets.all(16.0),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Select')),
            DataColumn(label: Text('Row')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Opening Stock')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Details')),
          ],
          rows: preview.rows.map((row) {
            return DataRow(
              cells: [
                DataCell(
                  Checkbox(
                    key: Key(
                      'inventory_import_row_checkbox_${row.sourceRowNumber}',
                    ),
                    value: row.isSelected,
                    onChanged: row.isSelectable
                        ? (_) => cubit.toggleRowSelection(row.sourceRowNumber)
                        : null,
                  ),
                ),
                DataCell(Text('${row.sourceRowNumber}')),
                DataCell(Text(row.name.isEmpty ? '(blank)' : row.name)),
                DataCell(Text(row.sku.isEmpty ? '(blank)' : row.sku)),
                DataCell(
                  Text(
                    row.openingStock != null
                        ? InventoryDisplayFormatters.formatQuantity(
                            row.openingStock!,
                          )
                        : '-',
                  ),
                ),
                DataCell(_StatusBadge(status: row.status)),
                DataCell(
                  Text(
                    row.errorMessage ?? '',
                    key: row.errorMessage != null
                        ? Key(
                            'inventory_import_row_error_${row.sourceRowNumber}',
                          )
                        : null,
                    style: TextStyle(
                      color: row.errorMessage != null
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final InventoryImportResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFullSuccess = result.failureCount == 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                isFullSuccess
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                size: 64,
                color: isFullSuccess ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'Import Complete',
                key: const Key('inventory_import_result_title'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Imported: ${result.successCount} | Failed: ${result.failureCount}',
                key: const Key('inventory_import_result_summary'),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (result.failures.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Failed Rows:',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: result.failures.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final failure = result.failures[index];
                      return ListTile(
                        key: Key('inventory_import_failure_item_$index'),
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.errorContainer,
                          child: Text(
                            '${failure.sourceRowNumber}',
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text('SKU: ${failure.sku}'),
                        subtitle: Text(
                          failure.reason,
                          style: TextStyle(color: colorScheme.error),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                key: const Key('inventory_import_done_button'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final InventoryImportRowStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      InventoryImportRowStatus.valid => ('Valid', Colors.green),
      InventoryImportRowStatus.invalid => (
        'Invalid',
        Theme.of(context).colorScheme.error,
      ),
      InventoryImportRowStatus.duplicate => ('Duplicate', Colors.orange),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
