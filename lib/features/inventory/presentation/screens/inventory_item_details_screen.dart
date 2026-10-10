import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/entities/inventory_stock_status.dart';
import '../../domain/exceptions/inventory_exception.dart';
import '../../domain/policies/inventory_deletion_policy.dart';
import '../../domain/policies/inventory_field_access_policy.dart';
import '../../domain/policies/inventory_item_administration_policy.dart';
import '../../domain/policies/inventory_stock_management_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/inventory_item_details_cubit.dart';
import '../bloc/inventory_item_details_state.dart';
import '../utils/inventory_display_formatters.dart';
import '../widgets/delete_inventory_item_dialog.dart';
import 'adjust_inventory_stock_screen.dart';
import 'edit_inventory_item_screen.dart';
import 'set_opening_stock_screen.dart';
import 'stock_movement_history_screen.dart';

/// Comprehensive read-only item details screen for a specific inventory product.
///
/// Guarded by pre-Cubit authorization check. Displays all catalog, pricing, warehouse,
/// tracking, notes, and custom fields saved by the user.
/// Administrators receive [Edit Item] and contextual stock mutation actions ([Set Opening Stock]
/// or [Adjust Stock] depending on movement history).
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
      ),
    );
  }
}

class _InventoryItemDetailsView extends StatelessWidget {
  final CurrentUser user;
  final InventoryRepository repository;

  const _InventoryItemDetailsView({
    required this.user,
    required this.repository,
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

  void _openSetOpeningStock(BuildContext context, String itemId) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SetOpeningStockScreen(
          user: user,
          repository: repository,
          itemId: itemId,
        ),
      ),
    );
    if (result == true && context.mounted) {
      context.read<InventoryItemDetailsCubit>().load(itemId);
    }
  }

  void _openAdjustStock(BuildContext context, String itemId) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdjustInventoryStockScreen(
          user: user,
          repository: repository,
          itemId: itemId,
        ),
      ),
    );
    if (result == true && context.mounted) {
      context.read<InventoryItemDetailsCubit>().load(itemId);
    }
  }

  void _openStockHistory(
    BuildContext context,
    String itemId, {
    InventoryItemSummary? summary,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockMovementHistoryScreen(
          user: user,
          repository: repository,
          itemId: itemId,
          itemSummary: summary,
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    InventoryItem item,
    double currentQuantity,
  ) async {
    final confirmed = await DeleteInventoryItemDialog.show(
      context,
      item: item,
      currentQuantity: currentQuantity,
    );
    if (confirmed == true && context.mounted) {
      try {
        await repository.requestItemDeletion(
          itemId: item.id,
          performedByUserId: user.id,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.name} scheduled for permanent deletion.'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  try {
                    await repository.undoItemDeletion(
                      itemId: item.id,
                      performedByUserId: user.id,
                    );
                    if (context.mounted) {
                      context.read<InventoryItemDetailsCubit>().load(item.id);
                    }
                  } catch (_) {}
                },
              ),
              duration: const Duration(seconds: 10),
            ),
          );
          context.read<InventoryItemDetailsCubit>().load(item.id);
        }
      } on InventoryDeletionBlockedException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete item: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _formatCustomKey(String key) {
    return key
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Widget _buildStockStatusBadge(
    BuildContext context,
    InventoryStockStatus status,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fg;
    final Color bg;
    final String label;

    switch (status) {
      case InventoryStockStatus.inStock:
        fg = isDark ? Colors.green.shade300 : Colors.green.shade800;
        bg = isDark
            ? Colors.green.shade900.withValues(alpha: 0.4)
            : Colors.green.shade50;
        label = 'In Stock';
        break;
      case InventoryStockStatus.lowStock:
        fg = isDark ? Colors.orange.shade300 : Colors.orange.shade800;
        bg = isDark
            ? Colors.orange.shade900.withValues(alpha: 0.4)
            : Colors.orange.shade50;
        label = 'Low Stock';
        break;
      case InventoryStockStatus.outOfStock:
        fg = isDark ? Colors.red.shade300 : Colors.red.shade800;
        bg = isDark
            ? Colors.red.shade900.withValues(alpha: 0.4)
            : Colors.red.shade50;
        label = 'Out of Stock';
        break;
      case InventoryStockStatus.overstock:
        fg = isDark ? Colors.purple.shade300 : Colors.purple.shade800;
        bg = isDark
            ? Colors.purple.shade900.withValues(alpha: 0.4)
            : Colors.purple.shade50;
        label = 'Overstock';
        break;
      case InventoryStockStatus.discontinued:
        fg = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
        bg = isDark
            ? Colors.grey.shade900.withValues(alpha: 0.4)
            : Colors.grey.shade200;
        label = 'Discontinued';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    Key? key,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              key: key,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildResponsiveGrid(List<Widget> items, bool isWide) {
    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      );
    }
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      if (i + 1 < items.length) {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: items[i]),
              const SizedBox(width: 20),
              Expanded(child: items[i + 1]),
            ],
          ),
        );
      } else {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: items[i]),
              const SizedBox(width: 20),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
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
              if (state is InventoryItemDetailsLoaded) {
                final isPending = state.pendingDeletion != null;
                final canEdit =
                    !isPending &&
                    InventoryItemAdministrationPolicy.canEdit(user);
                final canDelete =
                    !isPending && InventoryDeletionPolicy.canDelete(user);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const Key('inventory_details_stock_history_button'),
                      icon: const Icon(Icons.history),
                      tooltip: 'Stock History',
                      onPressed: () => _openStockHistory(
                        context,
                        state.summary.item.id,
                        summary: state.summary,
                      ),
                    ),
                    if (canEdit)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilledButton.icon(
                          key: const Key('inventory_details_edit_button'),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit Item'),
                          onPressed: () =>
                              _openEdit(context, state.summary.item.id),
                        ),
                      ),
                    if (canDelete)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: IconButton(
                          key: const Key('inventory_details_delete_button'),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete Item',
                          onPressed: () => _confirmDelete(
                            context,
                            state.summary.item,
                            state.summary.quantityOnHand,
                          ),
                        ),
                      ),
                  ],
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
                      'The requested inventory item could not be loaded or may have been deleted.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back to Inventory'),
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
                  key: const Key('inventory_item_details_error'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: colorScheme.error),
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
            final canViewCost = InventoryFieldAccessPolicy.canViewCost(user);
            final canViewSupplier = InventoryFieldAccessPolicy.canViewSupplier(user);

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 24.0,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;

                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Card(
                        key: const Key('inventory_item_details_card'),
                        elevation: 0,
                        color: colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Pending Deletion Notice
                              if (state.pendingDeletion != null) ...[
                                Container(
                                  key: const Key(
                                    'inventory_details_pending_deletion_banner',
                                  ),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: colorScheme.onErrorContainer,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'This item is pending permanent deletion (${state.pendingDeletion!.undoDeadline.difference(DateTime.now()).inSeconds.clamp(0, 60)}s remaining).',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: colorScheme.onErrorContainer,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      if (InventoryDeletionPolicy.canUndo(
                                        user,
                                        initiatedByUserId: state
                                            .pendingDeletion!
                                            .initiatedByUserId,
                                      ))
                                        FilledButton.tonal(
                                          key: const Key(
                                            'inventory_details_undo_delete_button',
                                          ),
                                          onPressed: () async {
                                            try {
                                              await repository.undoItemDeletion(
                                                itemId: item.id,
                                                performedByUserId: user.id,
                                              );
                                              if (context.mounted) {
                                                context
                                                    .read<
                                                      InventoryItemDetailsCubit
                                                    >()
                                                    .load(item.id);
                                              }
                                            } catch (_) {}
                                          },
                                          child: const Text('Undo Delete'),
                                        ),
                                    ],
                                  ),
                                ),
                              ],

                              // Header Title, SKU and Status Badges
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.inventory_2_outlined,
                                      color: colorScheme.onPrimaryContainer,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          key: const Key('inventory_details_name'),
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'SKU: ${item.sku}',
                                          key: const Key('inventory_details_sku'),
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                color: colorScheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            // Active / Inactive Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: item.isActive
                                                    ? Colors.green.withValues(alpha: 0.12)
                                                    : Colors.grey.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: item.isActive ? Colors.green : Colors.grey,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                item.isActive ? 'Active' : 'Inactive',
                                                style: theme.textTheme.labelSmall?.copyWith(
                                                  color: item.isActive
                                                      ? Colors.green.shade800
                                                      : Colors.grey.shade800,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            // Stock Status Badge
                                            _buildStockStatusBadge(context, summary.stockStatus),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),
                              const Divider(),

                              // Section 1: Stock on Hand (Prominent highlight)
                              const SizedBox(height: 12),
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
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.layers_outlined,
                                            size: 24,
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Quantity on hand',
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  color: colorScheme.onSurfaceVariant,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                qtyStr,
                                                key: const Key('inventory_details_quantity'),
                                                style: theme.textTheme.headlineSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: TextButton.icon(
                                        key: const Key('inventory_details_view_history_button'),
                                        icon: const Icon(Icons.history, size: 18),
                                        label: const Text('View Stock History'),
                                        onPressed: () => _openStockHistory(
                                          context,
                                          item.id,
                                          summary: summary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Stock Management Action Buttons
                              if (state.pendingDeletion == null &&
                                  InventoryStockManagementPolicy.canManageStock(user)) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: !state.hasStockMovements
                                      ? FilledButton.tonalIcon(
                                          key: const Key(
                                            'inventory_details_set_opening_stock_button',
                                          ),
                                          icon: const Icon(
                                            Icons.add_chart_outlined,
                                            size: 18,
                                          ),
                                          label: const Text('Set Opening Stock'),
                                          onPressed: () => _openSetOpeningStock(
                                            context,
                                            item.id,
                                          ),
                                        )
                                      : FilledButton.tonalIcon(
                                          key: const Key(
                                            'inventory_details_adjust_stock_button',
                                          ),
                                          icon: const Icon(
                                            Icons.tune_outlined,
                                            size: 18,
                                          ),
                                          label: const Text('Adjust Stock'),
                                          onPressed: () =>
                                              _openAdjustStock(context, item.id),
                                        ),
                                ),
                              ],

                              // Section 2: Catalog Details
                              _buildSectionCard(
                                context,
                                title: 'PRODUCT IDENTIFIERS & CATALOG',
                                icon: Icons.category_outlined,
                                children: [
                                  _buildResponsiveGrid(
                                    [
                                      _buildDetailRow(
                                        context,
                                        'Category',
                                        item.category.trim().isNotEmpty ? item.category : 'General',
                                        icon: Icons.folder_outlined,
                                      ),
                                      _buildDetailRow(
                                        context,
                                        'Brand',
                                        item.brand?.trim().isNotEmpty == true ? item.brand! : '—',
                                        icon: Icons.branding_watermark_outlined,
                                      ),
                                      _buildDetailRow(
                                        context,
                                        'Unit of Measure',
                                        item.unit.trim().isNotEmpty ? item.unit : 'piece',
                                        icon: Icons.straighten_outlined,
                                      ),
                                      _buildDetailRow(
                                        context,
                                        'Barcode / UPC',
                                        item.barcode?.trim().isNotEmpty == true ? item.barcode! : '—',
                                        icon: Icons.qr_code_2_outlined,
                                      ),
                                    ],
                                    isWide,
                                  ),
                                ],
                              ),

                              // Section 3: Warehouse & Stock Thresholds
                              _buildSectionCard(
                                context,
                                title: 'WAREHOUSE & THRESHOLDS',
                                icon: Icons.warehouse_outlined,
                                children: [
                                  _buildResponsiveGrid(
                                    [
                                      _buildDetailRow(
                                        context,
                                        'Warehouse',
                                        item.warehouse.trim().isNotEmpty ? item.warehouse : 'Default',
                                        icon: Icons.store_outlined,
                                      ),
                                      _buildDetailRow(
                                        context,
                                        'Bin Location',
                                        item.binLocation?.trim().isNotEmpty == true ? item.binLocation! : '—',
                                        icon: Icons.location_on_outlined,
                                      ),
                                      _buildDetailRow(
                                        context,
                                        'Reorder Level',
                                        item.reorderLevel != null
                                            ? InventoryDisplayFormatters.formatQuantity(item.reorderLevel!)
                                            : '—',
                                        icon: Icons.warning_amber_outlined,
                                      ),
                                      _buildDetailRow(
                                        context,
                                        'Maximum Stock',
                                        item.maxStock != null
                                            ? InventoryDisplayFormatters.formatQuantity(item.maxStock!)
                                            : '—',
                                        icon: Icons.vertical_align_top_outlined,
                                      ),
                                    ],
                                    isWide,
                                  ),
                                ],
                              ),

                              // Section 4: Pricing & Taxes
                              _buildSectionCard(
                                context,
                                title: 'PRICING & VALUATION',
                                icon: Icons.currency_rupee,
                                children: [
                                  _buildResponsiveGrid(
                                    [
                                      _buildDetailRow(
                                        context,
                                        'Unit Cost',
                                        canViewCost
                                            ? (item.unitCostInr != null
                                                ? '₹${item.unitCostInr!.toStringAsFixed(2)}'
                                                : '—')
                                            : 'Restricted (Admin only)',
                                        icon: Icons.attach_money,
                                      ),
                                      _buildDetailRow(
                                        context,
                                        'Selling Price',
                                        item.sellingPriceInr != null
                                            ? '₹${item.sellingPriceInr!.toStringAsFixed(2)}'
                                            : '—',
                                        icon: Icons.sell_outlined,
                                      ),
                                      _buildDetailRow(
                                        context,
                                        'GST Rate',
                                        item.gstPercent != null
                                            ? '${item.gstPercent!.toStringAsFixed(item.gstPercent! % 1 == 0 ? 0 : 2)}%'
                                            : '—',
                                        icon: Icons.receipt_long_outlined,
                                      ),
                                    ],
                                    isWide,
                                  ),
                                ],
                              ),

                              // Section 5: Tracking & Supplier
                              _buildSectionCard(
                                context,
                                title: 'BATCH, DATES & SUPPLIER',
                                icon: Icons.schedule_outlined,
                                children: [
                                  _buildResponsiveGrid(
                                    [
                                      _buildDetailRow(
                                        context,
                                        'Supplier',
                                        canViewSupplier
                                            ? (item.supplier?.trim().isNotEmpty == true
                                                ? item.supplier!
                                                : '—')
                                            : 'Restricted (Admin only)',
                                        icon: Icons.local_shipping_outlined,
                                      ),
                                      _buildDetailRow(
                                        context,
                                        'Batch / Lot',
                                        item.batchNumber?.trim().isNotEmpty == true
                                            ? item.batchNumber!
                                            : '—',
                                        icon: Icons.numbers_outlined,
                                      ),
                                      _buildDetailRow(
                                        context,
                                        'Expiry Date',
                                        item.expiryDate != null ? _formatDate(item.expiryDate!) : '—',
                                        icon: Icons.event_busy_outlined,
                                      ),
                                      _buildDetailRow(
                                        context,
                                        'Last Restocked',
                                        item.lastRestockedDate != null
                                            ? _formatDate(item.lastRestockedDate!)
                                            : '—',
                                        icon: Icons.event_available_outlined,
                                      ),
                                    ],
                                    isWide,
                                  ),
                                ],
                              ),

                              // Section 6: Notes
                              if (item.notes?.trim().isNotEmpty == true)
                                _buildSectionCard(
                                  context,
                                  title: 'INTERNAL NOTES',
                                  icon: Icons.notes_outlined,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Text(
                                        item.notes!,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              // Section 7: Dynamic Custom Fields
                              if (item.customFields.isNotEmpty)
                                _buildSectionCard(
                                  context,
                                  title: 'CUSTOM ATTRIBUTES',
                                  icon: Icons.extension_outlined,
                                  children: [
                                    _buildResponsiveGrid(
                                      item.customFields.entries.map((entry) {
                                        return _buildDetailRow(
                                          context,
                                          _formatCustomKey(entry.key),
                                          entry.value?.toString().trim().isNotEmpty == true
                                              ? entry.value.toString()
                                              : '—',
                                          icon: Icons.data_object_outlined,
                                        );
                                      }).toList(),
                                      isWide,
                                    ),
                                  ],
                                ),

                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
