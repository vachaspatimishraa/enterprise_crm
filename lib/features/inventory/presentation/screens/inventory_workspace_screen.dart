import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/entities/inventory_stock_status.dart';
import '../../domain/entities/inventory_sort.dart';
import '../../domain/entities/pending_inventory_deletion.dart';
import '../../domain/policies/inventory_deletion_policy.dart';
import '../../domain/policies/inventory_import_policy.dart';
import '../../domain/policies/inventory_item_administration_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/inventory_cubit.dart';
import '../bloc/inventory_state.dart';
import '../utils/inventory_display_formatters.dart';
import '../widgets/inventory_pagination_controls.dart';
import '../../domain/policies/inventory_export_policy.dart';
import '../widgets/inventory_export_dialog.dart';
import 'create_inventory_item_screen.dart';
import 'inventory_bulk_entry_screen.dart';
import 'inventory_import_screen.dart';
import 'inventory_item_details_screen.dart';

/// Workspace and item list screen for the Inventory module.
///
/// Enforces module assignment and `inventory.view` authorization as a pre-Cubit guard.
/// Provides read-only search, sort, pagination, and responsive mobile/desktop layouts.
class InventoryWorkspaceScreen extends StatelessWidget {
  final CurrentUser user;
  final InventoryRepository repository;
  final CurrentUser? Function()? currentUserProvider;

  const InventoryWorkspaceScreen({
    super.key,
    required this.user,
    required this.repository,
    this.currentUserProvider,
  });

  @override
  Widget build(BuildContext context) {
    // Pre-Cubit production guard: zero Cubit initialization if unauthorized.
    final isAuthorized =
        AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView);

    if (!isAuthorized) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider<InventoryCubit>(
      create: (_) => InventoryCubit(repository)..loadItems(),
      child: _InventoryWorkspaceView(
        user: user,
        repository: repository,
        currentUserProvider: currentUserProvider,
      ),
    );
  }
}

class _InventoryWorkspaceView extends StatefulWidget {
  final CurrentUser user;
  final InventoryRepository repository;
  final CurrentUser? Function()? currentUserProvider;

  const _InventoryWorkspaceView({
    required this.user,
    required this.repository,
    this.currentUserProvider,
  });

  @override
  State<_InventoryWorkspaceView> createState() =>
      _InventoryWorkspaceViewState();
}

class _InventoryWorkspaceViewState extends State<_InventoryWorkspaceView> {
  final TextEditingController _searchController = TextEditingController();
  List<PendingInventoryDeletion> _pendingDeletions = [];
  final Set<String> _selectedItemIds = <String>{};
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPendingDeletions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingDeletions() async {
    try {
      final pending = await widget.repository.getPendingDeletions();
      if (mounted) {
        setState(() {
          _pendingDeletions = pending;
        });
      }
    } catch (_) {
      // Graceful fallback
    }
  }

  Future<void> _undoPendingDeletion(String itemId) async {
    try {
      await widget.repository.undoItemDeletion(
        itemId: itemId,
        performedByUserId: widget.user.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item deletion undone successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadPendingDeletions();
      if (mounted) {
        context.read<InventoryCubit>().refresh();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openCreateItem(BuildContext context) async {
    final cubit = context.read<InventoryCubit>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateInventoryItemScreen(
          user: widget.user,
          repository: widget.repository,
        ),
      ),
    );
    if (created == true && mounted) {
      _loadPendingDeletions();
      cubit.refresh();
    }
  }

  void _openBulkEntry(BuildContext context) async {
    final cubit = context.read<InventoryCubit>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InventoryBulkEntryScreen(
          user: widget.user,
          repository: widget.repository,
        ),
      ),
    );
    if (created == true && mounted) {
      _loadPendingDeletions();
      cubit.refresh();
    }
  }

  CurrentUser? _resolveCurrentUser([BuildContext? contextOverride]) {
    if (widget.currentUserProvider != null) {
      try {
        return widget.currentUserProvider!();
      } catch (_) {
        return null;
      }
    }
    final ctx = contextOverride ?? context;
    try {
      final authCubit = ctx.read<AuthCubit?>();
      if (authCubit != null) {
        final authState = authCubit.state;
        if (authState is AuthAuthenticated) {
          return authState.user;
        }
      }
    } catch (_) {}
    return null;
  }

  CurrentUser? _watchCurrentUser(BuildContext context) {
    try {
      context.watch<AuthCubit?>();
    } catch (_) {}

    if (widget.currentUserProvider != null) {
      try {
        return widget.currentUserProvider!();
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
      }
    } catch (_) {}
    return null;
  }

  void _openExport(BuildContext context) {
    final liveUser = _resolveCurrentUser(context);
    if (liveUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User session expired or unauthenticated.'),
        ),
      );
      return;
    }
    final cubit = context.read<InventoryCubit?>();
    showInventoryExportDialog(
      context: context,
      user: liveUser,
      repository: widget.repository,
      currentUserProvider: _resolveCurrentUser,
      currentQuery: cubit?.state.query,
      selectedItemIds: Set<String>.unmodifiable(_selectedItemIds),
    );
  }

  void _openImport(BuildContext context) async {
    final cubit = context.read<InventoryCubit>();
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InventoryImportScreen(
          user: widget.user,
          repository: widget.repository,
        ),
      ),
    );
    if (imported == true && mounted) {
      _loadPendingDeletions();
      cubit.refresh();
    }
  }

  void _openDetails(BuildContext context, String itemId) async {
    final cubit = context.read<InventoryCubit>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventoryItemDetailsScreen(
          user: widget.user,
          repository: widget.repository,
          itemId: itemId,
        ),
      ),
    );
    if (mounted) {
      _loadPendingDeletions();
      cubit.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        leading: IconButton(
          key: const Key('inventory_workspace_back_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (InventoryItemAdministrationPolicy.canCreate(widget.user))
            IconButton(
              key: const Key('inventory_workspace_bulk_entry_appbar_button'),
              icon: const Icon(Icons.table_rows_outlined),
              tooltip: 'Bulk Entry',
              onPressed: () => _openBulkEntry(context),
            ),
          IconButton(
            key: const Key('inventory_refresh_button'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _loadPendingDeletions();
              context.read<InventoryCubit>().refresh();
            },
          ),
        ],
      ),
      body: BlocBuilder<InventoryCubit, InventoryState>(
        builder: (context, state) {
          return Column(
            children: [
              // Pending Deletions Banner if any
              if (_pendingDeletions.isNotEmpty)
                _buildPendingDeletionsBanner(context),

              // Search and Sort Control Bar
              _buildControlBar(context, state),
              const Divider(height: 1),

              // Main Content Area
              Expanded(child: _buildContent(context, state)),

              // Pagination Controls Footer
              if (state is InventoryLoaded)
                InventoryPaginationControls(
                  currentPage: state.page.currentPage,
                  pageSize: state.page.pageSize,
                  totalItems: state.page.totalItems,
                  hasNext: state.page.hasNext,
                  onPrevious: () =>
                      context.read<InventoryCubit>().previousPage(),
                  onNext: () => context.read<InventoryCubit>().nextPage(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingDeletionsBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('inventory_workspace_pending_deletions_banner'),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_top, size: 20, color: colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'Pending Deletions (${_pendingDeletions.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._pendingDeletions.map((pending) {
            final now = DateTime.now();
            final remainingSeconds = pending.undoDeadline.isAfter(now)
                ? pending.undoDeadline.difference(now).inSeconds
                : 0;
            final canUndo = InventoryDeletionPolicy.canUndo(
              widget.user,
              initiatedByUserId: pending.initiatedByUserId,
            );

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${pending.itemName} (${pending.itemSku}) - Undo expires in ${remainingSeconds}s',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (canUndo)
                    TextButton.icon(
                      key: Key(
                        'pending_deletion_undo_button_${pending.itemId}',
                      ),
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Undo'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _undoPendingDeletion(pending.itemId),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildControlBar(BuildContext context, InventoryState state) {
    final cubit = context.read<InventoryCubit>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 960;

          final searchWidget = TextField(
            key: const Key('inventory_search_field'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search name or SKU...',
              prefixIcon: IconButton(
                key: const Key('inventory_search_submit_button'),
                icon: const Icon(Icons.search, size: 20),
                onPressed: () => cubit.search(_searchController.text),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      key: const Key('inventory_clear_search_button'),
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        cubit.clearSearch();
                      },
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (text) {
              setState(() {});
              cubit.search(text);
            },
            onSubmitted: (text) => cubit.search(text),
          );

          final sortWidget = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<InventorySort>(
                key: const Key('inventory_sort_dropdown'),
                value: state.query.sort,
                isDense: true,
                items: InventorySort.values.map((sort) {
                  return DropdownMenuItem<InventorySort>(
                    value: sort,
                    child: Text(
                      sort.displayName,
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }).toList(),
                onChanged: (newSort) {
                  if (newSort != null) {
                    cubit.setSort(newSort);
                  }
                },
              ),
            ),
          );

          final canCreate = InventoryItemAdministrationPolicy.canCreate(
            widget.user,
          );
          final canImport = InventoryImportPolicy.canImport(widget.user);
          final liveUser = _watchCurrentUser(context);
          final canExport =
              liveUser != null && InventoryExportPolicy.canExport(liveUser);

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchWidget,
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sort by:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        sortWidget,
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (canExport)
                          OutlinedButton.icon(
                            key: const Key('inventory_workspace_export_button'),
                            onPressed: () => _openExport(context),
                            icon: const Icon(Icons.download_outlined, size: 18),
                            label: const Text('Export'),
                          ),
                        if (canImport)
                          OutlinedButton.icon(
                            key: const Key('inventory_workspace_import_button'),
                            onPressed: () => _openImport(context),
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Import'),
                          ),
                        if (canCreate)
                          FilledButton.icon(
                            key: const Key(
                              'inventory_workspace_add_item_button',
                            ),
                            onPressed: () => _openCreateItem(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Item'),
                          ),
                        if (canCreate)
                          OutlinedButton.icon(
                            key: const Key(
                              'inventory_workspace_bulk_entry_button',
                            ),
                            onPressed: () => _openBulkEntry(context),
                            icon: const Icon(
                              Icons.table_rows_outlined,
                              size: 18,
                            ),
                            label: const Text('Bulk Entry'),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchWidget),
              const SizedBox(width: 16),
              sortWidget,
              if (canExport) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  key: const Key('inventory_workspace_export_button'),
                  onPressed: () => _openExport(context),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Export'),
                ),
              ],
              if (canImport) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  key: const Key('inventory_workspace_import_button'),
                  onPressed: () => _openImport(context),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Import'),
                ),
              ],
              if (canCreate) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: const Key('inventory_workspace_add_item_button'),
                  onPressed: () => _openCreateItem(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Item'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, InventoryState state) {
    if (state is InventoryLoading || state is InventoryInitial) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('inventory_loading_indicator'),
        ),
      );
    }

    if (state is InventoryFailure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            key: const Key('inventory_failure_view'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                state.message,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('inventory_retry_button'),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () => context.read<InventoryCubit>().retry(),
              ),
            ],
          ),
        ),
      );
    }

    if (state is InventoryEmpty) {
      final isSearch = state.isSearchResult;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            key: Key(
              isSearch ? 'inventory_search_empty_view' : 'inventory_empty_view',
            ),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSearch ? Icons.search_off : Icons.inventory_2_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                isSearch
                    ? 'No matching inventory items found.'
                    : 'No inventory items found.',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (state is InventoryLoaded) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;

          if (isCompact) {
            return _buildMobileCardList(context, state.items);
          }

          return _buildDesktopDataTable(context, state);
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMobileCardList(
    BuildContext context,
    List<InventoryItemSummary> items,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView.separated(
      key: const Key('inventory_items_list'),
      padding: const EdgeInsets.all(16.0),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final summary = items[index];
        final item = summary.item;
        final qtyStr = InventoryDisplayFormatters.formatQuantity(
          summary.quantityOnHand,
        );

        return Card(
          key: Key('inventory_item_card_${item.id}'),
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SKU: ${item.sku}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Checkbox(
                      key: Key('inventory_item_select_${item.id}'),
                      value: _selectedItemIds.contains(item.id),
                      onChanged: (selected) => setState(() {
                        if (selected == true) {
                          _selectedItemIds.add(item.id);
                        } else {
                          _selectedItemIds.remove(item.id);
                        }
                      }),
                    ),
                    OutlinedButton(
                      key: Key('inventory_item_view_details_${item.id}'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      onPressed: () => _openDetails(context, item.id),
                      child: const Text('View Details'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: 'Quantity on hand: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: qtyStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopDataTable(
    BuildContext context,
    InventoryLoaded state,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final items = state.items;

    // Dataset-wide dynamic column visibility detection
    final hasCategory = items.any((s) => s.item.category.trim().isNotEmpty);
    final hasBrand = items.any((s) => s.item.brand?.trim().isNotEmpty == true);
    final hasUnit = items.any((s) => s.item.unit.trim().isNotEmpty);
    final hasBarcode = items.any((s) => s.item.barcode?.trim().isNotEmpty == true);
    final hasWarehouse = items.any((s) => s.item.warehouse.trim().isNotEmpty);
    final hasBinLocation = items.any((s) => s.item.binLocation?.trim().isNotEmpty == true);
    final hasSupplier = items.any((s) => s.item.supplier?.trim().isNotEmpty == true);
    final hasUnitCost = items.any((s) => s.item.unitCostInr != null);
    final hasSellingPrice = items.any((s) => s.item.sellingPriceInr != null);
    final hasQuantity = true;
    final hasReorderLevel = items.any((s) => s.item.reorderLevel != null);
    final hasMaxStock = items.any((s) => s.item.maxStock != null);
    final hasGst = items.any((s) => s.item.gstPercent != null);
    final hasBatchNumber = items.any((s) => s.item.batchNumber?.trim().isNotEmpty == true);
    final hasExpiryDate = items.any((s) => s.item.expiryDate != null);
    final hasLastRestocked = items.any((s) => s.item.lastRestockedDate != null);
    final hasStockStatus = true;
    final hasIsActive = items.isNotEmpty;
    final hasNotes = items.any((s) => s.item.notes?.trim().isNotEmpty == true);

    // Dynamic Custom Fields
    final customFieldKeys = <String>{};
    for (final s in items) {
      for (final entry in s.item.customFields.entries) {
        if (entry.value != null && entry.value.toString().trim().isNotEmpty) {
          customFieldKeys.add(entry.key);
        }
      }
    }
    final sortedCustomKeys = customFieldKeys.toList()..sort();

    const headerTextStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 13,
      letterSpacing: 0.3,
    );

    final columns = <DataColumn>[
      DataColumn(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              key: const Key('inventory_select_all_checkbox'),
              value: items.isNotEmpty && items.every((s) => _selectedItemIds.contains(s.item.id)),
              tristate: true,
              side: const BorderSide(color: Colors.white, width: 1.5),
              checkColor: const Color(0xFF1A365D),
              activeColor: Colors.white,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedItemIds.addAll(items.map((s) => s.item.id));
                  } else {
                    _selectedItemIds.removeAll(items.map((s) => s.item.id));
                  }
                });
              },
            ),
            const SizedBox(width: 4),
            const Text('#', style: headerTextStyle),
          ],
        ),
      ),
      const DataColumn(label: Text('Product Name', style: headerTextStyle)),
      const DataColumn(label: Text('SKU', style: headerTextStyle)),
      if (hasCategory) const DataColumn(label: Text('Category', style: headerTextStyle)),
      if (hasBrand) const DataColumn(label: Text('Brand', style: headerTextStyle)),
      if (hasUnit) const DataColumn(label: Text('Unit', style: headerTextStyle)),
      if (hasBarcode) const DataColumn(label: Text('Barcode', style: headerTextStyle)),
      if (hasWarehouse) const DataColumn(label: Text('Warehouse', style: headerTextStyle)),
      if (hasBinLocation) const DataColumn(label: Text('Bin Location', style: headerTextStyle)),
      if (hasSupplier) const DataColumn(label: Text('Supplier', style: headerTextStyle)),
      if (hasUnitCost) const DataColumn(label: Text('Unit Cost (₹)', style: headerTextStyle), numeric: true),
      if (hasSellingPrice) const DataColumn(label: Text('Selling Price (₹)', style: headerTextStyle), numeric: true),
      if (hasQuantity) const DataColumn(label: Text('Quantity', style: headerTextStyle), numeric: true),
      if (hasReorderLevel) const DataColumn(label: Text('Reorder Level', style: headerTextStyle), numeric: true),
      if (hasMaxStock) const DataColumn(label: Text('Max Stock', style: headerTextStyle), numeric: true),
      if (hasGst) const DataColumn(label: Text('GST (%)', style: headerTextStyle), numeric: true),
      if (hasBatchNumber) const DataColumn(label: Text('Batch Number', style: headerTextStyle)),
      if (hasExpiryDate) const DataColumn(label: Text('Expiry Date', style: headerTextStyle)),
      if (hasLastRestocked) const DataColumn(label: Text('Last Restocked', style: headerTextStyle)),
      if (hasIsActive) const DataColumn(label: Text('Active', style: headerTextStyle)),
      if (hasStockStatus) const DataColumn(label: Text('Status', style: headerTextStyle)),
      if (hasNotes) const DataColumn(label: Text('Notes', style: headerTextStyle)),
      for (final key in sortedCustomKeys)
        DataColumn(label: Text(_formatCustomHeader(key), style: headerTextStyle)),
      const DataColumn(label: Text('Actions', style: headerTextStyle)),
    ];

    final pageOffset = state.page.currentPage > 0
        ? (state.page.currentPage - 1) * state.page.pageSize
        : 0;

    final rows = List<DataRow>.generate(items.length, (i) {
      final summary = items[i];
      final item = summary.item;
      final rowNumber = pageOffset + i + 1;
      final isEven = i % 2 == 0;

      final cells = <DataCell>[
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                key: Key('inventory_item_select_${item.id}'),
                value: _selectedItemIds.contains(item.id),
                onChanged: (selected) => setState(() {
                  if (selected == true) {
                    _selectedItemIds.add(item.id);
                  } else {
                    _selectedItemIds.remove(item.id);
                  }
                }),
              ),
              const SizedBox(width: 4),
              Text(
                '$rowNumber',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            item.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
          onTap: () => _openDetails(context, item.id),
        ),
        DataCell(
          Text(
            item.sku,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          onTap: () => _openDetails(context, item.id),
        ),
        if (hasCategory)
          DataCell(
            Text(item.category.trim().isEmpty ? '—' : item.category),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasBrand)
          DataCell(
            Text(item.brand?.trim().isNotEmpty == true ? item.brand! : '—'),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasUnit)
          DataCell(
            Text(item.unit.trim().isEmpty ? '—' : item.unit),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasBarcode)
          DataCell(
            Text(item.barcode?.trim().isNotEmpty == true ? item.barcode! : '—'),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasWarehouse)
          DataCell(
            Text(item.warehouse.trim().isEmpty ? '—' : item.warehouse),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasBinLocation)
          DataCell(
            Text(item.binLocation?.trim().isNotEmpty == true ? item.binLocation! : '—'),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasSupplier)
          DataCell(
            Text(item.supplier?.trim().isNotEmpty == true ? item.supplier! : '—'),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasUnitCost)
          DataCell(
            Text(item.unitCostInr != null ? _formatCurrency(item.unitCostInr!) : '—'),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasSellingPrice)
          DataCell(
            Text(item.sellingPriceInr != null ? _formatCurrency(item.sellingPriceInr!) : '—'),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasQuantity)
          DataCell(
            Text(
              InventoryDisplayFormatters.formatQuantity(summary.quantityOnHand),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasReorderLevel)
          DataCell(
            Text(
              item.reorderLevel != null
                  ? InventoryDisplayFormatters.formatQuantity(item.reorderLevel!)
                  : '—',
            ),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasMaxStock)
          DataCell(
            Text(
              item.maxStock != null
                  ? InventoryDisplayFormatters.formatQuantity(item.maxStock!)
                  : '—',
            ),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasGst)
          DataCell(
            Text(
              item.gstPercent != null
                  ? '${item.gstPercent!.toStringAsFixed(item.gstPercent! % 1 == 0 ? 0 : 2)}%'
                  : '—',
            ),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasBatchNumber)
          DataCell(
            Text(item.batchNumber?.trim().isNotEmpty == true ? item.batchNumber! : '—'),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasExpiryDate)
          DataCell(
            Text(item.expiryDate != null ? _formatDate(item.expiryDate!) : '—'),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasLastRestocked)
          DataCell(
            Text(item.lastRestockedDate != null ? _formatDate(item.lastRestockedDate!) : '—'),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasIsActive)
          DataCell(
            Text(item.isActive ? 'Active' : 'Inactive'),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasStockStatus)
          DataCell(
            _buildStockStatusBadge(context, summary.stockStatus),
            onTap: () => _openDetails(context, item.id),
          ),
        if (hasNotes)
          DataCell(
            Text(item.notes?.trim().isNotEmpty == true ? item.notes! : '—'),
            onTap: () => _openDetails(context, item.id),
          ),
        for (final key in sortedCustomKeys)
          DataCell(
            Text(
              item.customFields[key]?.toString().trim().isNotEmpty == true
                  ? item.customFields[key].toString()
                  : '—',
            ),
            onTap: () => _openDetails(context, item.id),
          ),
        DataCell(
          OutlinedButton(
            key: Key('inventory_item_view_details_${item.id}'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _openDetails(context, item.id),
            child: const Text('View Details'),
          ),
        ),
      ];

      return DataRow(
        key: ValueKey('inventory_item_row_${item.id}'),
        color: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered)) {
            return colorScheme.primary.withValues(alpha: 0.05);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer.withValues(alpha: 0.2);
          }
          return isEven ? colorScheme.surface : colorScheme.surfaceContainerLowest;
        }),
        cells: cells,
      );
    });

    return Scrollbar(
      controller: _horizontalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: Scrollbar(
          controller: _verticalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _verticalScrollController,
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.all(16.0),
            child: DataTable(
              key: const Key('inventory_items_table'),
              headingRowColor: WidgetStateProperty.all(const Color(0xFF1A365D)),
              headingTextStyle: headerTextStyle,
              border: TableBorder.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 1,
                borderRadius: BorderRadius.circular(4),
              ),
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              columnSpacing: 24,
              horizontalMargin: 16,
              columns: columns,
              rows: rows,
            ),
          ),
        ),
      ),
    );
  }

  static String _formatCustomHeader(String key) {
    return key
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Widget _buildStockStatusBadge(
    BuildContext context,
    InventoryStockStatus status,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fg;
    final Color bg;
    switch (status) {
      case InventoryStockStatus.inStock:
        fg = isDark ? Colors.green.shade300 : Colors.green.shade800;
        bg = isDark
            ? Colors.green.shade900.withValues(alpha: 0.4)
            : Colors.green.shade50;
        break;
      case InventoryStockStatus.lowStock:
        fg = isDark ? Colors.orange.shade300 : Colors.orange.shade800;
        bg = isDark
            ? Colors.orange.shade900.withValues(alpha: 0.4)
            : Colors.orange.shade50;
        break;
      case InventoryStockStatus.outOfStock:
        fg = isDark ? Colors.red.shade300 : Colors.red.shade800;
        bg = isDark
            ? Colors.red.shade900.withValues(alpha: 0.4)
            : Colors.red.shade50;
        break;
      case InventoryStockStatus.overstock:
        fg = isDark ? Colors.blue.shade300 : Colors.blue.shade800;
        bg = isDark
            ? Colors.blue.shade900.withValues(alpha: 0.4)
            : Colors.blue.shade50;
        break;
      case InventoryStockStatus.discontinued:
        fg = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
        bg = isDark
            ? Colors.grey.shade800.withValues(alpha: 0.4)
            : Colors.grey.shade100;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
