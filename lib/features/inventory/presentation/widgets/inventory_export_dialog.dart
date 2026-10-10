import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/repositories/mock_inventory_repository.dart';
import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_export_artifact.dart';
import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/entities/inventory_export_fields.dart';
import '../../domain/entities/inventory_field_metadata.dart';
import '../../domain/entities/inventory_query.dart';
import '../../domain/policies/inventory_export_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/inventory_export_cubit.dart';
import '../bloc/inventory_export_state.dart';
import '../services/inventory_export_data_loader.dart';
import '../services/inventory_export_file_delivery_service.dart';
import '../services/inventory_export_service.dart';
import '../services/inventory_pdf_serializer.dart';

/// Opens the inventory export modal dialog.
Future<bool?> showInventoryExportDialog({
  required BuildContext context,
  required CurrentUser user,
  required InventoryRepository repository,
  CurrentUser? Function()? currentUserProvider,
  InventoryExportCubit? cubit,
  InventoryExportFileDeliveryService? fileDeliveryService,
  InventoryQuery? currentQuery,
  Set<String>? selectedItemIds,
  InventoryExportPreset initialPreset = InventoryExportPreset.allDetails,
}) {
  CurrentUser? Function()? effectiveProvider = currentUserProvider;
  if (effectiveProvider == null) {
    try {
      final authCubit = context.read<AuthCubit?>();
      if (authCubit != null) {
        effectiveProvider = () {
          final s = authCubit.state;
          return s is AuthAuthenticated ? s.user : null;
        };
      }
    } catch (_) {}
  }
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => InventoryExportDialog(
      user: user,
      repository: repository,
      currentUserProvider: effectiveProvider,
      cubit: cubit,
      fileDeliveryService: fileDeliveryService,
      currentQuery: currentQuery,
      selectedItemIds: selectedItemIds,
      initialPreset: initialPreset,
    ),
  );
}

/// Reusable modal dialog for configuring, preparing, and delivering customizable inventory exports.
class InventoryExportDialog extends StatefulWidget {
  final CurrentUser user;
  final InventoryRepository repository;
  final CurrentUser? Function()? currentUserProvider;
  final InventoryExportCubit? cubit;
  final InventoryExportFileDeliveryService? fileDeliveryService;
  final InventoryQuery? currentQuery;
  final Set<String>? selectedItemIds;
  final InventoryExportPreset initialPreset;

  const InventoryExportDialog({
    super.key,
    required this.user,
    required this.repository,
    this.currentUserProvider,
    this.cubit,
    this.fileDeliveryService,
    this.currentQuery,
    this.selectedItemIds,
    this.initialPreset = InventoryExportPreset.allDetails,
  });

  @override
  State<InventoryExportDialog> createState() => _InventoryExportDialogState();
}

class _InventoryExportDialogState extends State<InventoryExportDialog> {
  late final InventoryExportCubit _cubit;
  late final InventoryExportFileDeliveryService _fileDeliveryService;
  late final bool _isExternalCubit;
  late final CurrentUser? Function() _currentUserProvider;

  String? _initiatingUserId;
  InventoryExportFormat? _selectedFormat;
  late InventoryExportPreset _selectedPreset;
  InventoryExportScope _selectedScope = InventoryExportScope.all;
  List<String> _selectedColumns = [];
  List<CustomFieldDefinition> _customDefinitions = [];
  PdfLayoutOrientation _selectedPdfOrientation = PdfLayoutOrientation.auto;

  Set<String> _selectedItemIds = {};
  List<InventoryItemSummary> _selectableItems = [];
  bool _loadingSelectableItems = false;
  String? _selectableItemsError;

  bool _isDelivering = false;
  String? _deliveryFeedback;
  bool _isDeliverySuccess = false;

  CurrentUser? _getSafeCurrentUser() {
    try {
      return _currentUserProvider();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.initialPreset;
    _currentUserProvider = widget.currentUserProvider ??
        () {
          try {
            final authCubit = context.read<AuthCubit?>();
            if (authCubit != null) {
              final authState = authCubit.state;
              if (authState is AuthAuthenticated) {
                return authState.user;
              }
            }
          } catch (_) {}
          return null;
        };
    _isExternalCubit = widget.cubit != null;
    if (_isExternalCubit) {
      _cubit = widget.cubit!;
    } else {
      final dataLoader = InventoryExportDataLoader(widget.repository);
      final exportService = InventoryExportService(dataLoader: dataLoader);
      _cubit = InventoryExportCubit(
        exportService: exportService,
        currentUser: widget.user,
        currentUserProvider: _getSafeCurrentUser,
      );
    }

    _fileDeliveryService = widget.fileDeliveryService ??
        InventoryExportFileDeliveryService();

    final activeUser = _getSafeCurrentUser();
    final canCsv = activeUser != null && InventoryExportPolicy.canExportCsv(activeUser);
    final canXlsx = activeUser != null && InventoryExportPolicy.canExportXlsx(activeUser);
    final canPdf = activeUser != null && InventoryExportPolicy.canExportPdf(activeUser);

    if (canCsv) {
      _selectedFormat = InventoryExportFormat.csv;
    } else if (canXlsx) {
      _selectedFormat = InventoryExportFormat.xlsx;
    } else if (canPdf) {
      _selectedFormat = InventoryExportFormat.pdf;
    }

    // Initialize selected items and selectable items
    if (widget.selectedItemIds != null && widget.selectedItemIds!.isNotEmpty) {
      _selectedItemIds = Set<String>.from(widget.selectedItemIds!);
      _selectedScope = InventoryExportScope.selected;
      _loadSelectableItems();
    }

    // Initialize custom columns with permitted standard fields
    _initPermittedColumns(activeUser);

    // Load registered custom field definitions from repository
    final repo = widget.repository;
    if (repo is MockInventoryRepository) {
      repo.getCustomFieldDefinitions().then((defs) {
        if (mounted) {
          setState(() {
            _customDefinitions = defs;
            for (final def in defs) {
              if (!_selectedColumns.contains(def.key)) {
                _selectedColumns.add(def.key);
              }
            }
          });
        }
      });
    }
  }

  void _initPermittedColumns(CurrentUser? user) {
    _selectedColumns = InventoryFieldMetadata.allStandardFields
        .where((f) => f.canView(user))
        .map((f) => f.key)
        .toList();
    for (final def in _customDefinitions) {
      if (!_selectedColumns.contains(def.key)) {
        _selectedColumns.add(def.key);
      }
    }
  }

  List<String> _getAllPermittedColumns(CurrentUser? user) {
    final list = <String>[];
    for (final field in InventoryFieldMetadata.allStandardFields) {
      if (field.canView(user)) {
        list.add(field.key);
      }
    }
    for (final def in _customDefinitions) {
      if (!list.contains(def.key)) {
        list.add(def.key);
      }
    }
    for (final col in _selectedColumns) {
      if (!list.contains(col)) {
        list.add(col);
      }
    }
    return list;
  }

  @override
  void dispose() {
    if (!_isExternalCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  Future<void> _loadSelectableItems() async {
    if (_loadingSelectableItems) return;
    setState(() {
      _loadingSelectableItems = true;
      _selectableItemsError = null;
    });
    try {
      final items = await InventoryExportDataLoader(widget.repository)
          .loadAllItems();
      if (mounted) {
        setState(() {
          _selectableItems = items;
          _loadingSelectableItems = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingSelectableItems = false;
          _selectableItemsError = 'Could not load all inventory rows: $error';
        });
      }
    }
  }

  void _invalidatePreparedState() {
    if (_cubit.state is InventoryExportPrepared) {
      _cubit.reset();
    }
    _deliveryFeedback = null;
    _isDeliverySuccess = false;
  }

  void _startPreparation(InventoryExportFormat format) {
    final activeUser = _getSafeCurrentUser();
    if (activeUser == null) {
      setState(() {
        _deliveryFeedback = 'User session expired or unauthenticated.';
        _isDeliverySuccess = false;
      });
      return;
    }

    _initiatingUserId = activeUser.id;
    setState(() {
      _deliveryFeedback = null;
      _isDeliverySuccess = false;
    });

    final effectiveColumns = switch (_selectedPreset) {
      InventoryExportPreset.allDetails => _getAllPermittedColumns(activeUser),
      InventoryExportPreset.custom => _selectedColumns,
      InventoryExportPreset.legacyThreeColumn => InventoryExportFields.legacyHeaders,
    };

    _cubit.export(
      format,
      scope: _selectedScope,
      preset: _selectedPreset,
      columns: effectiveColumns,
      query: widget.currentQuery,
      selectedItemIds: _selectedItemIds,
      customFieldDefinitions: _customDefinitions,
      orientation: _selectedPdfOrientation,
    );
  }

  Future<void> _handleDelivery(InventoryExportArtifact artifact) async {
    setState(() {
      _isDelivering = true;
      _deliveryFeedback = null;
    });

    final result = await _fileDeliveryService.deliverArtifact(
      artifact: artifact,
      currentUserProvider: _getSafeCurrentUser,
      boundUserId: _initiatingUserId,
    );

    if (!mounted) return;

    setState(() {
      _isDelivering = false;
      if (result.isSaved) {
        _isDeliverySuccess = true;
        _deliveryFeedback = 'Inventory exported successfully.';
      } else if (result.isDownloadInitiated) {
        _isDeliverySuccess = true;
        _deliveryFeedback = 'Inventory download started.';
      } else if (result.isCancelled) {
        _isDeliverySuccess = false;
        _deliveryFeedback = 'File save was cancelled.';
      } else if (result.isRestricted) {
        _isDeliverySuccess = false;
        _deliveryFeedback = result.message ??
            "You don't have permission to export inventory in this format.";
      } else {
        _isDeliverySuccess = false;
        _deliveryFeedback = result.message ??
            'Unable to export inventory. Please try again.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<InventoryExportCubit, InventoryExportState>(
        listener: (context, state) {},
        builder: (context, state) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          final activeUser = _getSafeCurrentUser();
          final canCsv = activeUser != null && InventoryExportPolicy.canExportCsv(activeUser);
          final canXlsx = activeUser != null && InventoryExportPolicy.canExportXlsx(activeUser);
          final canPdf = activeUser != null && InventoryExportPolicy.canExportPdf(activeUser);

          final isBusy = state is InventoryExportPreparing || _isDelivering;
          final canSelected = activeUser != null && switch (_selectedFormat) {
            InventoryExportFormat.csv => canCsv,
            InventoryExportFormat.xlsx => canXlsx,
            InventoryExportFormat.pdf => canPdf,
            null => false,
          };

          final isPdf = _selectedFormat == InventoryExportFormat.pdf;
          final isCustomPreset = _selectedPreset == InventoryExportPreset.custom;

          final hasSelectedItems = _selectedItemIds.isNotEmpty;
          final selectedScopeValid = _selectedScope != InventoryExportScope.selected ||
              (hasSelectedItems && !_loadingSelectableItems &&
                  _selectableItemsError == null);
          final columnsValid = isPdf || !isCustomPreset || _selectedColumns.isNotEmpty;

          final canSubmit = !isBusy && _selectedFormat != null && canSelected && selectedScopeValid && columnsValid;

          final permittedStandardFields = InventoryFieldMetadata.allStandardFields
              .where((f) => f.canView(activeUser))
              .toList();

          return PopScope(
            canPop: !isBusy,
            child: AlertDialog(
              key: const Key('inventory_export_dialog'),
              title: Row(
                children: [
                  Icon(
                    Icons.download_outlined,
                    size: 22,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Export Inventory',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480, maxHeight: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Configure export format, column selection, and record scope.',
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
                      const SizedBox(height: 4),
                      RadioGroup<InventoryExportFormat>(
                        groupValue: _selectedFormat,
                        onChanged: (f) {
                          if (!isBusy && f != null) {
                            final allowed = switch (f) {
                              InventoryExportFormat.csv => canCsv,
                              InventoryExportFormat.xlsx => canXlsx,
                              InventoryExportFormat.pdf => canPdf,
                            };
                            if (allowed) {
                              setState(() {
                                _selectedFormat = f;
                                _invalidatePreparedState();
                              });
                            }
                          }
                        },
                        child: Column(
                          children: [
                            RadioListTile<InventoryExportFormat>(
                              key: const Key('inventory_export_format_csv'),
                              value: InventoryExportFormat.csv,
                              enabled: !isBusy && canCsv,
                              title: const Text('CSV (.csv)'),
                              subtitle: const Text('Spreadsheet-compatible text file.'),
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<InventoryExportFormat>(
                              key: const Key('inventory_export_format_pdf'),
                              value: InventoryExportFormat.pdf,
                              enabled: !isBusy && canPdf,
                              title: const Text('PDF (.pdf)'),
                              subtitle: const Text('Printable report with selected columns.'),
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<InventoryExportFormat>(
                              key: const Key('inventory_export_format_xlsx'),
                              value: InventoryExportFormat.xlsx,
                              enabled: !isBusy && canXlsx,
                              title: const Text('Excel (.xlsx)'),
                              subtitle: const Text('Excel workbook with numeric stock quantities.'),
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),

                      // Non-PDF options: Record Scope and Presets
                      if (_selectedFormat != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Record Scope',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        RadioGroup<InventoryExportScope>(
                          groupValue: _selectedScope,
                          onChanged: (s) {
                            if (!isBusy && s != null) {
                              setState(() {
                                _selectedScope = s;
                                _invalidatePreparedState();
                              });
                              if (s == InventoryExportScope.selected && _selectableItems.isEmpty) {
                                _loadSelectableItems();
                              }
                            }
                          },
                          child: Column(
                            children: [
                              RadioListTile<InventoryExportScope>(
                                key: const Key('inventory_export_scope_all'),
                                value: InventoryExportScope.all,
                                enabled: !isBusy,
                                title: const Text('All Records'),
                                subtitle: const Text('Export all active authorized inventory items.'),
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                              ),
                              RadioListTile<InventoryExportScope>(
                                key: const Key('inventory_export_scope_filtered'),
                                value: InventoryExportScope.filtered,
                                enabled: !isBusy,
                                title: const Text('Filtered Results'),
                                subtitle: Text(
                                  widget.currentQuery?.searchText != null &&
                                          widget.currentQuery!.searchText!.trim().isNotEmpty
                                      ? 'Filter: "${widget.currentQuery!.searchText!.trim()}"'
                                      : 'All matching active items.',
                                ),
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                              ),
                              RadioListTile<InventoryExportScope>(
                                key: const Key('inventory_export_scope_selected'),
                                value: InventoryExportScope.selected,
                                enabled: !isBusy,
                                title: Text(
                                  'Selected Records (${_selectedItemIds.length} items)',
                                ),
                                subtitle: const Text('Export only currently selected items.'),
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                        if (_selectedScope == InventoryExportScope.selected) ...[
                          const SizedBox(height: 8),
                          if (_loadingSelectableItems)
                            const LinearProgressIndicator(),
                          if (_selectableItemsError != null)
                            Text(_selectableItemsError!,
                                style: TextStyle(color: colorScheme.error)),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Selected: ${_selectedItemIds.length} / ${_selectableItems.length} rows',
                                key: const Key('inventory_export_rows_counter'),
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              TextButton(
                                key: const Key('inventory_export_select_all_rows'),
                                onPressed: isBusy
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedItemIds = _selectableItems.map((e) => e.item.id).toSet();
                                          _invalidatePreparedState();
                                        });
                                      },
                                child: const Text('Select All Rows'),
                              ),
                              TextButton(
                                key: const Key('inventory_export_deselect_all_rows'),
                                onPressed: isBusy
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedItemIds.clear();
                                          _invalidatePreparedState();
                                        });
                                      },
                                child: const Text('Deselect All Rows'),
                              ),
                            ],
                          ),
                          if (_selectableItems.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final summary in _selectableItems)
                                    CheckboxListTile(
                                      key: Key('inventory_export_row_${summary.item.id}'),
                                      value: _selectedItemIds.contains(summary.item.id),
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      title: Text(summary.item.name, overflow: TextOverflow.ellipsis),
                                      subtitle: Text('SKU: ${summary.item.sku} | Stock: ${summary.quantityOnHand.toInt()}'),
                                      onChanged: isBusy
                                          ? null
                                          : (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedItemIds.add(summary.item.id);
                                                } else {
                                                  _selectedItemIds.remove(summary.item.id);
                                                }
                                                _invalidatePreparedState();
                                              });
                                            },
                                    ),
                                ],
                              ),
                            ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Columns & Presets',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        RadioGroup<InventoryExportPreset>(
                          groupValue: _selectedPreset,
                          onChanged: (p) {
                            if (!isBusy && p != null) {
                              setState(() {
                                _selectedPreset = p;
                                _invalidatePreparedState();
                              });
                            }
                          },
                          child: Column(
                            children: [
                              RadioListTile<InventoryExportPreset>(
                                key: const Key('inventory_export_preset_all'),
                                value: InventoryExportPreset.allDetails,
                                enabled: !isBusy,
                                title: const Text('All Details (Complete Inventory)'),
                                subtitle: const Text(
                                  'Includes all product fields and saved custom attributes.',
                                ),
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                              ),
                              RadioListTile<InventoryExportPreset>(
                                key: const Key('inventory_export_preset_custom'),
                                value: InventoryExportPreset.custom,
                                enabled: !isBusy,
                                title: const Text('Custom Columns'),
                                subtitle: Text(
                                  '${_selectedColumns.length} columns selected.',
                                ),
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                              ),
                              RadioListTile<InventoryExportPreset>(
                                key: const Key('inventory_export_preset_legacy'),
                                value: InventoryExportPreset.legacyThreeColumn,
                                enabled: !isBusy,
                                title: const Text('Legacy Three-Column Preset'),
                                subtitle: Text(
                                  isPdf
                                      ? 'Printable report with frozen three columns (Item Name, SKU, Current Quantity).'
                                      : 'Item Name, SKU, Current Quantity only',
                                ),
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),

                        // Custom Column Configuration
                        if (isCustomPreset) ...[
                          if (isPdf) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<PdfLayoutOrientation>(
                              key: const Key('inventory_export_pdf_orientation'),
                              initialValue: _selectedPdfOrientation,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Page Layout / Orientation',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: PdfLayoutOrientation.auto,
                                  child: Text('Auto (Recommended)'),
                                ),
                                DropdownMenuItem(
                                  value: PdfLayoutOrientation.portrait,
                                  child: Text('Portrait'),
                                ),
                                DropdownMenuItem(
                                  value: PdfLayoutOrientation.landscape,
                                  child: Text('Landscape'),
                                ),
                              ],
                              onChanged: isBusy
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedPdfOrientation = val;
                                          _invalidatePreparedState();
                                        });
                                      }
                                    },
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Selected: ${_selectedColumns.length} columns',
                                key: const Key('inventory_export_columns_counter'),
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              TextButton(
                                key: const Key('inventory_export_select_all_columns'),
                                onPressed: isBusy
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedColumns = [
                                            ...permittedStandardFields.map((f) => f.key),
                                            ..._customDefinitions.map((d) => d.key),
                                          ];
                                          _invalidatePreparedState();
                                        });
                                      },
                                child: const Text('Select All Permitted'),
                              ),
                              TextButton(
                                key: const Key('inventory_export_deselect_all_columns'),
                                onPressed: isBusy
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedColumns.clear();
                                          _invalidatePreparedState();
                                        });
                                      },
                                child: const Text('Deselect All'),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...permittedStandardFields.map((field) {
                                  final isChecked = _selectedColumns.contains(field.key);
                                  return CheckboxListTile(
                                    key: Key('inventory_export_col_${field.key}'),
                                    value: isChecked,
                                    title: Text(field.label),
                                    subtitle: Text(field.dataTypeDescription),
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: isBusy
                                        ? null
                                        : (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedColumns.add(field.key);
                                              } else {
                                                _selectedColumns.remove(field.key);
                                              }
                                              _invalidatePreparedState();
                                            });
                                          },
                                  );
                                }),
                                ..._customDefinitions.map((def) {
                                  final isChecked = _selectedColumns.contains(def.key);
                                  return CheckboxListTile(
                                    key: Key('inventory_export_col_${def.key}'),
                                    value: isChecked,
                                    title: Text('${def.label} (Custom)'),
                                    subtitle: Text(def.dataType.name),
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: isBusy
                                        ? null
                                        : (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedColumns.add(def.key);
                                              } else {
                                                _selectedColumns.remove(def.key);
                                              }
                                              _invalidatePreparedState();
                                            });
                                          },
                                  );
                                }),
                              ],
                            ),
                          ),

                          // Column Order Management
                          if (_selectedColumns.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Column Order (${_selectedColumns.length})',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (int index = 0; index < _selectedColumns.length; index++) ...[
                                    Builder(
                                      builder: (context) {
                                        final colKey = _selectedColumns[index];
                                        final label = InventoryExportFields.getHeaderLabel(
                                          colKey,
                                          customFieldDefinitions: _customDefinitions,
                                        );
                                        return ListTile(
                                          key: Key('inventory_export_order_$colKey'),
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          title: Text('${index + 1}. $label'),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                key: Key('inventory_export_move_up_$colKey'),
                                                icon: const Icon(Icons.arrow_upward, size: 16),
                                                onPressed: isBusy || index == 0
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          final item = _selectedColumns.removeAt(index);
                                                          _selectedColumns.insert(index - 1, item);
                                                          _invalidatePreparedState();
                                                        });
                                                      },
                                              ),
                                              IconButton(
                                                key: Key('inventory_export_move_down_$colKey'),
                                                icon: const Icon(Icons.arrow_downward, size: 16),
                                                onPressed: isBusy || index == _selectedColumns.length - 1
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          final item = _selectedColumns.removeAt(index);
                                                          _selectedColumns.insert(index + 1, item);
                                                          _invalidatePreparedState();
                                                        });
                                                      },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],

                      if (activeUser == null && state is! InventoryExportPrepared && _deliveryFeedback == null) ...[
                        const SizedBox(height: 12),
                        _buildFeedbackBox(
                          context,
                          key: const Key('inventory_export_dialog_unauthenticated_notice'),
                          icon: Icons.lock_outline,
                          message: 'User session expired or unauthenticated.',
                          isError: true,
                        ),
                      ],

                      if (state is InventoryExportPreparing || _isDelivering) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                key: Key('inventory_export_loading_indicator'),
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isDelivering
                                    ? 'Saving export file...'
                                    : 'Preparing inventory export...',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (state is InventoryExportPrepared) ...[
                        const SizedBox(height: 12),
                        _buildFeedbackBox(
                          context,
                          key: const Key('inventory_export_dialog_prepared_feedback'),
                          icon: Icons.check_circle_outline,
                          message: 'Inventory export ready (${switch (state.artifact.format) {
                            InventoryExportFormat.csv => "CSV",
                            InventoryExportFormat.xlsx => "Excel",
                            InventoryExportFormat.pdf => "PDF",
                          }}).',
                          isError: false,
                        ),
                      ],

                      if (state is InventoryExportRestricted) ...[
                        const SizedBox(height: 12),
                        _buildFeedbackBox(
                          context,
                          key: const Key('inventory_export_dialog_restricted'),
                          icon: Icons.lock_outline,
                          message: state.message,
                          isError: true,
                        ),
                      ],

                      if (state is InventoryExportFailure) ...[
                        const SizedBox(height: 12),
                        _buildFeedbackBox(
                          context,
                          key: const Key('inventory_export_dialog_failure'),
                          icon: Icons.error_outline,
                          message: state.message,
                          isError: true,
                        ),
                      ],

                      if (_deliveryFeedback != null) ...[
                        const SizedBox(height: 12),
                        _buildFeedbackBox(
                          context,
                          key: const Key('inventory_export_dialog_delivery_feedback'),
                          icon: _isDeliverySuccess ? Icons.check_circle_outline : Icons.info_outline,
                          message: _deliveryFeedback!,
                          isError: !_isDeliverySuccess,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  key: const Key('inventory_export_dialog_cancel_button'),
                  onPressed: isBusy ? null : () => Navigator.of(context).pop(_isDeliverySuccess),
                  child: Text(_isDeliverySuccess ? 'Close' : 'Cancel'),
                ),
                if (state is InventoryExportPrepared)
                  FilledButton(
                    key: const Key('inventory_export_dialog_download_button'),
                    onPressed: isBusy ? null : () => _handleDelivery(state.artifact),
                    child: isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            switch (state.artifact.format) {
                              InventoryExportFormat.csv => 'Download CSV',
                              InventoryExportFormat.xlsx => 'Download Excel',
                              InventoryExportFormat.pdf => 'Download PDF',
                            },
                          ),
                  )
                else
                  FilledButton(
                    key: const Key('inventory_export_dialog_submit_button'),
                    onPressed: canSubmit ? () => _startPreparation(_selectedFormat!) : null,
                    child: isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Export'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedbackBox(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String message,
    required bool isError,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = isError ? colorScheme.errorContainer : colorScheme.primaryContainer;
    final fgColor = isError ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer;

    return Container(
      key: key,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fgColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: fgColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
