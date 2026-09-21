/// Sorting options supported by the Inventory module in INVENTORY-1.
enum InventorySort {
  nameAsc,
  nameDesc,
  skuAsc,
  skuDesc;

  String get displayName {
    switch (this) {
      case InventorySort.nameAsc:
        return 'Name A-Z';
      case InventorySort.nameDesc:
        return 'Name Z-A';
      case InventorySort.skuAsc:
        return 'SKU A-Z';
      case InventorySort.skuDesc:
        return 'SKU Z-A';
    }
  }
}
