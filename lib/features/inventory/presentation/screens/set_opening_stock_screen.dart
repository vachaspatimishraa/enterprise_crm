import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/policies/inventory_stock_management_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/set_opening_stock_cubit.dart';
import '../bloc/set_opening_stock_state.dart';
import '../utils/inventory_display_formatters.dart';

/// Screen allowing administrators to record the one-time opening stock for an uninitialized item.
///
/// Protected by a pre-Cubit authorization guard. Standard users receive [AccessRestrictedScreen].
class SetOpeningStockScreen extends StatelessWidget {
  final CurrentUser user;
  final InventoryRepository repository;
  final String itemId;

  const SetOpeningStockScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.itemId,
  });

  @override
  Widget build(BuildContext context) {
    if (!InventoryStockManagementPolicy.canManageStock(user)) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider<SetOpeningStockCubit>(
      create: (_) => SetOpeningStockCubit(repository)..load(itemId),
      child: _SetOpeningStockView(user: user, itemId: itemId),
    );
  }
}

class _SetOpeningStockView extends StatefulWidget {
  final CurrentUser user;
  final String itemId;

  const _SetOpeningStockView({required this.user, required this.itemId});

  @override
  State<_SetOpeningStockView> createState() => _SetOpeningStockViewState();
}

class _SetOpeningStockViewState extends State<_SetOpeningStockView> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rawText = _quantityController.text.trim();
    final quantity = double.tryParse(rawText);
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening quantity must be greater than zero.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.read<SetOpeningStockCubit>().submit(
      itemId: widget.itemId,
      quantity: quantity,
      performedByUserId: widget.user.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocConsumer<SetOpeningStockCubit, SetOpeningStockState>(
      listener: (context, state) {
        if (state is SetOpeningStockSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening stock recorded successfully.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state is SetOpeningStockFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state is SetOpeningStockSubmitting;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Set Opening Stock'),
            leading: IconButton(
              key: const Key('set_opening_stock_back_button'),
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 400;

              if (state is SetOpeningStockLoading ||
                  state is SetOpeningStockInitial) {
                return const Center(
                  child: CircularProgressIndicator(
                    key: Key('set_opening_stock_loading_indicator'),
                  ),
                );
              }

              if (state is SetOpeningStockNotFound) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Inventory item not found.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state is SetOpeningStockUnavailable) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 48,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.message,
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to Details'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final itemSummary = state is SetOpeningStockReady
                  ? state.item
                  : state is SetOpeningStockSubmitting
                  ? state.item
                  : state is SetOpeningStockFailure
                  ? state.item
                  : null;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isVeryNarrow ? 12.0 : 24.0,
                    vertical: 24.0,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      key: const Key('set_opening_stock_card'),
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isVeryNarrow ? 16.0 : 24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Initial Stock Count',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Record the initial physical quantity on hand for this item. Opening stock can only be recorded once.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Read-only item context info
                              if (itemSummary != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        itemSummary.item.name,
                                        key: const Key(
                                          'set_opening_stock_context_name',
                                        ),
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            'SKU: ${itemSummary.item.sku}',
                                            key: const Key(
                                              'set_opening_stock_context_sku',
                                            ),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          Text(
                                            'Current: ${InventoryDisplayFormatters.formatQuantity(itemSummary.quantityOnHand)}',
                                            key: const Key(
                                              'set_opening_stock_context_quantity',
                                            ),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              TextFormField(
                                key: const Key('set_opening_stock_quantity'),
                                controller: _quantityController,
                                enabled: !isSubmitting,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: 'Opening Quantity *',
                                  hintText: 'e.g. 10 or 25.5',
                                  prefixIcon: const Icon(Icons.numbers),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Opening quantity is required.';
                                  }
                                  final parsed = double.tryParse(value.trim());
                                  if (parsed == null || !parsed.isFinite) {
                                    return 'Enter a valid quantity.';
                                  }
                                  if (parsed <= 0) {
                                    return 'Opening quantity must be greater than zero.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    OutlinedButton(
                                      key: const Key(
                                        'set_opening_stock_cancel',
                                      ),
                                      onPressed: isSubmitting
                                          ? null
                                          : () => Navigator.of(context).pop(),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton.icon(
                                      key: const Key(
                                        'set_opening_stock_submit',
                                      ),
                                      icon: isSubmitting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.check, size: 18),
                                      label: const Text('Set Opening Stock'),
                                      onPressed: isSubmitting ? null : _submit,
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
              );
            },
          ),
        );
      },
    );
  }
}
