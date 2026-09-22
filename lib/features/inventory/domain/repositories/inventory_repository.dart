import '../entities/inventory_item_summary.dart';
import '../entities/inventory_page.dart';
import '../entities/inventory_query.dart';
import '../entities/inventory_stock_mutation_result.dart';
import '../inputs/adjust_inventory_stock_input.dart';
import '../inputs/create_inventory_item_input.dart';
import '../inputs/record_opening_stock_input.dart';
import '../inputs/update_inventory_item_input.dart';

/// Repository interface for the Inventory module.
///
/// Supports paginated item reads, item details, administrative item identity management,
/// and append-only stock movement ledger mutations (opening stock and manual adjustments).
/// Direct quantity editing remains strictly prohibited.
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

  /// Checks whether any stock movements exist for [itemId].
  ///
  /// Throws an exception if the item does not exist.
  Future<bool> hasStockMovements(String itemId);

  /// Records opening stock for an uninitialized item (0 existing movements).
  ///
  /// Appends exactly one `StockMovementType.openingStock` movement and returns
  /// the mutation result with updated derived quantity.
  Future<InventoryStockMutationResult> recordOpeningStock(
    RecordOpeningStockInput input,
  );

  /// Records a manual stock adjustment for an initialized item (1+ existing movements).
  ///
  /// Appends exactly one `StockMovementType.adjustment` movement and returns
  /// the mutation result with updated derived quantity.
  Future<InventoryStockMutationResult> adjustStock(
    AdjustInventoryStockInput input,
  );
}
