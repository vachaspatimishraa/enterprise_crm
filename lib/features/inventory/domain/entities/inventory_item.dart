import 'package:flutter/foundation.dart';

/// Pure domain entity representing an inventoried physical product or stock item.
///
/// Holds intrinsic identity fields only. Stock quantity is derived dynamically
/// from stock movements and is intentionally not stored on this entity.
@immutable
class InventoryItem {
  final String id;
  final String name;
  final String sku;

  InventoryItem({required this.id, required this.name, required this.sku}) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Item ID cannot be blank.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Item name cannot be blank.');
    }
    if (sku.trim().isEmpty) {
      throw ArgumentError.value(sku, 'sku', 'Item SKU cannot be blank.');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          sku == other.sku;

  @override
  int get hashCode => Object.hash(id, name, sku);

  @override
  String toString() => 'InventoryItem(id: $id, name: $name, sku: $sku)';
}
