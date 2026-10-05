import 'custom_field_definition.dart';
import 'inventory_item_summary.dart';

/// Specification and value extraction engine for all exportable Inventory columns.
abstract final class InventoryExportFields {
  /// The frozen three-column legacy headers.
  static const List<String> legacyHeaders = [
    'Item Name',
    'SKU',
    'Current Quantity',
  ];

  /// Canonical keys for the legacy three-column preset.
  static const List<String> legacyKeys = [
    'product_name',
    'sku',
    'current_quantity',
  ];

  /// All 21 standard field keys in canonical order.
  static const List<String> standardFieldKeys = [
    'sku',
    'product_name',
    'category',
    'brand',
    'unit',
    'barcode',
    'warehouse',
    'bin_location',
    'supplier',
    'unit_cost_inr',
    'selling_price_inr',
    'current_quantity',
    'reorder_level',
    'max_stock',
    'gst_percent',
    'batch_number',
    'expiry_date',
    'last_restocked_date',
    'is_active',
    'stock_status',
    'notes',
  ];

  /// Resolves the human-readable header label for a column [key].
  static String getHeaderLabel(
    String key, {
    List<CustomFieldDefinition>? customFieldDefinitions,
    bool isLegacy = false,
  }) {
    final normalized = key.trim().toLowerCase();
    if (isLegacy) {
      if (normalized == 'product_name' || normalized == 'name' || key == 'Item Name') {
        return 'Item Name';
      }
      if (normalized == 'sku' || key == 'SKU') {
        return 'SKU';
      }
      if (normalized == 'current_quantity' ||
          normalized == 'stock_quantity' ||
          key == 'Current Quantity') {
        return 'Current Quantity';
      }
    }

    switch (normalized) {
      case 'sku':
        return 'SKU';
      case 'product_name':
      case 'name':
      case 'item name':
        return isLegacy ? 'Item Name' : 'Product Name';
      case 'category':
        return 'Category';
      case 'brand':
        return 'Brand';
      case 'unit':
      case 'unit_of_measure':
      case 'unit of measure':
        return 'Unit';
      case 'barcode':
        return 'Barcode';
      case 'warehouse':
        return 'Warehouse';
      case 'bin_location':
      case 'bin location':
        return 'Bin Location';
      case 'supplier':
        return 'Supplier';
      case 'unit_cost_inr':
      case 'unit_cost':
      case 'cost':
      case 'unit cost (inr)':
        return 'Unit Cost (INR)';
      case 'selling_price_inr':
      case 'selling_price':
      case 'price':
      case 'selling price (inr)':
        return 'Selling Price (INR)';
      case 'current_quantity':
      case 'stock_quantity':
      case 'quantity':
      case 'current quantity':
        return 'Current Quantity';
      case 'reorder_level':
      case 'reorder level':
        return 'Reorder Level';
      case 'max_stock':
      case 'maximum_stock':
      case 'max stock':
      case 'maximum stock':
        return 'Maximum Stock';
      case 'gst_percent':
      case 'gst':
      case 'gst (%)':
        return 'GST (%)';
      case 'batch_number':
      case 'batch':
      case 'batch number':
        return 'Batch Number';
      case 'expiry_date':
      case 'expiry date':
        return 'Expiry Date';
      case 'last_restocked_date':
      case 'last restocked date':
        return 'Last Restocked Date';
      case 'is_active':
      case 'is active':
        return 'Is Active';
      case 'stock_status':
      case 'expected_stock_status':
      case 'stock status':
        return 'Stock Status';
      case 'notes':
        return 'Notes';
    }

    if (customFieldDefinitions != null) {
      for (final def in customFieldDefinitions) {
        if (def.key.toLowerCase() == normalized || def.label.toLowerCase() == normalized) {
          return def.label;
        }
      }
    }

    return key;
  }

  /// Normalizes a column [key] to its canonical form or custom field key.
  static String normalizeKey(String key) {
    final lower = key.trim().toLowerCase();
    switch (lower) {
      case 'name':
      case 'item name':
        return 'product_name';
      case 'stock_quantity':
      case 'quantity':
      case 'current quantity':
        return 'current_quantity';
      case 'unit_cost':
      case 'cost':
      case 'unit cost (inr)':
        return 'unit_cost_inr';
      case 'selling_price':
      case 'price':
      case 'selling price (inr)':
        return 'selling_price_inr';
      case 'unit_of_measure':
      case 'unit of measure':
        return 'unit';
      case 'bin location':
        return 'bin_location';
      case 'reorder level':
        return 'reorder_level';
      case 'max stock':
      case 'maximum stock':
      case 'maximum_stock':
        return 'max_stock';
      case 'gst':
      case 'gst (%)':
        return 'gst_percent';
      case 'batch':
      case 'batch number':
        return 'batch_number';
      case 'expiry date':
        return 'expiry_date';
      case 'last restocked date':
        return 'last_restocked_date';
      case 'is active':
        return 'is_active';
      case 'expected_stock_status':
      case 'stock status':
        return 'stock_status';
      default:
        return lower;
    }
  }

  /// Validates whether [key] is recognized as a standard or registered custom field.
  static bool isValidKey(
    String key, {
    List<CustomFieldDefinition>? customFieldDefinitions,
  }) {
    final norm = normalizeKey(key);
    if (standardFieldKeys.contains(norm)) return true;

    if (customFieldDefinitions != null) {
      for (final def in customFieldDefinitions) {
        if (def.key.toLowerCase() == norm || def.label.toLowerCase() == norm) {
          return true;
        }
      }
    }
    return false;
  }

  /// Extracts the typed value of [key] from an [InventoryItemSummary].
  static Object? extractValue(
    InventoryItemSummary summary,
    String key, {
    List<CustomFieldDefinition>? customFieldDefinitions,
  }) {
    final norm = normalizeKey(key);
    final item = summary.item;

    switch (norm) {
      case 'sku':
        return item.sku;
      case 'product_name':
        return item.name;
      case 'category':
        return item.category;
      case 'brand':
        return item.brand;
      case 'unit':
        return item.unit;
      case 'barcode':
        return item.barcode;
      case 'warehouse':
        return item.warehouse;
      case 'bin_location':
        return item.binLocation;
      case 'supplier':
        return item.supplier;
      case 'unit_cost_inr':
        return item.unitCostInr;
      case 'selling_price_inr':
        return item.sellingPriceInr;
      case 'current_quantity':
        return summary.quantityOnHand;
      case 'reorder_level':
        return item.reorderLevel;
      case 'max_stock':
        return item.maxStock;
      case 'gst_percent':
        return item.gstPercent;
      case 'batch_number':
        return item.batchNumber;
      case 'expiry_date':
        return item.expiryDate;
      case 'last_restocked_date':
        return item.lastRestockedDate;
      case 'is_active':
        return item.isActive;
      case 'stock_status':
        return summary.stockStatus.displayName;
      case 'notes':
        return item.notes;
    }

    // Custom field resolution
    if (item.customFields.containsKey(key)) {
      return item.customFields[key];
    }
    if (item.customFields.containsKey(norm)) {
      return item.customFields[norm];
    }
    if (customFieldDefinitions != null) {
      for (final def in customFieldDefinitions) {
        if (def.key.toLowerCase() == norm || def.label.toLowerCase() == norm) {
          return item.customFields[def.key];
        }
      }
    }

    return null;
  }

  /// Neutralizes potential spreadsheet formula injection triggers (=, +, -, @).
  static String neutralizeFormula(String input) {
    if (input.isEmpty) return input;
    final trimmedLeading = input.trimLeft();
    if (trimmedLeading.isEmpty) return input;
    final firstChar = trimmedLeading[0];
    if (firstChar == '=' || firstChar == '+' || firstChar == '-' || firstChar == '@') {
      return "'$input";
    }
    return input;
  }

  /// Formats date to ISO-8601 YYYY-MM-DD.
  static String formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Formats quantity as a clean numeric string preserving decimals without trailing zeroes.
  static String formatQuantity(double quantity) {
    if (quantity == quantity.toInt()) {
      return quantity.toInt().toString();
    }
    return quantity.toString();
  }
}
