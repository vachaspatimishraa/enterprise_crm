import '../entities/inventory_item_summary.dart';
import '../entities/inventory_page.dart';
import '../entities/inventory_query.dart';

/// Read-only repository interface for the Inventory module in INVENTORY-1.
///
/// Write operations and stock adjustments are strictly deferred to future phases.
abstract interface class InventoryRepository {
  /// Retrieves a paginated list of inventory item summaries matching [query].
  Future<InventoryPage> getItems(InventoryQuery query);

  /// Retrieves a single inventory item summary by [id], or `null` if not found.
  Future<InventoryItemSummary?> getItemById(String id);
}
