import 'package:flutter/foundation.dart';
import 'inventory_item.dart';
import 'inventory_stock_status.dart';

/// Read projection pairing an [InventoryItem] with its derived stock balance.
///
/// This is not a secondary source of truth; [quantityOnHand] is calculated from
/// the movement ledger.
@immutable
class InventoryItemSummary {
  final InventoryItem item;
  final double quantityOnHand;

  const InventoryItemSummary({
    required this.item,
    required this.quantityOnHand,
  });

  /// Derived stock status computed dynamically from [item.isActive], [quantityOnHand],
  /// [item.reorderLevel], and [item.maxStock].
  InventoryStockStatus get stockStatus => InventoryStockStatus.compute(
        isActive: item.isActive,
        quantityOnHand: quantityOnHand,
        reorderLevel: item.reorderLevel,
        maxStock: item.maxStock,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryItemSummary &&
          runtimeType == other.runtimeType &&
          item == other.item &&
          quantityOnHand == other.quantityOnHand;

  @override
  int get hashCode => Object.hash(item, quantityOnHand);

  @override
  String toString() =>
      'InventoryItemSummary(item: ${item.name} (${item.sku}), quantityOnHand: $quantityOnHand, status: ${stockStatus.name})';
}
