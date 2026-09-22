import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/policies/inventory_item_administration_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/inventory_item_details_cubit.dart';
import '../bloc/inventory_item_details_state.dart';
import '../utils/inventory_display_formatters.dart';
import 'edit_inventory_item_screen.dart';

/// Read-only item details screen for a specific inventory product.
///
/// Guarded by pre-Cubit authorization check. Displays strictly Name, SKU, and derived Quantity on hand.
/// Administrators receive an [Edit Item] action button.
class InventoryItemDetailsScreen extends StatelessWidget {
  final CurrentUser user;
  final InventoryRepository repository;
  final String itemId;

  const InventoryItemDetailsScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.itemId,
  });

  @override
  Widget build(BuildContext context) {
    // Pre-Cubit guard: zero Cubit initialization if unauthorized.
    final isAuthorized =
        AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView);

    if (!isAuthorized) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider<InventoryItemDetailsCubit>(
      create: (_) => InventoryItemDetailsCubit(repository)..load(itemId),
      child: _InventoryItemDetailsView(
        user: user,
        repository: repository,
        itemId: itemId,
      ),
    );
  }
}

class _InventoryItemDetailsView extends StatelessWidget {
  final CurrentUser user;
  final InventoryRepository repository;
  final String itemId;

  const _InventoryItemDetailsView({
    required this.user,
    required this.repository,
    required this.itemId,
  });

  void _openEdit(BuildContext context, String itemId) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditInventoryItemScreen(
          user: user,
          repository: repository,
          itemId: itemId,
        ),
      ),
    );
    if (updated == true && context.mounted) {
      context.read<InventoryItemDetailsCubit>().load(itemId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Item Details'),
        leading: IconButton(
          key: const Key('inventory_details_back_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          BlocBuilder<InventoryItemDetailsCubit, InventoryItemDetailsState>(
            builder: (context, state) {
              if (InventoryItemAdministrationPolicy.canManage(user) &&
                  state is InventoryItemDetailsLoaded) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilledButton.icon(
                    key: const Key('inventory_details_edit_button'),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Item'),
                    onPressed: () => _openEdit(context, state.summary.item.id),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),

      body: BlocBuilder<InventoryItemDetailsCubit, InventoryItemDetailsState>(
        builder: (context, state) {
          if (state is InventoryItemDetailsLoading ||
              state is InventoryItemDetailsInitial) {
            return const Center(
              child: CircularProgressIndicator(
                key: Key('inventory_details_loading_indicator'),
              ),
            );
          }

          if (state is InventoryItemDetailsNotFound) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  key: const Key('inventory_item_not_found'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 48,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Item not found',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The item with ID "$itemId" does not exist in inventory.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('inventory_not_found_back_button'),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Inventory'),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is InventoryItemDetailsFailure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  key: const Key('inventory_details_failure_view'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('inventory_details_retry_button'),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      onPressed: () =>
                          context.read<InventoryItemDetailsCubit>().retry(),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is InventoryItemDetailsLoaded) {
            final summary = state.summary;
            final item = summary.item;
            final qtyStr = InventoryDisplayFormatters.formatQuantity(
              summary.quantityOnHand,
            );

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 24.0,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Card(
                    key: const Key('inventory_item_details_card'),
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  color: colorScheme.onPrimaryContainer,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      key: const Key('inventory_details_name'),
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'SKU: ${item.sku}',
                                      key: const Key('inventory_details_sku'),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Quantity Section
                          Text(
                            'STOCK ON HAND',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth < 240) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.layers_outlined,
                                            size: 20,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Quantity on hand',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        qtyStr,
                                        key: const Key(
                                          'inventory_details_quantity',
                                        ),
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface,
                                            ),
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Icon(
                                      Icons.layers_outlined,
                                      size: 20,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Quantity on hand',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      qtyStr,
                                      key: const Key(
                                        'inventory_details_quantity',
                                      ),
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurface,
                                          ),
                                    ),
                                  ],
                                );
                              },
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

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
