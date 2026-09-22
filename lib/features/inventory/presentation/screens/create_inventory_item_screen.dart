import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/policies/inventory_item_administration_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/create_inventory_item_cubit.dart';
import '../bloc/create_inventory_item_state.dart';

/// Screen allowing Administrators to create a new Inventory item.
///
/// Guarded by [InventoryItemAdministrationPolicy] before Cubit initialization.
/// Standard users receive [AccessRestrictedScreen] with zero repository interaction.
class CreateInventoryItemScreen extends StatelessWidget {
  final CurrentUser user;
  final InventoryRepository repository;

  const CreateInventoryItemScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    // Pre-Cubit mutation guard: zero Cubit initialization if unauthorized.
    if (!InventoryItemAdministrationPolicy.canManage(user)) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider<CreateInventoryItemCubit>(
      create: (_) => CreateInventoryItemCubit(repository),
      child: const _CreateInventoryItemView(),
    );
  }
}

class _CreateInventoryItemView extends StatefulWidget {
  const _CreateInventoryItemView();

  @override
  State<_CreateInventoryItemView> createState() =>
      _CreateInventoryItemViewState();
}

class _CreateInventoryItemViewState extends State<_CreateInventoryItemView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<CreateInventoryItemCubit>().submit(
        name: _nameController.text,
        sku: _skuController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
        }
      },
      builder: (context, state) {
        final isSubmitting = state is CreateInventoryItemSubmitting;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Add Inventory Item'),
            leading: IconButton(
              key: const Key('create_inventory_item_cancel'),
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
                            'Item Details',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter the unique SKU and display name for this product.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Item Name Field
                          TextFormField(
                            key: const Key('create_inventory_item_name'),
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
                            key: const Key('create_inventory_item_sku'),
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

                          // Actions: Cancel & Create
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
                                    'create_inventory_item_cancel_button',
                                  ),
                                  onPressed: isSubmitting
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton.icon(
                                  key: const Key(
                                    'create_inventory_item_submit',
                                  ),
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
                                      : const Icon(Icons.add, size: 18),
                                  label: Text(
                                    isSubmitting
                                        ? 'Creating...'
                                        : 'Create Item',
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
