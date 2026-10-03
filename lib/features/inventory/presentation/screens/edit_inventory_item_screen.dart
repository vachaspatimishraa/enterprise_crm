import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_catalogs.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/policies/inventory_field_access_policy.dart';
import '../../domain/policies/inventory_item_administration_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/edit_inventory_item_cubit.dart';
import '../bloc/edit_inventory_item_state.dart';
import '../widgets/inventory_form_sections.dart';

/// Screen allowing authorized users to edit an existing Inventory item's fields.
class EditInventoryItemScreen extends StatelessWidget {
  final CurrentUser user;
  final CurrentUser Function()? currentUserProvider;
  final InventoryRepository repository;
  final String itemId;

  const EditInventoryItemScreen({
    super.key,
    required this.user,
    this.currentUserProvider,
    required this.repository,
    required this.itemId,
  });

  CurrentUser? _resolveUser(BuildContext context) {
    if (currentUserProvider != null) {
      try {
        return currentUserProvider!();
      } catch (_) {
        return null;
      }
    }
    try {
      final authCubit = context.read<AuthCubit?>();
      if (authCubit != null) {
        final authState = authCubit.state;
        if (authState is AuthAuthenticated) {
          return authState.user;
        }
        return null;
      }
    } catch (_) {}
    return user;
  }

  @override
  Widget build(BuildContext context) {
    try {
      context.watch<AuthCubit?>();
    } catch (_) {}

    final liveUser = _resolveUser(context);
    if (liveUser == null || !InventoryItemAdministrationPolicy.canEdit(liveUser)) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider<EditInventoryItemCubit>(
      create: (_) => EditInventoryItemCubit(repository)..load(itemId),
      child: _EditInventoryItemView(
        itemId: itemId,
        user: liveUser,
        repository: repository,
        currentUserResolver: () => _resolveUser(context),
      ),
    );
  }
}

class _EditInventoryItemView extends StatefulWidget {
  final String itemId;
  final CurrentUser user;
  final InventoryRepository repository;
  final CurrentUser? Function() currentUserResolver;

  const _EditInventoryItemView({
    required this.itemId,
    required this.user,
    required this.repository,
    required this.currentUserResolver,
  });

  @override
  State<_EditInventoryItemView> createState() => _EditInventoryItemViewState();
}

class _EditInventoryItemViewState extends State<_EditInventoryItemView> {
  final _formKey = GlobalKey<FormState>();

  // Product Identification
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _brandController = TextEditingController();
  final _barcodeController = TextEditingController();
  String _category = 'General';
  String _unit = 'piece';

  // Warehouse & Stock
  final _binLocationController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  final _maxStockController = TextEditingController();
  String _warehouse = 'Default';

  // Pricing & Commercial
  final _supplierController = TextEditingController();
  final _unitCostController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _gstPercentController = TextEditingController();

  // Tracking & Lifecycle
  final _batchNumberController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _expiryDate;
  DateTime? _lastRestockedDate;
  bool _isActive = true;

  // Custom Fields
  final Map<String, dynamic> _customValues = {};
  List<CustomFieldDefinition> _customDefinitions = [];
  InventoryCatalogs _catalogs = InventoryCatalogs();

  InventoryItem? _originalItem;
  InventoryItemSummary? _currentSummary;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _binLocationController.dispose();
    _reorderLevelController.dispose();
    _maxStockController.dispose();
    _supplierController.dispose();
    _unitCostController.dispose();
    _sellingPriceController.dispose();
    _gstPercentController.dispose();
    _batchNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _populateForm(
    InventoryItemSummary summary,
    List<CustomFieldDefinition> defs,
    InventoryCatalogs catalogs,
  ) {
    if (!_initialized) {
      _currentSummary = summary;
      final item = summary.item;
      _originalItem = item;
      _catalogs = catalogs;
      _customDefinitions = List.of(defs);

      _nameController.text = item.name;
      _skuController.text = item.sku;
      _category = item.category;
      _brandController.text = item.brand ?? '';
      _unit = item.unit;
      _barcodeController.text = item.barcode ?? '';
      _warehouse = item.warehouse;
      _binLocationController.text = item.binLocation ?? '';
      _reorderLevelController.text = item.reorderLevel?.toString() ?? '';
      _maxStockController.text = item.maxStock?.toString() ?? '';
      _supplierController.text = item.supplier ?? '';
      _unitCostController.text =
          item.unitCostInr != null ? item.unitCostInr!.toStringAsFixed(2) : '';
      _sellingPriceController.text = item.sellingPriceInr != null
          ? item.sellingPriceInr!.toStringAsFixed(2)
          : '';
      _gstPercentController.text =
          item.gstPercent != null ? item.gstPercent!.toString() : '';
      _batchNumberController.text = item.batchNumber ?? '';
      _expiryDate = item.expiryDate;
      _lastRestockedDate = item.lastRestockedDate;
      _isActive = item.isActive;
      _notesController.text = item.notes ?? '';

      _customValues.clear();
      _customValues.addAll(item.customFields);

      _initialized = true;
    }
  }

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime? initialDate,
    required ValueChanged<DateTime?> onDateSelected,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  Future<void> _openAddCustomFieldDialog(BuildContext context) async {
    final liveUser = widget.currentUserResolver() ?? widget.user;
    final messenger = ScaffoldMessenger.of(context);
    final created = await showDialog<CustomFieldDefinition>(
      context: context,
      builder: (_) => AddCustomFieldDialog(
        repository: widget.repository,
        user: liveUser,
      ),
    );

    if (created != null && mounted) {
      setState(() {
        _customDefinitions = List<CustomFieldDefinition>.from(_customDefinitions)..add(created);
        if (created.defaultValue != null) {
          _customValues[created.key] = created.defaultValue;
        }
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Custom field "${created.label}" added.')),
      );
    }
  }

  void _submit() {
    final liveUser = widget.currentUserResolver();
    if (liveUser == null || !InventoryItemAdministrationPolicy.canEdit(liveUser)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired or unauthorized to edit items.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final original = _originalItem;
    if (original == null) {
      return;
    }

    final canViewCost = InventoryFieldAccessPolicy.canViewCost(liveUser);
    final canViewSupplier = InventoryFieldAccessPolicy.canViewSupplier(liveUser);

    // Numeric validations
    final reorderLevel = _reorderLevelController.text.trim().isNotEmpty
        ? double.tryParse(_reorderLevelController.text.trim())
        : null;
    final maxStock = _maxStockController.text.trim().isNotEmpty
        ? double.tryParse(_maxStockController.text.trim())
        : null;

    if (reorderLevel != null && maxStock != null && maxStock < reorderLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Max stock ($maxStock) cannot be lower than reorder level ($reorderLevel).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final unitCost = _unitCostController.text.trim().isNotEmpty
        ? double.tryParse(_unitCostController.text.trim())
        : null;
    final sellingPrice = _sellingPriceController.text.trim().isNotEmpty
        ? double.tryParse(_sellingPriceController.text.trim())
        : null;
    final gstPercent = _gstPercentController.text.trim().isNotEmpty
        ? double.tryParse(_gstPercentController.text.trim())
        : null;

    // Validate required custom fields
    for (final def in _customDefinitions) {
      if (def.isRequired) {
        final val = _customValues[def.key];
        if (val == null || (val is String && val.trim().isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Custom field "${def.label}" is required.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    // Determine clearing flags for nullable fields
    final clearBrand = original.brand != null && _brandController.text.trim().isEmpty;
    final clearBarcode = original.barcode != null && _barcodeController.text.trim().isEmpty;
    final clearBinLocation = original.binLocation != null && _binLocationController.text.trim().isEmpty;
    final clearSupplier = canViewSupplier && original.supplier != null && _supplierController.text.trim().isEmpty;
    final clearUnitCostInr = canViewCost && original.unitCostInr != null && _unitCostController.text.trim().isEmpty;
    final clearSellingPriceInr = original.sellingPriceInr != null && _sellingPriceController.text.trim().isEmpty;
    final clearReorderLevel = original.reorderLevel != null && _reorderLevelController.text.trim().isEmpty;
    final clearMaxStock = original.maxStock != null && _maxStockController.text.trim().isEmpty;
    final clearGstPercent = original.gstPercent != null && _gstPercentController.text.trim().isEmpty;
    final clearBatchNumber = original.batchNumber != null && _batchNumberController.text.trim().isEmpty;
    final clearExpiryDate = original.expiryDate != null && _expiryDate == null;
    final clearLastRestockedDate = original.lastRestockedDate != null && _lastRestockedDate == null;
    final clearNotes = original.notes != null && _notesController.text.trim().isEmpty;

    final customFieldsToSubmit = Map<String, dynamic>.from(_customValues);
    for (final key in original.customFields.keys) {
      if (!customFieldsToSubmit.containsKey(key) ||
          customFieldsToSubmit[key] == null ||
          (customFieldsToSubmit[key] is String && (customFieldsToSubmit[key] as String).trim().isEmpty)) {
        customFieldsToSubmit[key] = null;
      }
    }

    context.read<EditInventoryItemCubit>().submit(
      name: _nameController.text,
      sku: _skuController.text,
      category: _category,
      brand: _brandController.text.trim().isNotEmpty ? _brandController.text.trim() : null,
      unit: _unit,
      barcode: _barcodeController.text.trim().isNotEmpty ? _barcodeController.text.trim() : null,
      warehouse: _warehouse,
      binLocation: _binLocationController.text.trim().isNotEmpty ? _binLocationController.text.trim() : null,
      supplier: canViewSupplier
          ? (_supplierController.text.trim().isNotEmpty ? _supplierController.text.trim() : null)
          : null,
      unitCostInr: canViewCost ? unitCost : null,
      sellingPriceInr: sellingPrice,
      reorderLevel: reorderLevel,
      maxStock: maxStock,
      gstPercent: gstPercent,
      batchNumber: _batchNumberController.text.trim().isNotEmpty ? _batchNumberController.text.trim() : null,
      expiryDate: _expiryDate,
      lastRestockedDate: _lastRestockedDate,
      isActive: _isActive,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      customFields: customFieldsToSubmit,
      clearBrand: clearBrand,
      clearBarcode: clearBarcode,
      clearBinLocation: clearBinLocation,
      clearSupplier: clearSupplier,
      clearUnitCostInr: clearUnitCostInr,
      clearSellingPriceInr: clearSellingPriceInr,
      clearReorderLevel: clearReorderLevel,
      clearMaxStock: clearMaxStock,
      clearGstPercent: clearGstPercent,
      clearBatchNumber: clearBatchNumber,
      clearExpiryDate: clearExpiryDate,
      clearLastRestockedDate: clearLastRestockedDate,
      clearNotes: clearNotes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final liveUser = widget.currentUserResolver() ?? widget.user;

    final canViewCost = InventoryFieldAccessPolicy.canViewCost(liveUser);
    final canViewSupplier = InventoryFieldAccessPolicy.canViewSupplier(liveUser);
    final canManageCustomFields = liveUser.isAdmin ||
        liveUser.permissions.contains('inventory.custom_fields.manage');

    return BlocConsumer<EditInventoryItemCubit, EditInventoryItemState>(
      listener: (context, state) {
        if (state is EditInventoryItemSuccess) {
          Navigator.of(context).pop(true);
        } else if (state is EditInventoryItemFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: colorScheme.error,
            ),
          );
        } else if (state is EditInventoryItemLoaded) {
          _populateForm(state.item, state.customFieldDefinitions, state.catalogs);
        }
      },
      builder: (context, state) {
        final isSubmitting = state is EditInventoryItemSubmitting;

        if (state is EditInventoryItemLoading || state is EditInventoryItemInitial) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Edit Inventory Item'),
              leading: IconButton(
                key: const Key('edit_inventory_item_cancel'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: const Center(
              child: CircularProgressIndicator(
                key: Key('edit_inventory_loading_indicator'),
              ),
            ),
          );
        }

        if (state is EditInventoryItemNotFound) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Edit Inventory Item'),
              leading: IconButton(
                key: const Key('edit_inventory_item_cancel'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      'Inventory item not found',
                      key: const Key('edit_inventory_not_found'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The item with ID "${widget.itemId}" does not exist in inventory.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('edit_inventory_not_found_back_button'),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Inventory'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state is EditInventoryItemLoaded) {
          _populateForm(state.item, state.customFieldDefinitions, state.catalogs);
        } else if (state is EditInventoryItemFailure && state.item != null) {
          _populateForm(state.item!, _customDefinitions, _catalogs);
        }

        final summary = _currentSummary;

        return Scaffold(
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: SafeArea(
              child: isDesktop
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          key: const Key('edit_inventory_item_cancel_button'),
                          onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          key: const Key('edit_inventory_item_save'),
                          onPressed: isSubmitting ? null : _submit,
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text(isSubmitting ? 'Saving...' : 'Save Changes'),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('edit_inventory_item_cancel_button'),
                            onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('edit_inventory_item_save'),
                            onPressed: isSubmitting ? null : _submit,
                            icon: isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save_outlined, size: 18),
                            label: Text(
                              isSubmitting ? 'Saving...' : 'Save Changes',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          appBar: AppBar(
            title: const Text('Edit Inventory Item'),
            leading: IconButton(
              key: const Key('edit_inventory_item_cancel'),
              icon: const Icon(Icons.arrow_back),
              onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 400 ? 12.0 : 24.0,
                vertical: 20.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section A: Product Information
                      InventorySectionCard(
                        title: 'Product Information',
                        subtitle: 'Edit Item Identity',
                        icon: Icons.inventory_2_outlined,
                        children: [
                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    key: const Key('edit_inventory_item_name'),
                                    controller: _nameController,
                                    enabled: !isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Product Name *',
                                      hintText: 'e.g. Wireless Mouse',
                                      prefixIcon: Icon(Icons.label_outline),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Item name is required.';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    key: const Key('edit_inventory_item_sku'),
                                    controller: _skuController,
                                    enabled: !isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'SKU *',
                                      hintText: 'e.g. 00492-WM',
                                      prefixIcon: Icon(Icons.qr_code_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'SKU is required.';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            TextFormField(
                              key: const Key('edit_inventory_item_name'),
                              controller: _nameController,
                              enabled: !isSubmitting,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Product Name *',
                                hintText: 'e.g. Wireless Mouse',
                                prefixIcon: Icon(Icons.label_outline),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Item name is required.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('edit_inventory_item_sku'),
                              controller: _skuController,
                              enabled: !isSubmitting,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'SKU *',
                                hintText: 'e.g. 00492-WM',
                                prefixIcon: Icon(Icons.qr_code_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'SKU is required.';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 14),
                          if (isDesktop)
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    key: const Key('inventory_form_category'),
                                    initialValue: _catalogs.isValidCategory(_category)
                                        ? _category
                                        : (_catalogs.categories.isNotEmpty ? _catalogs.categories.first : null),
                                    decoration: const InputDecoration(
                                      labelText: 'Category *',
                                      prefixIcon: Icon(Icons.category_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _catalogs.categories.map((cat) {
                                      return DropdownMenuItem(value: cat, child: Text(cat, overflow: TextOverflow.ellipsis));
                                    }).toList(),
                                    onChanged: isSubmitting ? null : (val) {
                                      if (val != null) setState(() => _category = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    key: const Key('inventory_form_brand'),
                                    controller: _brandController,
                                    enabled: !isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Brand (optional)',
                                      hintText: 'e.g. Logitech',
                                      prefixIcon: Icon(Icons.branding_watermark_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            DropdownButtonFormField<String>(
                                    isExpanded: true,
                              key: const Key('inventory_form_category'),
                              initialValue: _catalogs.isValidCategory(_category)
                                  ? _category
                                  : (_catalogs.categories.isNotEmpty ? _catalogs.categories.first : null),
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                prefixIcon: Icon(Icons.category_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: _catalogs.categories.map((cat) {
                                return DropdownMenuItem(value: cat, child: Text(cat, overflow: TextOverflow.ellipsis));
                              }).toList(),
                              onChanged: isSubmitting ? null : (val) {
                                if (val != null) setState(() => _category = val);
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('inventory_form_brand'),
                              controller: _brandController,
                              enabled: !isSubmitting,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Brand (optional)',
                                hintText: 'e.g. Logitech',
                                prefixIcon: Icon(Icons.branding_watermark_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          if (isDesktop)
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    key: const Key('inventory_form_unit'),
                                    initialValue: _catalogs.isValidUnit(_unit)
                                        ? _unit
                                        : (_catalogs.units.isNotEmpty ? _catalogs.units.first : null),
                                    decoration: const InputDecoration(
                                      labelText: 'Unit of Measure *',
                                      prefixIcon: Icon(Icons.straighten_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _catalogs.units.map((u) {
                                      return DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis));
                                    }).toList(),
                                    onChanged: isSubmitting ? null : (val) {
                                      if (val != null) setState(() => _unit = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    key: const Key('inventory_form_barcode'),
                                    controller: _barcodeController,
                                    enabled: !isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Barcode (optional)',
                                      hintText: 'e.g. 8901234567890',
                                      prefixIcon: Icon(Icons.barcode_reader),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            DropdownButtonFormField<String>(
                                    isExpanded: true,
                              key: const Key('inventory_form_unit'),
                              initialValue: _catalogs.isValidUnit(_unit)
                                  ? _unit
                                  : (_catalogs.units.isNotEmpty ? _catalogs.units.first : null),
                              decoration: const InputDecoration(
                                labelText: 'Unit of Measure *',
                                prefixIcon: Icon(Icons.straighten_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: _catalogs.units.map((u) {
                                return DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis));
                              }).toList(),
                              onChanged: isSubmitting ? null : (val) {
                                if (val != null) setState(() => _unit = val);
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('inventory_form_barcode'),
                              controller: _barcodeController,
                              enabled: !isSubmitting,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Barcode (optional)',
                                hintText: 'e.g. 8901234567890',
                                prefixIcon: Icon(Icons.barcode_reader),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Section B: Warehouse & Stock (Read-only quantity & calculated status)
                      InventorySectionCard(
                        title: 'Warehouse & Stock',
                        subtitle: 'Storage allocation and inventory threshold limits.',
                        icon: Icons.warehouse_outlined,
                        children: [
                          // Read-only stock quantity and status
                          if (summary != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withAlpha(70),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colorScheme.outlineVariant.withAlpha(128)),
                              ),
                              child: isDesktop
                                  ? Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Current Stock Quantity',
                                              style: theme.textTheme.labelMedium?.copyWith(
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${summary.quantityOnHand} $_unit',
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Calculated Stock Status',
                                              style: theme.textTheme.labelMedium?.copyWith(
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            StockStatusBadge(status: summary.stockStatus),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Current Stock Quantity',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${summary.quantityOnHand} $_unit',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Calculated Stock Status',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        StockStatusBadge(status: summary.stockStatus),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Quantity is strictly derived from the stock movement ledger. Use Stock Adjustment to modify quantity.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (isDesktop)
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    key: const Key('inventory_form_warehouse'),
                                    initialValue: _catalogs.isValidWarehouse(_warehouse)
                                        ? _warehouse
                                        : (_catalogs.warehouses.isNotEmpty ? _catalogs.warehouses.first : null),
                                    decoration: const InputDecoration(
                                      labelText: 'Warehouse *',
                                      prefixIcon: Icon(Icons.store_mall_directory_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _catalogs.warehouses.map((wh) {
                                      return DropdownMenuItem(value: wh, child: Text(wh, overflow: TextOverflow.ellipsis));
                                    }).toList(),
                                    onChanged: isSubmitting ? null : (val) {
                                      if (val != null) setState(() => _warehouse = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    key: const Key('inventory_form_bin_location'),
                                    controller: _binLocationController,
                                    enabled: !isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Bin Location (optional)',
                                      hintText: 'e.g. A3-R2',
                                      prefixIcon: Icon(Icons.grid_view_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            DropdownButtonFormField<String>(
                                    isExpanded: true,
                              key: const Key('inventory_form_warehouse'),
                              initialValue: _catalogs.isValidWarehouse(_warehouse)
                                  ? _warehouse
                                  : (_catalogs.warehouses.isNotEmpty ? _catalogs.warehouses.first : null),
                              decoration: const InputDecoration(
                                labelText: 'Warehouse *',
                                prefixIcon: Icon(Icons.store_mall_directory_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: _catalogs.warehouses.map((wh) {
                                return DropdownMenuItem(value: wh, child: Text(wh, overflow: TextOverflow.ellipsis));
                              }).toList(),
                              onChanged: isSubmitting ? null : (val) {
                                if (val != null) setState(() => _warehouse = val);
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('inventory_form_bin_location'),
                              controller: _binLocationController,
                              enabled: !isSubmitting,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Bin Location (optional)',
                                hintText: 'e.g. A3-R2',
                                prefixIcon: Icon(Icons.grid_view_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          if (isDesktop)
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    key: const Key('inventory_form_reorder_level'),
                                    controller: _reorderLevelController,
                                    enabled: !isSubmitting,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Reorder Level (optional)',
                                      hintText: 'e.g. 10',
                                      helperText: 'Alert triggered when stock falls to/below this point.',
                                      prefixIcon: Icon(Icons.warning_amber_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    key: const Key('inventory_form_max_stock'),
                                    controller: _maxStockController,
                                    enabled: !isSubmitting,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Maximum Stock (optional)',
                                      hintText: 'e.g. 100',
                                      helperText: 'Must be >= reorder level when specified.',
                                      prefixIcon: Icon(Icons.vertical_align_top_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            TextFormField(
                              key: const Key('inventory_form_reorder_level'),
                              controller: _reorderLevelController,
                              enabled: !isSubmitting,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Reorder Level (optional)',
                                hintText: 'e.g. 10',
                                helperText: 'Alert triggered when stock falls to/below this point.',
                                prefixIcon: Icon(Icons.warning_amber_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('inventory_form_max_stock'),
                              controller: _maxStockController,
                              enabled: !isSubmitting,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Maximum Stock (optional)',
                                hintText: 'e.g. 100',
                                helperText: 'Must be >= reorder level when specified.',
                                prefixIcon: Icon(Icons.vertical_align_top_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Section C: Pricing & Commercial Details
                      InventorySectionCard(
                        title: 'Pricing & Commercial Details',
                        subtitle: 'Commercial information with role-based field security.',
                        icon: Icons.payments_outlined,
                        children: [
                          if (canViewSupplier) ...[
                            TextFormField(
                              key: const Key('inventory_form_supplier'),
                              controller: _supplierController,
                              enabled: !isSubmitting,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Supplier (optional)',
                                hintText: 'e.g. Acme Supplies Pvt Ltd',
                                prefixIcon: Icon(Icons.business_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ] else ...[
                            const RestrictedFieldPlaceholder(label: 'Supplier Details'),
                            const SizedBox(height: 14),
                          ],
                          if (isDesktop)
                            Row(
                              children: [
                                Expanded(
                                  child: canViewCost
                                      ? TextFormField(
                                          key: const Key('inventory_form_unit_cost'),
                                          controller: _unitCostController,
                                          enabled: !isSubmitting,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                            labelText: 'Unit Cost (INR)',
                                            hintText: 'e.g. 450.00',
                                            prefixIcon: Icon(Icons.currency_rupee_outlined),
                                            border: OutlineInputBorder(),
                                          ),
                                        )
                                      : const RestrictedFieldPlaceholder(label: 'Unit Cost (INR)'),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    key: const Key('inventory_form_selling_price'),
                                    controller: _sellingPriceController,
                                    enabled: !isSubmitting,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Selling Price (INR)',
                                      hintText: 'e.g. 799.00',
                                      prefixIcon: Icon(Icons.sell_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            if (canViewCost)
                              TextFormField(
                                key: const Key('inventory_form_unit_cost'),
                                controller: _unitCostController,
                                enabled: !isSubmitting,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Unit Cost (INR)',
                                  hintText: 'e.g. 450.00',
                                  prefixIcon: Icon(Icons.currency_rupee_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              )
                            else
                              const RestrictedFieldPlaceholder(label: 'Unit Cost (INR)'),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('inventory_form_selling_price'),
                              controller: _sellingPriceController,
                              enabled: !isSubmitting,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Selling Price (INR)',
                                hintText: 'e.g. 799.00',
                                prefixIcon: Icon(Icons.sell_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('inventory_form_gst_percent'),
                            controller: _gstPercentController,
                            enabled: !isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'GST Percentage (optional)',
                              hintText: 'e.g. 18.0',
                              helperText: 'Standard GST slabs: 0, 5, 12, 18, 28%',
                              prefixIcon: Icon(Icons.percent_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),

                      // Section D: Tracking & Lifecycle
                      InventorySectionCard(
                        title: 'Tracking & Lifecycle',
                        subtitle: 'Batch numbers, expiration dates, active catalog status, and notes.',
                        icon: Icons.track_changes_outlined,
                        children: [
                          if (isDesktop)
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    key: const Key('inventory_form_batch_number'),
                                    controller: _batchNumberController,
                                    enabled: !isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Batch Number (optional)',
                                      hintText: 'e.g. BATCH-2026-X1',
                                      prefixIcon: Icon(Icons.tag_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: InkWell(
                                    key: const Key('inventory_form_expiry_date'),
                                    onTap: isSubmitting
                                        ? null
                                        : () => _pickDate(
                                              context: context,
                                              initialDate: _expiryDate,
                                              onDateSelected: (d) => setState(() => _expiryDate = d),
                                            ),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Expiry Date (optional)',
                                        prefixIcon: const Icon(Icons.event_outlined),
                                        suffixIcon: _expiryDate != null
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 18),
                                                onPressed: () => setState(() => _expiryDate = null),
                                              )
                                            : null,
                                        border: const OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        _expiryDate != null
                                            ? _expiryDate!.toIso8601String().split('T').first
                                            : 'Select date',
                                        style: _expiryDate != null
                                            ? theme.textTheme.bodyMedium
                                            : theme.textTheme.bodyMedium?.copyWith(
                                                color: colorScheme.onSurfaceVariant.withAlpha(128),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            TextFormField(
                              key: const Key('inventory_form_batch_number'),
                              controller: _batchNumberController,
                              enabled: !isSubmitting,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Batch Number (optional)',
                                hintText: 'e.g. BATCH-2026-X1',
                                prefixIcon: Icon(Icons.tag_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            InkWell(
                              key: const Key('inventory_form_expiry_date'),
                              onTap: isSubmitting
                                  ? null
                                  : () => _pickDate(
                                        context: context,
                                        initialDate: _expiryDate,
                                        onDateSelected: (d) => setState(() => _expiryDate = d),
                                      ),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Expiry Date (optional)',
                                  prefixIcon: const Icon(Icons.event_outlined),
                                  suffixIcon: _expiryDate != null
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () => setState(() => _expiryDate = null),
                                        )
                                      : null,
                                  border: const OutlineInputBorder(),
                                ),
                                child: Text(
                                  _expiryDate != null
                                      ? _expiryDate!.toIso8601String().split('T').first
                                      : 'Select date',
                                  style: _expiryDate != null
                                      ? theme.textTheme.bodyMedium
                                      : theme.textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant.withAlpha(128),
                                        ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          InkWell(
                            key: const Key('inventory_form_last_restocked_date'),
                            onTap: isSubmitting
                                ? null
                                : () => _pickDate(
                                      context: context,
                                      initialDate: _lastRestockedDate,
                                      onDateSelected: (d) => setState(() => _lastRestockedDate = d),
                                    ),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Last Restocked Date (optional)',
                                prefixIcon: const Icon(Icons.restore_outlined),
                                suffixIcon: _lastRestockedDate != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () => setState(() => _lastRestockedDate = null),
                                      )
                                    : null,
                                border: const OutlineInputBorder(),
                              ),
                              child: Text(
                                _lastRestockedDate != null
                                    ? _lastRestockedDate!.toIso8601String().split('T').first
                                    : 'Select date',
                                style: _lastRestockedDate != null
                                    ? theme.textTheme.bodyMedium
                                    : theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant.withAlpha(128),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SwitchListTile(
                            key: const Key('inventory_form_is_active'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active Product Catalog Status'),
                            subtitle: Text(_isActive
                                ? 'Active item available for sale and operations.'
                                : 'Inactive/Discontinued catalog item.'),
                            value: _isActive,
                            onChanged: isSubmitting ? null : (val) => setState(() => _isActive = val),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const Key('inventory_form_notes'),
                            controller: _notesController,
                            enabled: !isSubmitting,
                            maxLines: 3,
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                              hintText: 'Internal handling instructions or additional specifications.',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),

                      // Section E: Dynamic Custom Fields
                      InventorySectionCard(
                        title: 'Custom Fields',
                        subtitle: 'Dynamic user-defined fields registered in the CRM.',
                        icon: Icons.tune_outlined,
                        trailing: canManageCustomFields
                            ? OutlinedButton.icon(
                                key: const Key('inventory_add_custom_field_button'),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Field'),
                                onPressed: isSubmitting ? null : () => _openAddCustomFieldDialog(context),
                              )
                            : null,
                        children: [
                          if (_customDefinitions.isEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              child: Text(
                                'No custom fields registered.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ] else ...[
                            for (final def in _customDefinitions) ...[
                              _buildCustomFieldInput(def, isSubmitting),
                              const SizedBox(height: 14),
                            ],
                          ],
                        ],
                      ),

                      const SizedBox(height: 20),

                      const SizedBox(height: 24),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomFieldInput(CustomFieldDefinition def, bool isSubmitting) {
    final label = '${def.label}${def.isRequired ? ' *' : ''}';
    final keyString = 'custom_field_${def.key}';

    switch (def.dataType) {
      case CustomFieldDataType.text:
        return TextFormField(
          key: Key(keyString),
          initialValue: _customValues[def.key]?.toString(),
          enabled: !isSubmitting,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          onChanged: (val) => _customValues[def.key] = val,
        );

      case CustomFieldDataType.number:
        return TextFormField(
          key: Key(keyString),
          initialValue: _customValues[def.key]?.toString(),
          enabled: !isSubmitting,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          onChanged: (val) {
            final parsed = num.tryParse(val.trim());
            if (parsed != null) {
              _customValues[def.key] = parsed;
            } else if (val.trim().isEmpty) {
              _customValues.remove(def.key);
            }
          },
        );

      case CustomFieldDataType.date:
        final currentVal = _customValues[def.key];
        DateTime? dateVal;
        if (currentVal is DateTime) {
          dateVal = currentVal;
        } else if (currentVal is String) {
          dateVal = DateTime.tryParse(currentVal);
        }

        return InkWell(
          key: Key(keyString),
          onTap: isSubmitting
              ? null
              : () => _pickDate(
                    context: context,
                    initialDate: dateVal,
                    onDateSelected: (d) => setState(() => _customValues[def.key] = d),
                  ),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.event_outlined),
              suffixIcon: dateVal != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _customValues.remove(def.key)),
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            child: Text(
              dateVal != null ? dateVal.toIso8601String().split('T').first : 'Select date',
              style: dateVal != null
                  ? Theme.of(context).textTheme.bodyMedium
                  : Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(128),
                      ),
            ),
          ),
        );

      case CustomFieldDataType.boolean:
        final boolVal = _customValues[def.key] == true;
        return SwitchListTile(
          key: Key(keyString),
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: boolVal,
          onChanged: isSubmitting ? null : (val) => setState(() => _customValues[def.key] = val),
        );

      case CustomFieldDataType.dropdown:
        final currentSelected = _customValues[def.key]?.toString();
        return DropdownButtonFormField<String>(
                                    isExpanded: true,
          key: Key(keyString),
          initialValue: def.options.contains(currentSelected) ? currentSelected : null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          items: def.options.map((opt) {
            return DropdownMenuItem(value: opt, child: Text(opt, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: isSubmitting ? null : (val) {
            if (val != null) {
              setState(() => _customValues[def.key] = val);
            }
          },
        );
    }
  }
}
