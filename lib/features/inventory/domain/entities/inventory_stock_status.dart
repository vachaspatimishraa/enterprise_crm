/// Approved stock status enumeration derived dynamically from on-hand stock and thresholds.
///
/// Invariant: Stock status is NEVER stored as a mutable field on `InventoryItem`.
/// It is computed dynamically from `isActive`, `quantityOnHand`, `reorderLevel`, and `maxStock`.
enum InventoryStockStatus {
  discontinued,
  outOfStock,
  lowStock,
  overstock,
  inStock;

  /// Computes the active stock status using the approved precedence rules:
  /// 1. If not [isActive] -> [discontinued].
  /// 2. Else if [quantityOnHand] <= 0 -> [outOfStock].
  /// 3. Else if [reorderLevel] is defined and [quantityOnHand] <= [reorderLevel] -> [lowStock].
  /// 4. Else if [maxStock] is defined and [quantityOnHand] > [maxStock] -> [overstock].
  /// 5. Otherwise -> [inStock].
  static InventoryStockStatus compute({
    required bool isActive,
    required double quantityOnHand,
    double? reorderLevel,
    double? maxStock,
  }) {
    if (!isActive) {
      return InventoryStockStatus.discontinued;
    }
    if (quantityOnHand <= 0) {
      return InventoryStockStatus.outOfStock;
    }
    if (reorderLevel != null && quantityOnHand <= reorderLevel) {
      return InventoryStockStatus.lowStock;
    }
    if (maxStock != null && quantityOnHand > maxStock) {
      return InventoryStockStatus.overstock;
    }
    return InventoryStockStatus.inStock;
  }

  /// Machine name matching the mock test workbook schema (e.g. `OUT_OF_STOCK`).
  String get workbookKey {
    switch (this) {
      case InventoryStockStatus.discontinued:
        return 'DISCONTINUED';
      case InventoryStockStatus.outOfStock:
        return 'OUT_OF_STOCK';
      case InventoryStockStatus.lowStock:
        return 'LOW_STOCK';
      case InventoryStockStatus.overstock:
        return 'OVERSTOCK';
      case InventoryStockStatus.inStock:
        return 'IN_STOCK';
    }
  }

  /// Human-readable label for UI display.
  String get displayName {
    switch (this) {
      case InventoryStockStatus.discontinued:
        return 'Discontinued';
      case InventoryStockStatus.outOfStock:
        return 'Out of Stock';
      case InventoryStockStatus.lowStock:
        return 'Low Stock';
      case InventoryStockStatus.overstock:
        return 'Overstock';
      case InventoryStockStatus.inStock:
        return 'In Stock';
    }
  }
}
