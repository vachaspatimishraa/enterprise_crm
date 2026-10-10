import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../data/repositories/mock_inventory_repository.dart';
import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_catalogs.dart';
import '../../domain/policies/inventory_field_access_policy.dart';
import '../../domain/policies/inventory_item_administration_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/create_inventory_item_cubit.dart';
import '../bloc/create_inventory_item_state.dart';
import '../widgets/inventory_form_sections.dart';

/// Screen allowing authorized users to create a new Inventory item with
/// full standard fields and dynamic custom fields.
class CreateInventoryItemScreen extends StatelessWidget {
  final CurrentUser user;
  final CurrentUser Function()? currentUserProvider;
  final InventoryRepository repository;

  const CreateInventoryItemScreen({
    super.key,
    required this.user,
    this.currentUserProvider,
    required this.repository,
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
    if (liveUser == null || !InventoryItemAdministrationPolicy.canCreate(liveUser)) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider<CreateInventoryItemCubit>(
      create: (_) => CreateInventoryItemCubit(repository)..loadDefinitions(),
      child: _CreateInventoryItemView(
        user: liveUser,
        repository: repository,
        currentUserResolver: () => _resolveUser(context),
      ),
    );
  }
}

class _CreateInventoryItemView extends StatefulWidget {
  final CurrentUser user;
  final InventoryRepository repository;
  final CurrentUser? Function() currentUserResolver;

  const _CreateInventoryItemView({
    required this.user,
    required this.repository,
    required this.currentUserResolver,
  });

  @override
  State<_CreateInventoryItemView> createState() => _CreateInventoryItemViewState();
}

class _CreateInventoryItemViewState extends State<_CreateInventoryItemView> {
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
  final _openingStockController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    final repo = widget.repository;
    if (repo is MockInventoryRepository) {
      _catalogs = repo.catalogs;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _binLocationController.dispose();
    _reorderLevelController.dispose();
    _maxStockController.dispose();
    _openingStockController.dispose();
    _supplierController.dispose();
    _unitCostController.dispose();
    _sellingPriceController.dispose();
    _gstPercentController.dispose();
    _batchNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _syncCatalogsAndDefinitions(CreateInventoryItemInitial state) {
    _catalogs = state.catalogs;
    final existingKeys = _customDefinitions.map((d) => d.key).toSet();
    final newDefs = state.customFieldDefinitions.where((d) => !existingKeys.contains(d.key));
    if (newDefs.isNotEmpty || _customDefinitions.isEmpty) {
      _customDefinitions = [..._customDefinitions, ...newDefs];
    }

    // Apply default values for uninitialized custom fields
    for (final def in _customDefinitions) {
      if (!_customValues.containsKey(def.key) && def.defaultValue != null) {
        _customValues[def.key] = def.defaultValue;
      }
    }

    if (!_catalogs.isValidCategory(_category) && _catalogs.categories.isNotEmpty) {
      _category = _catalogs.categories.first;
    }
    if (!_catalogs.isValidUnit(_unit) && _catalogs.units.isNotEmpty) {
      _unit = _catalogs.units.first;
    }
    if (!_catalogs.isValidWarehouse(_warehouse) && _catalogs.warehouses.isNotEmpty) {
      _warehouse = _catalogs.warehouses.first;
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
    if (liveUser == null || !InventoryItemAdministrationPolicy.canCreate(liveUser)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired or unauthorized to create items.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Opening stock validation
    final openingStockRaw = _openingStockController.text.trim();
    if (openingStockRaw.isNotEmpty) {
      final parsed = double.tryParse(openingStockRaw);
      if (parsed == null || !parsed.isFinite || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening stock must be greater than zero.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Numeric conversions
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

    context.read<CreateInventoryItemCubit>().submit(
      name: _nameController.text,
      sku: _skuController.text,
      openingStockText: openingStockRaw.isNotEmpty ? openingStockRaw : null,
      category: _category,
      brand: _brandController.text.trim().isNotEmpty ? _brandController.text.trim() : null,
      unit: _unit,
      barcode: _barcodeController.text.trim().isNotEmpty ? _barcodeController.text.trim() : null,
      warehouse: _warehouse,
      binLocation: _binLocationController.text.trim().isNotEmpty ? _binLocationController.text.trim() : null,
      supplier: InventoryFieldAccessPolicy.canViewSupplier(liveUser) && _supplierController.text.trim().isNotEmpty
          ? _supplierController.text.trim()
          : null,
      unitCostInr: InventoryFieldAccessPolicy.canViewCost(liveUser) ? unitCost : null,
      sellingPriceInr: sellingPrice,
      reorderLevel: reorderLevel,
      maxStock: maxStock,
      gstPercent: gstPercent,
      batchNumber: _batchNumberController.text.trim().isNotEmpty ? _batchNumberController.text.trim() : null,
      expiryDate: _expiryDate,
      lastRestockedDate: _lastRestockedDate,
      isActive: _isActive,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      customFields: Map<String, dynamic>.from(_customValues),
      performedByUserId: liveUser.id,
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

    return BlocConsumer<CreateInventoryItemCubit, CreateInventoryItemState>(
      listener: (context, state) {
        if (state is CreateInventoryItemSuccess) {
          Navigator.of(context).pop(true);
        } else if (state is CreateInventoryItemFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: colorScheme.error,
            ),
          );
        } else if (state is CreateInventoryItemInitial) {
          _syncCatalogsAndDefinitions(state);
        }
      },
      builder: (context, state) {
        final isSubmitting = state is CreateInventoryItemSubmitting;

        if (state is CreateInventoryItemInitial && _customDefinitions.isEmpty) {
          _syncCatalogsAndDefinitions(state);
        }

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
                          key: const Key('create_inventory_item_cancel_button'),
                          onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          key: const Key('create_inventory_item_submit'),
                          onPressed: isSubmitting ? null : _submit,
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.add, size: 18),
                          label: Text(isSubmitting ? 'Creating...' : 'Create Item'),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('create_inventory_item_cancel_button'),
                            onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('create_inventory_item_submit'),
                            onPressed: isSubmitting ? null : _submit,
                            icon: isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.add, size: 18),
                            label: Text(
                              isSubmitting ? 'Creating...' : 'Create Item',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          appBar: AppBar(
            title: const Text('Add Inventory Item'),
            leading: IconButton(
              key: const Key('create_inventory_item_cancel'),
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
                        subtitle: 'Core product identifiers, categorization, and barcode.',
                        icon: Icons.inventory_2_outlined,
                        children: [
                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    key: const Key('create_inventory_item_name'),
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
                                    key: const Key('create_inventory_item_sku'),
                                    controller: _skuController,
                                    enabled: !isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'SKU *',
                                      hintText: 'e.g. 00492-WM',
                                      helperText: 'Unique SKU; leading zeros are preserved.',
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
                              key: const Key('create_inventory_item_name'),
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
                              key: const Key('create_inventory_item_sku'),
                              controller: _skuController,
                              enabled: !isSubmitting,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'SKU *',
                                hintText: 'e.g. 00492-WM',
                                helperText: 'Unique SKU; leading zeros are preserved.',
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
                                    initialValue: _category,
                                    decoration: const InputDecoration(
                                      labelText: 'Category (optional)',
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
                              initialValue: _category,
                              decoration: const InputDecoration(
                                labelText: 'Category (optional)',
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
                                    initialValue: _unit,
                                    decoration: const InputDecoration(
                                      labelText: 'Unit of Measure (optional)',
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
                              initialValue: _unit,
                              decoration: const InputDecoration(
                                labelText: 'Unit of Measure (optional)',
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

                      // Section B: Warehouse & Stock
                      InventorySectionCard(
                        title: 'Warehouse & Stock',
                        subtitle: 'Storage allocation, reorder points, and optional initial opening stock.',
                        icon: Icons.warehouse_outlined,
                        children: [
                          if (isDesktop)
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    key: const Key('inventory_form_warehouse'),
                                    initialValue: _warehouse,
                                    decoration: const InputDecoration(
                                      labelText: 'Warehouse (optional)',
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
                              initialValue: _warehouse,
                              decoration: const InputDecoration(
                                labelText: 'Warehouse (optional)',
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
                          const SizedBox(height: 14),
                          // Opening stock input (only during creation)
                          TextFormField(
                            key: const Key('create_inventory_item_opening_stock'),
                            controller: _openingStockController,
                            enabled: !isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Opening Stock (optional)',
                              hintText: 'e.g. 50',
                              helperText: 'Initial quantity is ledger-backed via an opening stock transaction.',
                              prefixIcon: Icon(Icons.add_chart_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val != null && val.trim().isNotEmpty) {
                                final parsed = double.tryParse(val.trim());
                                if (parsed == null || !parsed.isFinite || parsed <= 0) {
                                  return 'Opening stock must be greater than zero.';
                                }
                              }
                              return null;
                            },
                          ),
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
