// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_import_models.dart';
import '../../domain/policies/inventory_import_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/inventory_import_cubit.dart';
import '../bloc/inventory_import_state.dart';
import '../services/inventory_import_file_picker.dart';
import '../services/inventory_import_error_report_service.dart';
import '../services/inventory_import_parser.dart';
import '../services/inventory_import_preview_builder.dart';
import '../services/inventory_export_file_delivery_service.dart';
import '../utils/inventory_display_formatters.dart';
import '../widgets/inventory_form_sections.dart';

/// Screen coordinating the full CSV/XLSX Inventory Import workflow.
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Import Inventory'), elevation: 0),
      body: BlocConsumer<InventoryImportCubit, InventoryImportState>(
        listener: (context, state) {
          if (state is InventoryImportErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: colorScheme.error,
              ),
            );
          }
        },
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
              message: 'Importing inventory items...',
            ),
            InventoryImportSuccessState(:final result) => _ResultView(
              result: result,
            ),
            InventoryImportErrorState(:final message, :final fallbackState) =>
              fallbackState != null
                  ? switch (fallbackState) {
                      InventoryImportMappingState() => _MappingView(
                        state: fallbackState,
                      ),
                      InventoryImportPreviewState() => _PreviewView(
                        state: fallbackState,
                      ),
                      _ => _ErrorView(message: message),
                    }
                  : _ErrorView(message: message),
          };
        },
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
    final cubit = context.read<InventoryImportCubit>();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 72,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Upload Inventory File',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Upload a CSV or Excel (.xlsx) file to create new inventory items or update existing records. You can configure column mapping, custom fields, and preview records before committing.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.description, size: 16),
                        label: const Text('CSV (.csv)'),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                      Chip(
                        avatar: const Icon(Icons.table_chart, size: 16),
                        label: const Text('Excel (.xlsx)'),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                      Chip(
                        avatar: const Icon(Icons.shield, size: 16),
                        label: const Text('Ledger Protected'),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    key: const Key('inventory_import_select_file_button'),
                    onPressed: () => cubit.pickAndParseFile(),
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Select File'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
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
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(message, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cubit = context.read<InventoryImportCubit>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Import Error',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => cubit.backToFileSelection(),
              icon: const Icon(Icons.refresh),
              label: const Text('Start Over'),
            ),
          ],
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
                'This Excel workbook contains multiple sheets. Choose which sheet represents your item-master records.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.file.sheets.length,
                  separatorBuilder: (context, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final sheet = state.file.sheets[i];
                    final isMasterCandidate =
                        sheet.name.trim().toLowerCase() == 'inventory_data';

                    return RadioListTile<int>(
                      key: Key('inventory_import_sheet_$i'),
                      value: i,
                      groupValue: state.selectedSheetIndex,
                      onChanged: (val) {
                        if (val != null) cubit.selectSheet(val);
                      },
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              sheet.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isMasterCandidate)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Recommended Item Master',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text('${sheet.rows.length} rows detected'),
                    );
                  },
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
                    child: const Text('Confirm Sheet'),
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
    final previewRows = sheet.rows.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
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
            'Select the row that contains your table column headers.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                columns: [
                  const DataColumn(label: Text('Row')),
                  for (
                    var c = 0;
                    c < (previewRows.isNotEmpty ? previewRows[0].length : 0);
                    c++
                  )
                    DataColumn(label: Text('Col ${c + 1}')),
                ],
                rows: List<DataRow>.generate(previewRows.length, (rowIdx) {
                  final isSelected = state.selectedHeaderRowIndex == rowIdx;
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (_) => cubit.selectHeaderRowIndex(rowIdx),
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Radio<int>(
                              key: Key('inventory_import_header_row_$rowIdx'),
                              value: rowIdx,
                              groupValue: state.selectedHeaderRowIndex,
                              onChanged: (val) {
                                if (val != null) {
                                  cubit.selectHeaderRowIndex(val);
                                }
                              },
                            ),
                            Text('Row ${rowIdx + 1}'),
                          ],
                        ),
                      ),
                      for (final cell in previewRows[rowIdx])
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              cell,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
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
                child: const Text('Confirm Header'),
              ),
            ],
          ),
        ],
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
    final user = cubit.user;
    final canManageCustomFields = InventoryImportPolicy.canManageCustomFields(
      user,
    );

    final isWide = MediaQuery.of(context).size.width >= 720;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
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
                      'Map columns from your spreadsheet to destination Inventory fields. Name and SKU are required. Unmapped columns can be mapped to standard fields, custom fields, or explicitly skipped.',
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

                    // Primary Required Fields Card
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Primary Required Fields',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildLegacyFieldRow(
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
                            _buildLegacyFieldRow(
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
                            _buildLegacyFieldRow(
                              context,
                              field: InventoryImportField.openingStock,
                              currentColumn:
                                  state.mapping.openingStockColumnIndex,
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

                    // Mode & Policy Configuration Card
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Import Settings & Conflict Policy',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<InventoryImportMode>(
                              isExpanded: true,
                              value: state.mapping.importMode,
                              decoration: const InputDecoration(
                                labelText: 'Import Mode',
                                border: OutlineInputBorder(),
                              ),
                              items: InventoryImportMode.values.map((mode) {
                                return DropdownMenuItem(
                                  value: mode,
                                  child: Text(
                                    mode.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (mode) {
                                if (mode != null) cubit.setImportMode(mode);
                              },
                            ),
                            if (state.mapping.importMode !=
                                InventoryImportMode.createOnly) ...[
                              const SizedBox(height: 16),
                              DropdownButtonFormField<BlankValuePolicy>(
                                isExpanded: true,
                                value: state.mapping.blankValuePolicy,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Blank Values Policy for Existing Items',
                                  border: OutlineInputBorder(),
                                ),
                                items: BlankValuePolicy.values.map((policy) {
                                  return DropdownMenuItem(
                                    value: policy,
                                    child: Text(
                                      policy.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (p) {
                                  if (p != null) cubit.setBlankValuePolicy(p);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Detailed Column-by-Column Source Mapping
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'All Discovered Columns (${state.availableColumns.length})',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (canManageCustomFields)
                                  TextButton.icon(
                                    onPressed: () => _openAddCustomFieldDialog(
                                      context,
                                      cubit,
                                    ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('New Custom Field'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: state.availableColumns.length,
                              separatorBuilder: (context, _) =>
                                  const Divider(height: 16),
                              itemBuilder: (context, colIdx) {
                                final colName = state.availableColumns[colIdx];
                                final isSkipped = state
                                    .mapping
                                    .skippedColumnIndices
                                    .contains(colIdx);
                                final standardField =
                                    state.mapping.standardFieldMappings[colIdx];
                                final customKey =
                                    state.mapping.customFieldMappings[colIdx];

                                return isWide
                                    ? Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  colName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  _getSampleCellValue(
                                                    state.sheet,
                                                    state.headerRowIndex,
                                                    colIdx,
                                                  ),
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            flex: 4,
                                            child:
                                                _buildColumnDestinationDropdown(
                                                  context,
                                                  cubit: cubit,
                                                  columnIndex: colIdx,
                                                  standardField: standardField,
                                                  customKey: customKey,
                                                  isSkipped: isSkipped,
                                                ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            colName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            _getSampleCellValue(
                                              state.sheet,
                                              state.headerRowIndex,
                                              colIdx,
                                            ),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          _buildColumnDestinationDropdown(
                                            context,
                                            cubit: cubit,
                                            columnIndex: colIdx,
                                            standardField: standardField,
                                            customKey: customKey,
                                            isSkipped: isSkipped,
                                          ),
                                        ],
                                      );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Sticky Bottom Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Row(
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
        ),
      ],
    );
  }

  String _getSampleCellValue(
    InventoryImportParsedSheet sheet,
    int headerRowIdx,
    int colIdx,
  ) {
    if (headerRowIdx + 1 < sheet.rows.length) {
      final sampleRow = sheet.rows[headerRowIdx + 1];
      if (colIdx < sampleRow.length && sampleRow[colIdx].trim().isNotEmpty) {
        return 'Sample: "${sampleRow[colIdx].trim()}"';
      }
    }
    return 'Sample: (empty)';
  }

  Widget _buildColumnDestinationDropdown(
    BuildContext context, {
    required InventoryImportCubit cubit,
    required int columnIndex,
    required InventoryImportField? standardField,
    required String? customKey,
    required bool isSkipped,
  }) {
    String currentValue = 'unmapped';
    if (isSkipped) {
      currentValue = 'skip';
    } else if (standardField != null) {
      currentValue = 'std:${standardField.name}';
    } else if (customKey != null) {
      currentValue = 'custom:$customKey';
    }

    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: 'unmapped',
        child: Text('-- Select Destination --'),
      ),
      const DropdownMenuItem(
        value: 'skip',
        child: Text('Explicit Skip (Do not import)'),
      ),
      ...InventoryImportField.values.map((f) {
        return DropdownMenuItem(
          value: 'std:${f.name}',
          child: Text(
            'Standard: ${f.label}${f.isRequired ? ' *' : ''}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }),
      ...state.customFieldDefinitions.map((def) {
        return DropdownMenuItem(
          value: 'custom:${def.key}',
          child: Text('Custom: ${def.label}', overflow: TextOverflow.ellipsis),
        );
      }),
    ];

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: items.any((it) => it.value == currentValue)
          ? currentValue
          : 'unmapped',
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items,
      onChanged: (val) {
        if (val == null || val == 'unmapped') {
          cubit.setColumnStandardField(columnIndex, null);
        } else if (val == 'skip') {
          cubit.setColumnSkipped(columnIndex, true);
        } else if (val.startsWith('std:')) {
          final fieldName = val.substring(4);
          final field = InventoryImportField.values.firstWhere(
            (f) => f.name == fieldName,
          );
          cubit.setFieldMapping(field, columnIndex);
        } else if (val.startsWith('custom:')) {
          final key = val.substring(7);
          cubit.setColumnCustomField(columnIndex, key);
        }
      },
    );
  }

  Widget _buildLegacyFieldRow(
    BuildContext context, {
    required InventoryImportField field,
    required int? currentColumn,
    required Key dropdownKey,
    required ValueChanged<int?> onChanged,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Text(
                field.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (field.isRequired)
                Text(
                  ' *',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int?>(
            key: dropdownKey,
            isExpanded: true,
            value: currentColumn,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Not Mapped'),
              ),
              for (var i = 0; i < state.availableColumns.length; i++)
                DropdownMenuItem<int?>(
                  value: i,
                  child: Text(
                    state.availableColumns[i],
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Future<void> _openAddCustomFieldDialog(
    BuildContext context,
    InventoryImportCubit cubit,
  ) async {
    final def = await showDialog<CustomFieldDefinition>(
      context: context,
      builder: (dialogCtx) =>
          AddCustomFieldDialog(repository: cubit.repository, user: cubit.user),
    );
    if (def != null) {
      cubit.addStagedCustomDefinition(def, -1);
    }
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

    final filteredRows = preview.rows.where((r) {
      if (state.filter == 'valid') {
        return r.status == InventoryImportRowStatus.valid ||
            r.status == InventoryImportRowStatus.warning;
      }
      if (state.filter == 'errors') {
        return r.status == InventoryImportRowStatus.invalid ||
            r.status == InventoryImportRowStatus.duplicate;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _SummaryChip(
                    key: const Key('inventory_import_summary_total'),
                    label: 'Total: ${preview.totalRows}',
                    color: colorScheme.primary,
                  ),
                  _SummaryChip(
                    label: 'Valid: ${preview.validCount}',
                    color: Colors.green,
                  ),
                  _SummaryChip(
                    label:
                        'Errors: ${preview.invalidCount + preview.duplicateCount}',
                    color: colorScheme.error,
                  ),
                  _SummaryChip(
                    label: 'Selected: ${preview.selectedCount}',
                    color: colorScheme.secondary,
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('All')),
                      ButtonSegment(value: 'valid', label: Text('Valid')),
                      ButtonSegment(value: 'errors', label: Text('Errors')),
                    ],
                    selected: {state.filter},
                    onSelectionChanged: (set) =>
                        cubit.setPreviewFilter(set.first),
                  ),
                  TextButton(
                    onPressed: () => cubit.selectAllValid(),
                    child: const Text('Select All Valid'),
                  ),
                  TextButton(
                    onPressed: () => cubit.deselectAll(),
                    child: const Text('Clear Selection'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Scrollable Preview Table
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Select')),
                  DataColumn(label: Text('Row #')),
                  DataColumn(label: Text('Action')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('SKU')),
                  DataColumn(label: Text('Product Name')),
                  DataColumn(label: Text('Qty / Stock')),
                  DataColumn(label: Text('Issues / Notes')),
                ],
                rows: filteredRows.map((row) {
                  return DataRow(
                    selected: row.isSelected,
                    onSelectChanged: row.isSelectable
                        ? (_) => cubit.toggleRowSelection(row.sourceRowNumber)
                        : null,
                    cells: [
                      DataCell(
                        Checkbox(
                          value: row.isSelected,
                          onChanged: row.isSelectable
                              ? (_) => cubit.toggleRowSelection(
                                  row.sourceRowNumber,
                                )
                              : null,
                        ),
                      ),
                      DataCell(Text('Row ${row.sourceRowNumber}')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: row.action == InventoryImportAction.create
                                ? Colors.blue.withValues(alpha: 0.15)
                                : Colors.purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            row.action.label,
                            style: TextStyle(
                              color: row.action == InventoryImportAction.create
                                  ? Colors.blue.shade800
                                  : Colors.purple.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(_StatusBadge(status: row.status)),
                      DataCell(Text(row.sku)),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            row.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.openingStock != null
                              ? InventoryDisplayFormatters.formatQuantity(
                                  row.openingStock!,
                                )
                              : '—',
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            row.errorMessage ?? row.warningMessage ?? '—',
                            style: TextStyle(
                              color: row.errorMessage != null
                                  ? colorScheme.error
                                  : colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // Bottom Actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => cubit.backToMapping(),
                child: const Text('Back to Mapping'),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                key: const Key('inventory_import_submit_button'),
                onPressed: preview.selectedCount > 0
                    ? () => cubit.executeImport()
                    : null,
                icon: const Icon(Icons.check),
                label: Text('Import (${preview.selectedCount} Rows)'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultView extends StatefulWidget {
  const _ResultView({required this.result});

  final InventoryImportResult result;

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  bool _isDownloading = false;

  Future<void> _downloadErrorReport() async {
    if (_isDownloading) return;
    final cubit = context.read<InventoryImportCubit>();
    setState(() => _isDownloading = true);
    final bytes = const InventoryImportErrorReportService().toBytes(
      widget.result.failures,
    );
    final delivery = await InventoryExportFileDeliveryService()
        .deliverImportErrorReport(
          bytes: bytes,
          currentUserProvider: () => cubit.user,
          boundUserId: cubit.user.id,
        );
    if (!mounted) return;
    setState(() => _isDownloading = false);
    final message = delivery.isDownloadInitiated || delivery.isSaved
        ? 'Import error report download started.'
        : (delivery.message ?? 'Unable to download the error report.');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cubit = context.read<InventoryImportCubit>();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    result.failureCount == 0
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    size: 72,
                    color: result.failureCount == 0
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Import Complete',
                    key: const Key('inventory_import_result_title'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Imported: ${result.successCount} | Failed: ${result.failureCount}',
                    key: const Key('inventory_import_result_summary'),
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _SummaryChip(
                        label: 'Requested: ${result.requestedCount}',
                        color: colorScheme.primary,
                      ),
                      _SummaryChip(
                        label: 'Created: ${result.effectiveCreatedCount}',
                        color: Colors.green,
                      ),
                      _SummaryChip(
                        label: 'Updated: ${result.effectiveUpdatedCount}',
                        color: Colors.purple,
                      ),
                      if (result.failureCount > 0)
                        _SummaryChip(
                          label: 'Failed: ${result.failureCount}',
                          color: colorScheme.error,
                        ),
                    ],
                  ),
                  if (result.failures.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Failure Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: result.failures.length,
                        itemBuilder: (context, i) {
                          final f = result.failures[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.error,
                              size: 16,
                              color: colorScheme.error,
                            ),
                            title: Text('Row ${f.sourceRowNumber} (${f.sku})'),
                            subtitle: Text(f.reason),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key(
                        'inventory_import_download_error_report_button',
                      ),
                      onPressed: _isDownloading ? null : _downloadErrorReport,
                      icon: _isDownloading
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined),
                      label: const Text('Download Error Report (CSV)'),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton(
                    key: const Key('inventory_import_done_button'),
                    onPressed: () => cubit.backToFileSelection(),
                    child: const Text('Done'),
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
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
      InventoryImportRowStatus.warning => ('Warning', Colors.orange),
      InventoryImportRowStatus.invalid => ('Invalid', Colors.red),
      InventoryImportRowStatus.duplicate => ('Duplicate', Colors.purple),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
