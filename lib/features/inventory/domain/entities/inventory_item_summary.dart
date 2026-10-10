import 'package:flutter/foundation.dart';
import 'inventory_item.dart';

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
      'InventoryItemSummary(item: ${item.name} (${item.sku}), quantityOnHand: $quantityOnHand)';
}
