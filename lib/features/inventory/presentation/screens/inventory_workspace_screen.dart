import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/entities/inventory_sort.dart';
import '../../domain/policies/inventory_item_administration_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/inventory_cubit.dart';
import '../bloc/inventory_state.dart';
import '../utils/inventory_display_formatters.dart';
import '../widgets/inventory_pagination_controls.dart';
import 'create_inventory_item_screen.dart';
import 'inventory_item_details_screen.dart';

/// Workspace and item list screen for the Inventory module.
///
/// Enforces module assignment and `inventory.view` authorization as a pre-Cubit guard.
/// Provides read-only search, sort, pagination, and responsive mobile/desktop layouts.
class InventoryWorkspaceScreen extends StatelessWidget {
  final CurrentUser user;
  final InventoryRepository repository;

  const InventoryWorkspaceScreen({
    super.key,
    required this.user,
    required this.repository,
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
      child: _InventoryWorkspaceView(user: user, repository: repository),
    );
  }
}

class _InventoryWorkspaceView extends StatefulWidget {
  final CurrentUser user;
  final InventoryRepository repository;

  const _InventoryWorkspaceView({required this.user, required this.repository});

  @override
  State<_InventoryWorkspaceView> createState() =>
      _InventoryWorkspaceViewState();
}

class _InventoryWorkspaceViewState extends State<_InventoryWorkspaceView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          IconButton(
            key: const Key('inventory_refresh_button'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<InventoryCubit>().refresh(),
          ),
        ],
      ),
      body: BlocBuilder<InventoryCubit, InventoryState>(
        builder: (context, state) {
          return Column(
            children: [
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

  Widget _buildControlBar(BuildContext context, InventoryState state) {
    final cubit = context.read<InventoryCubit>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;

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

          final canManage = InventoryItemAdministrationPolicy.canManage(
            widget.user,
          );

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
                    if (canManage)
                      FilledButton.icon(
                        key: const Key('inventory_workspace_add_item_button'),
                        onPressed: () => _openCreateItem(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Item'),
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
              if (canManage) ...[
                const SizedBox(width: 16),
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

          return _buildDesktopDataTable(context, state.items);
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
    List<InventoryItemSummary> items,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        padding: const EdgeInsets.all(16.0),
        child: DataTable(
          key: const Key('inventory_items_table'),
          headingRowColor: WidgetStateProperty.all(
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Quantity on hand'), numeric: true),
            DataColumn(label: Text('Actions')),
          ],
          rows: items.map((summary) {
            final item = summary.item;
            final qtyStr = InventoryDisplayFormatters.formatQuantity(
              summary.quantityOnHand,
            );

            return DataRow(
              key: ValueKey('inventory_item_row_${item.id}'),
              cells: [
                DataCell(
                  Text(
                    item.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => _openDetails(context, item.id),
                ),
                DataCell(
                  Text(
                    item.sku,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => _openDetails(context, item.id),
                ),
                DataCell(
                  Text(
                    qtyStr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
