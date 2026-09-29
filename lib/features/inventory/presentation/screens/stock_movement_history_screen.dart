import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/entities/stock_movement_record.dart';
import '../../domain/entities/stock_movement_type.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/stock_movement_history_cubit.dart';
import '../bloc/stock_movement_history_state.dart';
import '../utils/inventory_display_formatters.dart';

/// Available local filter options for stock movement history presentation.
enum StockMovementFilter { all, openingStock, adjustment }

/// Screen presenting the read-only chronological stock movement history and running balances.
///
/// Protected by pre-Cubit authorization check (Admin or `inventory.view` on `CrmModule.inventory`).
/// Standard users without inventory viewing permission receive [AccessRestrictedScreen].
/// Read-only history access remains available during an item's 60-second pending-deletion window.
class StockMovementHistoryScreen extends StatelessWidget {
  final CurrentUser user;
  final InventoryRepository repository;
  final String itemId;
  final InventoryItemSummary? itemSummary;

  const StockMovementHistoryScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.itemId,
    this.itemSummary,
  });

  @override
  Widget build(BuildContext context) {
    // Pre-Cubit guard: zero Cubit initialization if unauthorized.
    final isAuthorized =
        user.isAdmin ||
        (AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
            AccessPolicy.hasPermission(user, CrmPermissions.inventoryView));

    if (!isAuthorized) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider<StockMovementHistoryCubit>(
      create:
          (_) => StockMovementHistoryCubit(
            repository: repository,
            currentUser: user,
          )..loadHistory(itemId),
      child: _StockMovementHistoryView(
        user: user,
        repository: repository,
        itemId: itemId,
        initialSummary: itemSummary,
      ),
    );
  }
}

class _StockMovementHistoryView extends StatefulWidget {
  final CurrentUser user;
  final InventoryRepository repository;
  final String itemId;
  final InventoryItemSummary? initialSummary;

  const _StockMovementHistoryView({
    required this.user,
    required this.repository,
    required this.itemId,
    this.initialSummary,
  });

  @override
  State<_StockMovementHistoryView> createState() =>
      _StockMovementHistoryViewState();
}

class _StockMovementHistoryViewState extends State<_StockMovementHistoryView> {
  StockMovementFilter _selectedFilter = StockMovementFilter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock History'),
        leading: IconButton(
          key: const Key('stock_history_back_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocBuilder<StockMovementHistoryCubit, StockMovementHistoryState>(
        builder: (context, state) {
          if (state is StockMovementHistoryInitial ||
              state is StockMovementHistoryLoading) {
            return const Center(
              child: CircularProgressIndicator(
                key: Key('stock_history_loading_indicator'),
              ),
            );
          }

          if (state is StockMovementHistoryRestricted) {
            return const AccessRestrictedScreen();
          }

          if (state is StockMovementHistoryNotFound) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  key: const Key('stock_history_not_found_view'),
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
                      key: const Key('stock_history_not_found_title'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The item with ID "${widget.itemId}" does not exist in inventory.',
                      key: const Key('stock_history_not_found_message'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('stock_history_not_found_back_button'),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Inventory'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is StockMovementHistoryFailure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  key: const Key('stock_history_failure_view'),
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
                      key: const Key('stock_history_error_message'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('stock_history_retry_button'),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      onPressed:
                          () =>
                              context.read<StockMovementHistoryCubit>().retry(),
                    ),
                  ],
                ),
              ),
            );
          }

          // State is empty or loaded. Dynamically retrieve item metadata if not passed.
          return FutureBuilder<InventoryItemSummary?>(
            future:
                widget.initialSummary != null
                    ? Future.value(widget.initialSummary)
                    : widget.repository.getItemById(widget.itemId),
            builder: (context, snapshot) {
              final summary = snapshot.data ?? widget.initialSummary;
              final itemName = summary?.item.name ?? 'Item ${widget.itemId}';
              final itemSku = summary?.item.sku ?? '—';

              // Authoritative current balance dynamically derived from the latest ledger movement, independent of filter:
              final double currentQuantity;
              if (state is StockMovementHistoryLoaded) {
                currentQuantity =
                    state.records.isNotEmpty
                        ? state.records.first.runningBalance
                        : (summary?.quantityOnHand ?? 0.0);
              } else {
                currentQuantity = summary?.quantityOnHand ?? 0.0;
              }

              final isLoaded = state is StockMovementHistoryLoaded;
              final List<StockMovementRecord> visibleRecords;
              if (isLoaded) {
                final completeRecords =
                    state.records;
                switch (_selectedFilter) {
                  case StockMovementFilter.all:
                    visibleRecords = completeRecords;
                  case StockMovementFilter.openingStock:
                    visibleRecords =
                        completeRecords
                            .where(
                              (r) =>
                                  r.movement.type ==
                                  StockMovementType.openingStock,
                            )
                            .toList();
                  case StockMovementFilter.adjustment:
                    visibleRecords =
                        completeRecords
                            .where(
                              (r) =>
                                  r.movement.type ==
                                  StockMovementType.adjustment,
                            )
                            .toList();
                }
              } else {
                visibleRecords = const [];
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StockHistoryHeaderCard(
                          itemName: itemName,
                          itemSku: itemSku,
                          currentQuantity: currentQuantity,
                        ),
                        if (isLoaded) ...[
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<StockMovementFilter>(
                              key: const Key(
                                'stock_history_filter_segmented_button',
                              ),
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: StockMovementFilter.all,
                                  label: Text(
                                    'All Movements',
                                    key: Key('stock_history_filter_all'),
                                  ),
                                ),
                                ButtonSegment(
                                  value: StockMovementFilter.openingStock,
                                  label: Text(
                                    'Opening Stock',
                                    key: Key(
                                      'stock_history_filter_opening_stock',
                                    ),
                                  ),
                                ),
                                ButtonSegment(
                                  value: StockMovementFilter.adjustment,
                                  label: Text(
                                    'Adjustment',
                                    key: Key('stock_history_filter_adjustment'),
                                  ),
                                ),
                              ],
                              selected: {_selectedFilter},
                              onSelectionChanged: (newSelection) {
                                setState(() {
                                  _selectedFilter = newSelection.first;
                                });
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Expanded(
                          child:
                              !isLoaded
                                  ? const _StockHistoryEmptyView()
                                  : visibleRecords.isEmpty
                                  ? _StockHistoryFilterEmptyView(
                                    filter: _selectedFilter,
                                  )
                                  : _StockHistoryListView(
                                    records: visibleRecords,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StockHistoryHeaderCard extends StatelessWidget {
  final String itemName;
  final String itemSku;
  final double currentQuantity;

  const _StockHistoryHeaderCard({
    required this.itemName,
    required this.itemSku,
    required this.currentQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final qtyStr = InventoryDisplayFormatters.formatQuantity(currentQuantity);

    return Card(
      key: const Key('stock_history_header_card'),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 450;
            final itemDetails = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  itemName,
                  key: const Key('stock_history_item_name'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SKU: $itemSku',
                  key: const Key('stock_history_item_sku'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );

            final quantityBox = Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment:
                    isSmall ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CURRENT BALANCE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    qtyStr,
                    key: const Key('stock_history_item_current_quantity'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );

            if (isSmall) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  itemDetails,
                  const SizedBox(height: 12),
                  quantityBox,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: itemDetails),
                const SizedBox(width: 12),
                quantityBox,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StockHistoryEmptyView extends StatelessWidget {
  const _StockHistoryEmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
        child: Column(
          key: const Key('stock_history_empty_view'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No stock movements recorded yet.',
              key: const Key('stock_history_empty_message'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Movements will appear here once opening stock or adjustments are recorded.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StockHistoryFilterEmptyView extends StatelessWidget {
  final StockMovementFilter filter;

  const _StockHistoryFilterEmptyView({required this.filter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final message = switch (filter) {
      StockMovementFilter.openingStock => 'No opening stock movements found.',
      StockMovementFilter.adjustment => 'No adjustment movements found.',
      StockMovementFilter.all => 'No stock movements recorded yet.',
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
        child: Column(
          key: const Key('stock_history_filter_empty_view'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              key: const Key('stock_history_filter_empty_message'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Switch to "All Movements" or choose a different filter to view other records.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StockHistoryListView extends StatelessWidget {
  final List<StockMovementRecord> records;

  const _StockHistoryListView({required this.records});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('stock_history_list'),
      itemCount: records.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = records[index];
        return _StockMovementCard(record: record);
      },
    );
  }
}

class _StockMovementCard extends StatelessWidget {
  final StockMovementRecord record;

  const _StockMovementCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final movement = record.movement;

    final isOpening = movement.type == StockMovementType.openingStock;
    final typeLabel = isOpening ? 'Opening Stock' : 'Adjustment';

    final delta = movement.quantityDelta;
    final deltaStr = InventoryDisplayFormatters.formatSignedQuantity(delta);

    final Color deltaColor;
    if (delta > 0) {
      deltaColor =
          theme.brightness == Brightness.dark
              ? Colors.greenAccent.shade200
              : Colors.green.shade700;
    } else if (delta < 0) {
      deltaColor = colorScheme.error;
    } else {
      deltaColor = colorScheme.onSurfaceVariant;
    }

    final balanceStr = InventoryDisplayFormatters.formatQuantity(
      record.runningBalance,
    );
    final dateStr = InventoryDisplayFormatters.formatDateTime(
      movement.createdAt,
    );
    final actorStr = movement.performedByUserId ?? 'Not recorded';
    final reasonStr =
        movement.reason != null && movement.reason!.trim().isNotEmpty
            ? movement.reason!
            : '—';

    return Card(
      key: Key('stock_movement_card_${movement.id}'),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Type badge and Delta
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isOpening
                              ? colorScheme.secondaryContainer
                              : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      typeLabel,
                      key: Key('movement_type_${movement.id}'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color:
                            isOpening
                                ? colorScheme.onSecondaryContainer
                                : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  deltaStr,
                  key: Key('movement_delta_${movement.id}'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: deltaColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Balance and Timestamp
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Balance: $balanceStr',
                  key: Key('movement_running_balance_${movement.id}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  dateStr,
                  key: Key('movement_timestamp_${movement.id}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Row 3: Actor
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    actorStr,
                    key: Key('movement_actor_${movement.id}'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Row 4: Reason
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notes_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    reasonStr,
                    key: Key('movement_reason_${movement.id}'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
