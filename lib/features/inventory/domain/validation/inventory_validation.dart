import '../entities/inventory_catalogs.dart';
import '../exceptions/inventory_exception.dart';

/// Centralized domain validation logic for standard inventory fields.
///
/// Implements validation checks aligned with INVENTORY-7.1 and the 16 Invalid_Examples cases.
abstract final class InventoryValidation {
  /// Validates SKU (INV-001, INV-016).
  ///
  /// Rejects blank/whitespace SKUs. Preserves exact text formatting including leading zeros.
  static String validateSku(String sku) {
    final trimmed = sku.trim();
    if (trimmed.isEmpty) {
      throw const InventoryValidationException('Item SKU cannot be blank.');
    }
    if (trimmed.length > 64) {
      throw const InventoryValidationException(
        'Item SKU cannot exceed 64 characters.',
      );
    }
    return trimmed;
  }

  /// Validates Product Name (INV-009).
  static String validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const InventoryValidationException('Item name cannot be blank.');
    }
    if (trimmed.length > 255) {
      throw const InventoryValidationException(
        'Item name cannot exceed 255 characters.',
      );
    }
    return trimmed;
  }

  /// Validates Category against [catalogs] (INV-008).
  static String validateCategory(String category, InventoryCatalogs catalogs) {
    final trimmed = category.trim();
    if (trimmed.isEmpty) {
      throw const InventoryValidationException('Category cannot be blank.');
    }
    if (!catalogs.isValidCategory(trimmed)) {
      throw InventoryValidationException(
        'Category "$trimmed" is not recognized in the configured catalog.',
      );
    }
    return trimmed;
  }

  /// Validates Unit of Measure against [catalogs].
  static String validateUnit(String unit, InventoryCatalogs catalogs) {
    final trimmed = unit.trim();
    if (trimmed.isEmpty) {
      throw const InventoryValidationException('Unit cannot be blank.');
    }
    if (!catalogs.isValidUnit(trimmed)) {
      throw InventoryValidationException(
        'Unit "$trimmed" is not recognized in the configured catalog.',
      );
    }
    return trimmed;
  }

  /// Validates Warehouse against [catalogs] (INV-007).
  static String validateWarehouse(String warehouse, InventoryCatalogs catalogs) {
    final trimmed = warehouse.trim();
    if (trimmed.isEmpty) {
      throw const InventoryValidationException('Warehouse cannot be blank.');
    }
    if (!catalogs.isValidWarehouse(trimmed)) {
      throw InventoryValidationException(
        'Warehouse "$trimmed" is not recognized in the configured catalog.',
      );
    }
    return trimmed;
  }

  /// Validates Barcode if provided (INV-005, INV-016).
  ///
  /// Preserves leading zeros as string. Rejects invalid formats if enabled.
  static String? validateBarcode(String? barcode) {
    if (barcode == null) return null;
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;

    // Check if alphanumeric barcode is safe, or if strictly digits
    // If standard 13-digit EAN-13, ensure digits only
    if (trimmed.length == 13) {
      final isDigits = RegExp(r'^\d{13}$').hasMatch(trimmed);
      if (!isDigits) {
        throw InventoryValidationException(
          '13-character barcode "$trimmed" must consist of numeric digits only.',
        );
      }
    }
    return trimmed;
  }

  /// Validates Unit Cost (INR) (INV-004).
  static double? validateUnitCost(double? cost) {
    if (cost == null) return null;
    if (!cost.isFinite) {
      throw const InventoryValidationException('Unit cost must be a finite number.');
    }
    if (cost < 0.0) {
      throw const InventoryValidationException('Unit cost cannot be below zero.');
    }
    return cost;
  }

  /// Validates Selling Price (INR).
  static double? validateSellingPrice(double? price) {
    if (price == null) return null;
    if (!price.isFinite) {
      throw const InventoryValidationException('Selling price must be a finite number.');
    }
    if (price < 0.0) {
      throw const InventoryValidationException('Selling price cannot be below zero.');
    }
    return price;
  }

  /// Validates Reorder Level (INV-012).
  static double? validateReorderLevel(double? reorderLevel) {
    if (reorderLevel == null) return null;
    if (!reorderLevel.isFinite) {
      throw const InventoryValidationException('Reorder level must be a finite number.');
    }
    if (reorderLevel < 0.0) {
      throw const InventoryValidationException('Reorder level cannot be negative.');
    }
    return reorderLevel;
  }

  /// Validates Max Stock relative to Reorder Level (INV-013).
  static double? validateMaxStock(double? maxStock, double? reorderLevel) {
    if (maxStock == null) return null;
    if (!maxStock.isFinite) {
      throw const InventoryValidationException('Max stock must be a finite number.');
    }
    if (maxStock < 0.0) {
      throw const InventoryValidationException('Max stock cannot be negative.');
    }
    if (reorderLevel != null && maxStock < reorderLevel) {
      throw InventoryValidationException(
        'Max stock ($maxStock) cannot be lower than reorder level ($reorderLevel).',
      );
    }
    return maxStock;
  }

  /// Validates GST percentage.
  static double? validateGstPercent(double? gst) {
    if (gst == null) return null;
    if (!gst.isFinite) {
      throw const InventoryValidationException('GST percent must be a finite number.');
    }
    if (gst < 0.0 || gst > 100.0) {
      throw const InventoryValidationException(
        'GST percent must be between 0.0 and 100.0.',
      );
    }
    return gst;
  }

  /// Validates Notes.
  static String? validateNotes(String? notes) {
    if (notes == null) return null;
    final trimmed = notes.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > 1000) {
      throw const InventoryValidationException(
        'Notes cannot exceed 1000 characters.',
      );
    }
    return trimmed;
  }
}
