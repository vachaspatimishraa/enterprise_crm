import 'package:flutter/material.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../data/repositories/mock_inventory_repository.dart';
import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_import_models.dart';
import '../../domain/policies/inventory_field_access_policy.dart';
import '../../domain/policies/inventory_import_policy.dart';
import '../../domain/policies/inventory_item_administration_policy.dart';
import '../../domain/repositories/inventory_repository.dart';

/// Spreadsheet-style multi-row manual entry for inventory item masters.
///
/// Rows are committed through the same repository import boundary as CSV/XLSX
/// imports. That keeps SKU uniqueness, standard-field validation, opening-stock
/// ledger writes, and row-level failure reporting identical across entry modes.
class InventoryBulkEntryScreen extends StatefulWidget {
  const InventoryBulkEntryScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  final CurrentUser user;
  final InventoryRepository repository;

  @override
  State<InventoryBulkEntryScreen> createState() =>
      _InventoryBulkEntryScreenState();
}

class _BulkColumn {
  const _BulkColumn(this.keyName, this.label, {this.width = 150});

  final String keyName;
  final String label;
  final double width;
}

class _BulkRow {
  _BulkRow(Iterable<String> keys)
    : controllers = {for (final key in keys) key: TextEditingController()};

  final Map<String, TextEditingController> controllers;

  String value(String key) => controllers[key]?.text.trim() ?? '';

  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}

class _InventoryBulkEntryScreenState extends State<InventoryBulkEntryScreen> {
  static const _standardColumns = <_BulkColumn>[
    _BulkColumn('name', 'Product Name', width: 190),
    _BulkColumn('sku', 'SKU', width: 150),
    _BulkColumn('category', 'Category'),
    _BulkColumn('brand', 'Brand'),
    _BulkColumn('unit', 'Unit'),
    _BulkColumn('barcode', 'Barcode'),
    _BulkColumn('warehouse', 'Warehouse'),
    _BulkColumn('binLocation', 'Bin Location'),
    _BulkColumn('supplier', 'Supplier'),
    _BulkColumn('unitCostInr', 'Unit Cost (INR)'),
    _BulkColumn('sellingPriceInr', 'Selling Price (INR)'),
    _BulkColumn('openingStock', 'Opening Stock'),
    _BulkColumn('reorderLevel', 'Reorder Level'),
    _BulkColumn('maxStock', 'Max Stock'),
    _BulkColumn('gstPercent', 'GST %'),
    _BulkColumn('batchNumber', 'Batch Number'),
    _BulkColumn('expiryDate', 'Expiry Date (YYYY-MM-DD)'),
    _BulkColumn('lastRestockedDate', 'Last Restocked (YYYY-MM-DD)'),
    _BulkColumn('isActive', 'Is Active (true/false)'),
    _BulkColumn('notes', 'Notes', width: 220),
  ];

  final List<_BulkRow> _rows = [];
  List<CustomFieldDefinition> _customDefinitions = const [];
  final Set<String> _selectedColumnKeys = {
    for (final column in _standardColumns) column.keyName,
  };
  bool _isSaving = false;
  InventoryImportResult? _result;
  String? _fatalMessage;

  List<_BulkColumn> get _allColumns => [
    ..._standardColumns.where((column) {
      if (column.keyName == 'unitCostInr') {
        return InventoryFieldAccessPolicy.canViewCost(widget.user);
      }
      if (column.keyName == 'supplier') {
        return InventoryFieldAccessPolicy.canViewSupplier(widget.user);
      }
      return true;
    }),
    ..._customDefinitions.map(
      (definition) => _BulkColumn(
        'custom:${definition.key}',
        '${definition.label} (Custom)',
        width: 180,
      ),
    ),
  ];

  List<_BulkColumn> get _columns => [
    for (final column in _allColumns)
      if (_selectedColumnKeys.contains(column.keyName)) column,
  ];

  Iterable<String> get _columnKeys =>
      _allColumns.map((column) => column.keyName);

  @override
  void initState() {
    super.initState();
    _addRow();
    _addRow();
    _addRow();
    _loadDefinitions();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDefinitions() async {
    final repository = widget.repository;
    if (repository is MockInventoryRepository) {
      final definitions = await repository.getCustomFieldDefinitions();
      if (!mounted) return;
      setState(() {
        _customDefinitions = definitions;
        _selectedColumnKeys.addAll(
          definitions.map((definition) => 'custom:${definition.key}'),
        );
        for (final row in _rows) {
          for (final key in _columnKeys) {
            row.controllers.putIfAbsent(key, TextEditingController.new);
          }
        }
      });
    }
  }

  void _addRow() {
    if (_rows.length >= 100) return;
    setState(() => _rows.add(_BulkRow(_columnKeys)));
  }

  void _removeRow(int index) {
    if (_rows.length == 1) return;
    setState(() {
      _rows.removeAt(index).dispose();
    });
  }

  Future<void> _openColumnSelector() async {
    final draftSelectedColumnKeys = Set<String>.from(_selectedColumnKeys);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final columns = _allColumns;
            return AlertDialog(
              key: const Key('inventory_bulk_entry_column_selector_dialog'),
              title: const Text('Select columns'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Choose the fields shown in the entry grid. Name and SKU are always required.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final column in columns)
                        CheckboxListTile(
                          key: Key(
                            'inventory_bulk_entry_column_${column.keyName}',
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(column.label),
                          value: draftSelectedColumnKeys.contains(
                            column.keyName,
                          ),
                          onChanged:
                              column.keyName == 'name' ||
                                  column.keyName == 'sku'
                              ? null
                              : (selected) {
                                  setDialogState(() {
                                    if (selected == true) {
                                      draftSelectedColumnKeys.add(
                                        column.keyName,
                                      );
                                    } else {
                                      draftSelectedColumnKeys.remove(
                                        column.keyName,
                                      );
                                    }
                                  });
                                },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  key: const Key('inventory_bulk_entry_column_selector_cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('inventory_bulk_entry_column_selector_done'),
                  onPressed: () {
                    setState(() {
                      _selectedColumnKeys
                        ..clear()
                        ..addAll(draftSelectedColumnKeys);
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Apply columns'),
                ),
              ],
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  bool _hasData(_BulkRow row) =>
      _columnKeys.any((key) => row.value(key).isNotEmpty);

  double? _number(String value, String label, List<String> errors) {
    if (value.isEmpty) return null;
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite) {
      errors.add('$label must be a finite number.');
      return null;
    }
    return parsed;
  }

  DateTime? _date(String value, String label, List<String> errors) {
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) errors.add('$label must use YYYY-MM-DD format.');
    return parsed;
  }

  bool _boolean(String value, List<String> errors) {
    if (value.isEmpty) return true;
    final normalized = value.toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    errors.add('Is Active must be true or false.');
    return true;
  }

  dynamic _customValue(
    _BulkRow row,
    CustomFieldDefinition definition,
    List<String> errors,
  ) {
    final raw = row.value('custom:${definition.key}');
    if (raw.isEmpty) return definition.defaultValue;
    switch (definition.dataType) {
      case CustomFieldDataType.text:
        return raw;
      case CustomFieldDataType.number:
        final number = double.tryParse(raw);
        if (number == null || !number.isFinite) {
          errors.add('${definition.label} must be a finite number.');
          return null;
        }
        return number;
      case CustomFieldDataType.date:
        final date = DateTime.tryParse(raw);
        if (date == null) {
          errors.add('${definition.label} must use YYYY-MM-DD format.');
        }
        return date;
      case CustomFieldDataType.boolean:
        return _boolean(raw, errors);
      case CustomFieldDataType.dropdown:
        if (!definition.options.contains(raw)) {
          errors.add('${definition.label} must match a configured option.');
          return null;
        }
        return raw;
    }
  }

  InventoryImportRowInput? _toInput(
    _BulkRow row,
    int sourceRow,
    List<InventoryImportRowFailure> failures,
  ) {
    final errors = <String>[];
    final name = row.value('name');
    final sku = row.value('sku');
    if (name.isEmpty) errors.add('Product Name is required.');
    if (sku.isEmpty) errors.add('SKU is required.');

    final openingStock = _number(
      row.value('openingStock'),
      'Opening Stock',
      errors,
    );
    if (openingStock != null && openingStock < 0) {
      errors.add('Opening Stock cannot be negative.');
    }
    if (openingStock != null &&
        openingStock > 0 &&
        !InventoryImportPolicy.canImportWithStock(widget.user)) {
      errors.add('Stock Management permission is required for opening stock.');
    }
    final reorderLevel = _number(
      row.value('reorderLevel'),
      'Reorder Level',
      errors,
    );
    final maxStock = _number(row.value('maxStock'), 'Max Stock', errors);
    if (reorderLevel != null && reorderLevel < 0) {
      errors.add('Reorder Level cannot be negative.');
    }
    if (maxStock != null && maxStock < 0) {
      errors.add('Max Stock cannot be negative.');
    }
    if (maxStock != null && reorderLevel != null && maxStock < reorderLevel) {
      errors.add('Max Stock cannot be lower than Reorder Level.');
    }
    final unitCost = _number(row.value('unitCostInr'), 'Unit Cost', errors);
    final sellingPrice = _number(
      row.value('sellingPriceInr'),
      'Selling Price',
      errors,
    );
    final gst = _number(row.value('gstPercent'), 'GST', errors);
    if (unitCost != null && unitCost < 0) {
      errors.add('Unit Cost cannot be negative.');
    }
    if (sellingPrice != null && sellingPrice < 0) {
      errors.add('Selling Price cannot be negative.');
    }
    if (gst != null && (gst < 0 || gst > 100)) {
      errors.add('GST must be between 0 and 100.');
    }
    final expiry = _date(row.value('expiryDate'), 'Expiry Date', errors);
    final restocked = _date(
      row.value('lastRestockedDate'),
      'Last Restocked Date',
      errors,
    );
    final isActive = _boolean(row.value('isActive'), errors);

    final customFields = <String, dynamic>{};
    for (final definition in _customDefinitions) {
      final value = _customValue(row, definition, errors);
      if (value != null) customFields[definition.key] = value;
      if (definition.isRequired && value == null) {
        errors.add('${definition.label} is required.');
      }
    }

    if (errors.isNotEmpty) {
      failures.add(
        InventoryImportRowFailure(
          sourceRowNumber: sourceRow,
          sku: sku,
          reason: errors.join(' '),
        ),
      );
      return null;
    }

    return InventoryImportRowInput(
      sourceRowNumber: sourceRow,
      name: name,
      sku: sku,
      openingStock: openingStock == 0 ? null : openingStock,
      category: row.value('category').isEmpty ? null : row.value('category'),
      brand: row.value('brand').isEmpty ? null : row.value('brand'),
      unit: row.value('unit').isEmpty ? null : row.value('unit'),
      barcode: row.value('barcode').isEmpty ? null : row.value('barcode'),
      warehouse: row.value('warehouse').isEmpty ? null : row.value('warehouse'),
      binLocation: row.value('binLocation').isEmpty
          ? null
          : row.value('binLocation'),
      supplier: row.value('supplier').isEmpty ? null : row.value('supplier'),
      unitCostInr: unitCost,
      sellingPriceInr: sellingPrice,
      reorderLevel: reorderLevel,
      maxStock: maxStock,
      gstPercent: gst,
      batchNumber: row.value('batchNumber').isEmpty
          ? null
          : row.value('batchNumber'),
      expiryDate: expiry,
      lastRestockedDate: restocked,
      isActive: isActive,
      notes: row.value('notes').isEmpty ? null : row.value('notes'),
      customFields: customFields,
    );
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!InventoryItemAdministrationPolicy.canCreate(widget.user)) {
      setState(
        () =>
            _fatalMessage = 'You are not authorized to create inventory items.',
      );
      return;
    }
    final failures = <InventoryImportRowFailure>[];
    final inputs = <InventoryImportRowInput>[];
    var sourceRow = 2;
    for (final row in _rows.where(_hasData)) {
      final input = _toInput(row, sourceRow, failures);
      if (input != null) inputs.add(input);
      sourceRow++;
    }
    if (inputs.isEmpty && failures.isEmpty) {
      setState(() => _fatalMessage = 'Enter at least one inventory row.');
      return;
    }

    setState(() {
      _isSaving = true;
      _fatalMessage = null;
      _result = null;
    });

    InventoryImportResult? repositoryResult;
    if (inputs.isNotEmpty) {
      try {
        repositoryResult = await widget.repository.importItems(
          InventoryImportRequest(
            performedByUserId: widget.user.id,
            rows: inputs,
            mode: InventoryImportMode.createOnly,
          ),
        );
      } catch (error) {
        failures.add(
          InventoryImportRowFailure(
            sourceRowNumber: 0,
            sku: '',
            reason: 'Bulk entry could not be committed: $error',
          ),
        );
      }
    }

    if (!mounted) return;
    final result = InventoryImportResult(
      requestedCount: _rows.where(_hasData).length,
      successCount: repositoryResult?.successCount ?? 0,
      failureCount: failures.length + (repositoryResult?.failureCount ?? 0),
      importedSummaries: repositoryResult?.importedSummaries ?? const [],
      failures: [...failures, ...?repositoryResult?.failures],
      createdCount: repositoryResult?.createdCount,
      updatedCount: repositoryResult?.updatedCount,
    );
    setState(() {
      _isSaving = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!InventoryItemAdministrationPolicy.canCreate(widget.user)) {
      return const AccessRestrictedScreen();
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Manual Inventory Entry'),
        actions: [
          IconButton(
            key: const Key('inventory_bulk_entry_add_row_button'),
            tooltip: 'Add row',
            onPressed: _isSaving ? null : _addRow,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter multiple item records in a spreadsheet-style grid. SKU and Product Name are required; stock is recorded through the movement ledger.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      key: const Key('inventory_bulk_entry_column_selector'),
                      onPressed: _isSaving ? null : _openColumnSelector,
                      icon: const Icon(Icons.view_column_outlined),
                      label: Text(
                        'Columns (${_columns.length}/${_allColumns.length})',
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_rows.length} rows',
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_fatalMessage != null)
            Container(
              key: const Key('inventory_bulk_entry_error'),
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              color: colorScheme.errorContainer,
              child: Text(
                _fatalMessage!,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          if (_result != null) _BulkResultBanner(result: _result!),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  key: const Key('inventory_bulk_entry_grid'),
                  columnSpacing: 12,
                  headingRowColor: WidgetStatePropertyAll(
                    colorScheme.surfaceContainerHighest,
                  ),
                  columns: [
                    const DataColumn(label: Text('#')),
                    ..._columns.map(
                      (column) => DataColumn(
                        label: SizedBox(
                          width: column.width,
                          child: Text(column.label),
                        ),
                      ),
                    ),
                    const DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (var index = 0; index < _rows.length; index++)
                      DataRow(
                        cells: [
                          DataCell(Text('${index + 1}')),
                          ..._columns.map((column) {
                            final controller =
                                _rows[index].controllers[column.keyName]!;
                            return DataCell(
                              SizedBox(
                                width: column.width,
                                child: TextField(
                                  key: Key(
                                    'inventory_bulk_entry_${index}_${column.keyName}',
                                  ),
                                  controller: controller,
                                  enabled: !_isSaving,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            );
                          }),
                          DataCell(
                            IconButton(
                              key: Key(
                                'inventory_bulk_entry_remove_row_$index',
                              ),
                              tooltip: 'Remove row',
                              onPressed: _isSaving
                                  ? null
                                  : () => _removeRow(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  key: const Key('inventory_bulk_entry_cancel_button'),
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: const Key('inventory_bulk_entry_save_button'),
                  onPressed: _isSaving ? null : _submit,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save Rows'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkResultBanner extends StatelessWidget {
  const _BulkResultBanner({required this.result});

  final InventoryImportResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('inventory_bulk_entry_result'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      color: result.failureCount == 0
          ? colorScheme.primaryContainer
          : colorScheme.errorContainer,
      child: Text(
        'Saved ${result.successCount} row(s); ${result.failureCount} row(s) need attention.'
        '${result.failures.isEmpty ? '' : ' First error: ${result.failures.first.reason}'}',
        style: TextStyle(
          color: result.failureCount == 0
              ? colorScheme.onPrimaryContainer
              : colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
