import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/policies/inventory_item_administration_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/edit_inventory_item_cubit.dart';
import '../bloc/edit_inventory_item_state.dart';

/// Screen allowing Administrators to edit an Inventory item's identity ([name], [sku]).
///
/// Guarded by [InventoryItemAdministrationPolicy] before Cubit initialization.
/// Standard users receive [AccessRestrictedScreen] with zero repository interaction.
///
/// Invariant: Strictly edits identity. No quantity or stock editing fields are present.
class EditInventoryItemScreen extends StatelessWidget {
  final CurrentUser user;
  final InventoryRepository repository;
  final String itemId;

  const EditInventoryItemScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.itemId,
  });

  @override
  Widget build(BuildContext context) {
    // Pre-Cubit mutation guard: zero Cubit initialization if unauthorized.
    if (!InventoryItemAdministrationPolicy.canManage(user)) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider<EditInventoryItemCubit>(
      create: (_) => EditInventoryItemCubit(repository)..load(itemId),
      child: _EditInventoryItemView(itemId: itemId),
    );
  }
}

class _EditInventoryItemView extends StatefulWidget {
  final String itemId;

  const _EditInventoryItemView({required this.itemId});

  @override
  State<_EditInventoryItemView> createState() => _EditInventoryItemViewState();
}

class _EditInventoryItemViewState extends State<_EditInventoryItemView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  void _populateForm(String name, String sku) {
    if (!_initialized) {
      _nameController.text = name;
      _skuController.text = sku;
      _initialized = true;
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<EditInventoryItemCubit>().submit(
        name: _nameController.text,
        sku: _skuController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
        }
      },
      builder: (context, state) {
        final isSubmitting = state is EditInventoryItemSubmitting;

        if (state is EditInventoryItemLoading ||
            state is EditInventoryItemInitial) {
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
                  key: const Key('edit_inventory_not_found'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 48,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Inventory item not found',
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

        // Populate fields from loaded state
        if (state is EditInventoryItemLoaded) {
          _populateForm(state.item.item.name, state.item.item.sku);
        } else if (state is EditInventoryItemFailure && state.item != null) {
          _populateForm(state.item!.item.name, state.item!.item.sku);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Inventory Item'),
            leading: IconButton(
              key: const Key('edit_inventory_item_cancel'),
              icon: const Icon(Icons.arrow_back),
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 400
                    ? 12.0
                    : 24.0,
                vertical: 20.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withAlpha(128),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(
                      MediaQuery.of(context).size.width < 400 ? 16.0 : 24.0,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Item Identity',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Update the item display name and SKU. Stock quantity remains derived from the movement ledger.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Item Name Field
                          TextFormField(
                            key: const Key('edit_inventory_item_name'),
                            controller: _nameController,
                            enabled: !isSubmitting,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Item Name *',
                              hintText: 'e.g. Wireless Mouse',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Item name is required.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // SKU Field
                          TextFormField(
                            key: const Key('edit_inventory_item_sku'),
                            controller: _skuController,
                            enabled: !isSubmitting,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'SKU *',
                              hintText: 'e.g. INV-042',
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
                          const SizedBox(height: 28),

                          // Actions: Cancel & Save Changes
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                OutlinedButton(
                                  key: const Key(
                                    'edit_inventory_item_cancel_button',
                                  ),
                                  onPressed: isSubmitting
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton.icon(
                                  key: const Key('edit_inventory_item_save'),
                                  onPressed: isSubmitting ? null : _submit,
                                  icon: isSubmitting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.save_outlined,
                                          size: 18,
                                        ),
                                  label: Text(
                                    isSubmitting ? 'Saving...' : 'Save Changes',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
