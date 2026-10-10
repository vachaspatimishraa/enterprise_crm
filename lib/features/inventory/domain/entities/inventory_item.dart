import 'package:flutter/foundation.dart';

const Object _sentinel = Object();

/// Pure domain entity representing an inventoried physical product or stock item.
///
/// Holds intrinsic identity, classification, logistics, financial pricing,
/// batch tracking, and user-defined custom attributes.
///
/// CRITICAL INVARIANT: Physical stock quantity is derived dynamically from
/// immutable stock movements and is intentionally NOT stored on this entity.
@immutable
class InventoryItem {
  final String id;
  final String name;
  final String sku;
  final String category;
  final String? brand;
  final String unit;
  final String? barcode;
  final String warehouse;
  final String? binLocation;
  final String? supplier;
  final double? unitCostInr;
  final double? sellingPriceInr;
  final double? reorderLevel;
  final double? maxStock;
  final double? gstPercent;
  final String? batchNumber;
  final DateTime? expiryDate;
  final DateTime? lastRestockedDate;
  final bool isActive;
  final String? notes;
  final Map<String, dynamic> customFields;

  InventoryItem({
    required this.id,
    required this.name,
    required this.sku,
    this.category = 'General',
    this.brand,
    this.unit = 'piece',
    this.barcode,
    this.warehouse = 'Default',
    this.binLocation,
    this.supplier,
    this.unitCostInr,
    this.sellingPriceInr,
    this.reorderLevel,
    this.maxStock,
    this.gstPercent,
    this.batchNumber,
    this.expiryDate,
    this.lastRestockedDate,
    this.isActive = true,
    this.notes,
    Map<String, dynamic> customFields = const {},
  }) : customFields = Map.unmodifiable(Map<String, dynamic>.from(customFields)) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Item ID cannot be blank.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Item name cannot be blank.');
    }
    if (sku.trim().isEmpty) {
      throw ArgumentError.value(sku, 'sku', 'Item SKU cannot be blank.');
    }
    if (category.trim().isEmpty) {
      throw ArgumentError.value(category, 'category', 'Category cannot be blank.');
    }
    if (unit.trim().isEmpty) {
      throw ArgumentError.value(unit, 'unit', 'Unit cannot be blank.');
    }
    if (warehouse.trim().isEmpty) {
      throw ArgumentError.value(warehouse, 'warehouse', 'Warehouse cannot be blank.');
    }
    if (unitCostInr != null && unitCostInr! < 0.0) {
      throw ArgumentError.value(unitCostInr, 'unitCostInr', 'Unit cost cannot be negative.');
    }
    if (sellingPriceInr != null && sellingPriceInr! < 0.0) {
      throw ArgumentError.value(sellingPriceInr, 'sellingPriceInr', 'Selling price cannot be negative.');
    }
    if (reorderLevel != null && reorderLevel! < 0.0) {
      throw ArgumentError.value(reorderLevel, 'reorderLevel', 'Reorder level cannot be negative.');
    }
    if (maxStock != null && maxStock! < 0.0) {
      throw ArgumentError.value(maxStock, 'maxStock', 'Max stock cannot be negative.');
    }
    if (reorderLevel != null && maxStock != null && maxStock! < reorderLevel!) {
      throw ArgumentError.value(
        maxStock,
        'maxStock',
        'Max stock ($maxStock) cannot be lower than reorder level ($reorderLevel).',
      );
    }
  }

  /// Creates a copy of this [InventoryItem] with the given fields replaced.
  ///
  /// Passing `null` to a nullable field explicitly resets/clears that field.
  /// Omitting a parameter preserves the existing value.
  InventoryItem copyWith({
    String? id,
    String? name,
    String? sku,
    String? category,
    Object? brand = _sentinel,
    String? unit,
    Object? barcode = _sentinel,
    String? warehouse,
    Object? binLocation = _sentinel,
    Object? supplier = _sentinel,
    Object? unitCostInr = _sentinel,
    Object? sellingPriceInr = _sentinel,
    Object? reorderLevel = _sentinel,
    Object? maxStock = _sentinel,
    Object? gstPercent = _sentinel,
    Object? batchNumber = _sentinel,
    Object? expiryDate = _sentinel,
    Object? lastRestockedDate = _sentinel,
    bool? isActive,
    Object? notes = _sentinel,
    Map<String, dynamic>? customFields,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      brand: identical(brand, _sentinel) ? this.brand : brand as String?,
      unit: unit ?? this.unit,
      barcode: identical(barcode, _sentinel) ? this.barcode : barcode as String?,
      warehouse: warehouse ?? this.warehouse,
      binLocation: identical(binLocation, _sentinel) ? this.binLocation : binLocation as String?,
      supplier: identical(supplier, _sentinel) ? this.supplier : supplier as String?,
      unitCostInr: identical(unitCostInr, _sentinel) ? this.unitCostInr : unitCostInr as double?,
      sellingPriceInr: identical(sellingPriceInr, _sentinel) ? this.sellingPriceInr : sellingPriceInr as double?,
      reorderLevel: identical(reorderLevel, _sentinel) ? this.reorderLevel : reorderLevel as double?,
      maxStock: identical(maxStock, _sentinel) ? this.maxStock : maxStock as double?,
      gstPercent: identical(gstPercent, _sentinel) ? this.gstPercent : gstPercent as double?,
      batchNumber: identical(batchNumber, _sentinel) ? this.batchNumber : batchNumber as String?,
      expiryDate: identical(expiryDate, _sentinel) ? this.expiryDate : expiryDate as DateTime?,
      lastRestockedDate: identical(lastRestockedDate, _sentinel) ? this.lastRestockedDate : lastRestockedDate as DateTime?,
      isActive: isActive ?? this.isActive,
      notes: identical(notes, _sentinel) ? this.notes : notes as String?,
      customFields: customFields ?? this.customFields,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          sku == other.sku &&
          category == other.category &&
          brand == other.brand &&
          unit == other.unit &&
          barcode == other.barcode &&
          warehouse == other.warehouse &&
          binLocation == other.binLocation &&
          supplier == other.supplier &&
          unitCostInr == other.unitCostInr &&
          sellingPriceInr == other.sellingPriceInr &&
          reorderLevel == other.reorderLevel &&
          maxStock == other.maxStock &&
          gstPercent == other.gstPercent &&
          batchNumber == other.batchNumber &&
          expiryDate == other.expiryDate &&
          lastRestockedDate == other.lastRestockedDate &&
          isActive == other.isActive &&
          notes == other.notes &&
          mapEquals(customFields, other.customFields);

  @override
  int get hashCode => Object.hashAll([
        id,
        name,
        sku,
        category,
        brand,
        unit,
        barcode,
        warehouse,
        binLocation,
        supplier,
        unitCostInr,
        sellingPriceInr,
        reorderLevel,
        maxStock,
        gstPercent,
        batchNumber,
        expiryDate,
        lastRestockedDate,
        isActive,
        notes,
        Object.hashAll(customFields.entries.map((e) => Object.hash(e.key, e.value))),
      ]);

  @override
  String toString() =>
      'InventoryItem(id: $id, name: $name, sku: $sku, category: $category, isActive: $isActive)';
}
