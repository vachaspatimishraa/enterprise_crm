import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/policies/inventory_stock_management_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/adjust_inventory_stock_cubit.dart';
import '../bloc/adjust_inventory_stock_state.dart';
import '../utils/inventory_display_formatters.dart';

/// Screen allowing administrators to record manual stock adjustments (increases/decreases).
///
/// Protected by a pre-Cubit authorization guard. Standard users receive [AccessRestrictedScreen].
class AdjustInventoryStockScreen extends StatelessWidget {
  final CurrentUser user;
  final InventoryRepository repository;
  final String itemId;

  const AdjustInventoryStockScreen({
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

    return BlocProvider<AdjustInventoryStockCubit>(
      create: (_) => AdjustInventoryStockCubit(repository)..load(itemId),
      child: _AdjustInventoryStockView(user: user, itemId: itemId),
    );
  }
}

class _AdjustInventoryStockView extends StatefulWidget {
  final CurrentUser user;
  final String itemId;

  const _AdjustInventoryStockView({required this.user, required this.itemId});

  @override
  State<_AdjustInventoryStockView> createState() =>
      _AdjustInventoryStockViewState();
}

class _AdjustInventoryStockViewState extends State<_AdjustInventoryStockView> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  StockAdjustmentDirection _direction = StockAdjustmentDirection.increase;

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rawQuantity = _quantityController.text.trim();
    final magnitude = double.tryParse(rawQuantity);
    if (magnitude == null || !magnitude.isFinite || magnitude <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantity must be greater than zero.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final trimmedReason = _reasonController.text.trim();
    if (trimmedReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reason is required.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.read<AdjustInventoryStockCubit>().submit(
      itemId: widget.itemId,
      direction: _direction,
      magnitude: magnitude,
      reason: trimmedReason,
      performedByUserId: widget.user.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocConsumer<AdjustInventoryStockCubit, AdjustInventoryStockState>(
      listener: (context, state) {
        if (state is AdjustInventoryStockSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stock adjusted successfully.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state is AdjustInventoryStockFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state is AdjustInventoryStockSubmitting;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Adjust Stock'),
            leading: IconButton(
              key: const Key('adjust_stock_back_button'),
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 400;

              if (state is AdjustInventoryStockLoading ||
                  state is AdjustInventoryStockInitial) {
                return const Center(
                  child: CircularProgressIndicator(
                    key: Key('adjust_stock_loading_indicator'),
                  ),
                );
              }

              if (state is AdjustInventoryStockNotFound) {
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

              if (state is AdjustInventoryStockUnavailable) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 48,
                          color: colorScheme.error,
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

              final itemSummary = state is AdjustInventoryStockReady
                  ? state.item
                  : state is AdjustInventoryStockSubmitting
                  ? state.item
                  : state is AdjustInventoryStockFailure
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
                      key: const Key('adjust_stock_card'),
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
                                'Manual Stock Adjustment',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Apply a manual increase or decrease to inventory stock on hand. A non-blank reason is required for auditing.',
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
                                          'adjust_stock_context_name',
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
                                              'adjust_stock_context_sku',
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
                                              'adjust_stock_context_quantity',
                                            ),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Direction selection
                              Text(
                                'Adjustment Direction *',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child:
                                    SegmentedButton<StockAdjustmentDirection>(
                                      segments: const [
                                        ButtonSegment(
                                          value:
                                              StockAdjustmentDirection.increase,
                                          label: Text(
                                            'Increase Stock (+)',
                                            key: Key(
                                              'adjust_stock_direction_increase',
                                            ),
                                          ),
                                          icon: Icon(Icons.add_circle_outline),
                                        ),
                                        ButtonSegment(
                                          value:
                                              StockAdjustmentDirection.decrease,
                                          label: Text(
                                            'Decrease Stock (-)',
                                            key: Key(
                                              'adjust_stock_direction_decrease',
                                            ),
                                          ),
                                          icon: Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                        ),
                                      ],
                                      selected: {_direction},
                                      onSelectionChanged: isSubmitting
                                          ? null
                                          : (newSelection) {
                                              setState(() {
                                                _direction = newSelection.first;
                                              });
                                            },
                                    ),
                              ),
                              const SizedBox(height: 20),

                              // Quantity input
                              TextFormField(
                                key: const Key('adjust_stock_quantity'),
                                controller: _quantityController,
                                enabled: !isSubmitting,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: 'Quantity *',
                                  hintText: 'e.g. 5 or 10.5',
                                  prefixIcon: const Icon(Icons.numbers),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Quantity is required.';
                                  }
                                  final parsed = double.tryParse(value.trim());
                                  if (parsed == null || !parsed.isFinite) {
                                    return 'Enter a valid quantity.';
                                  }
                                  if (parsed <= 0) {
                                    return 'Quantity must be greater than zero.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Reason input
                              TextFormField(
                                key: const Key('adjust_stock_reason'),
                                controller: _reasonController,
                                enabled: !isSubmitting,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: 'Reason *',
                                  hintText:
                                      'e.g. Annual audit count correction, damaged units',
                                  prefixIcon: const Icon(
                                    Icons.description_outlined,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Reason is required.';
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
                                      key: const Key('adjust_stock_cancel'),
                                      onPressed: isSubmitting
                                          ? null
                                          : () => Navigator.of(context).pop(),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton.icon(
                                      key: const Key('adjust_stock_submit'),
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
                                      label: const Text('Apply Adjustment'),
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
