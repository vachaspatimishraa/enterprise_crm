/// Configurable catalogs for standard taxonomy: Categories, Units of Measure, and Warehouses.
///
/// Designed to support dynamic extension by authorized users while preserving legacy defaults.
class InventoryCatalogs {
  final Set<String> _categories;
  final Set<String> _units;
  final Set<String> _warehouses;

  InventoryCatalogs({
    Set<String>? categories,
    Set<String>? units,
    Set<String>? warehouses,
  })  : _categories = categories != null ? Set.from(categories) : _defaultCategories(),
        _units = units != null ? Set.from(units) : _defaultUnits(),
        _warehouses = warehouses != null ? Set.from(warehouses) : _defaultWarehouses();

  /// Default categories including the legacy default ('General') and the 9 seed workbook categories.
  static Set<String> _defaultCategories() => {
        'General',
        'Cleaning',
        'Electronics',
        'IT Accessories',
        'Maintenance',
        'Office Furniture',
        'Packaging',
        'Pantry',
        'Safety',
        'Stationery',
      };

  /// Default units of measure including the legacy default ('piece') and the 11 seed workbook units.
  static Set<String> _defaultUnits() => {
        'piece',
        'bag',
        'bottle',
        'box',
        'case',
        'jar',
        'kit',
        'pack',
        'ream',
        'roll',
        'set',
      };

  /// Default warehouses including the legacy default ('Default') and the 3 seed workbook facilities.
  static Set<String> _defaultWarehouses() => {
        'Default',
        'BLR-01',
        'DEL-01',
        'MUM-01',
      };

  Set<String> get categories => Set.unmodifiable(_categories);
  Set<String> get units => Set.unmodifiable(_units);
  Set<String> get warehouses => Set.unmodifiable(_warehouses);

  bool isValidCategory(String category) {
    final trimmed = category.trim().toLowerCase();
    return _categories.any((c) => c.toLowerCase() == trimmed);
  }

  bool isValidUnit(String unit) {
    final trimmed = unit.trim().toLowerCase();
    return _units.any((u) => u.toLowerCase() == trimmed);
  }

  bool isValidWarehouse(String warehouse) {
    final trimmed = warehouse.trim().toLowerCase();
    return _warehouses.any((w) => w.toLowerCase() == trimmed);
  }

  void registerCategory(String category) {
    final trimmed = category.trim();
    if (trimmed.isNotEmpty) {
      _categories.add(trimmed);
    }
  }

  void registerUnit(String unit) {
    final trimmed = unit.trim();
    if (trimmed.isNotEmpty) {
      _units.add(trimmed);
    }
  }

  void registerWarehouse(String warehouse) {
    final trimmed = warehouse.trim();
    if (trimmed.isNotEmpty) {
      _warehouses.add(trimmed);
    }
  }
}
