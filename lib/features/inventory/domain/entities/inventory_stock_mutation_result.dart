import 'package:flutter/foundation.dart';

import 'inventory_item_summary.dart';
import 'stock_movement.dart';

/// Result of a stock mutation operation returning both the newly appended
/// [StockMovement] and the updated [InventoryItemSummary].
@immutable
class InventoryStockMutationResult {
  final StockMovement movement;
  final InventoryItemSummary item;

  const InventoryStockMutationResult({
    required this.movement,
    required this.item,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryStockMutationResult &&
          runtimeType == other.runtimeType &&
          movement == other.movement &&
          item == other.item;

  @override
  int get hashCode => Object.hash(movement, item);

  @override
  String toString() =>
      'InventoryStockMutationResult(movement: $movement, item: $item)';
}
