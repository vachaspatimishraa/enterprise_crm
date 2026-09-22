import '../entities/inventory_item_summary.dart';
import '../entities/inventory_page.dart';
import '../entities/inventory_query.dart';
import '../inputs/create_inventory_item_input.dart';
import '../inputs/update_inventory_item_input.dart';

/// Repository interface for the Inventory module.
///
/// Supports paginated item reads, item details, and administrative creation and editing of item identity.
/// Stock mutation and direct quantity editing remain strictly prohibited.
abstract interface class InventoryRepository {
  /// Retrieves a paginated list of inventory item summaries matching [query].
  Future<InventoryPage> getItems(InventoryQuery query);

  /// Retrieves a single inventory item summary by [id], or `null` if not found.
  Future<InventoryItemSummary?> getItemById(String id);

  /// Creates a new inventory item.
  ///
  /// Generated item has derived quantity = 0 without creating stock movements.
  Future<InventoryItemSummary> createItem(CreateInventoryItemInput input);

  /// Updates an existing inventory item's identity ([name], [sku]).
  ///
  /// Existing item id, stock movements, and derived quantity are strictly preserved.
  Future<InventoryItemSummary> updateItem(UpdateInventoryItemInput input);
}
