import 'package:flutter/foundation.dart';
import 'stock_movement_type.dart';

/// Historical ledger record representing a stock delta for an [InventoryItem].
///
/// Current stock on hand is calculated as the sum of [quantityDelta] for a given
/// [inventoryItemId].
@immutable
class StockMovement {
  final String id;
  final String inventoryItemId;
  final StockMovementType type;
  final double quantityDelta;
  final DateTime createdAt;

  StockMovement({
    required this.id,
    required this.inventoryItemId,
    required this.type,
    required this.quantityDelta,
    required this.createdAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Movement ID cannot be blank.');
    }
    if (inventoryItemId.trim().isEmpty) {
      throw ArgumentError.value(
        inventoryItemId,
        'inventoryItemId',
        'Inventory item ID cannot be blank.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovement &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          inventoryItemId == other.inventoryItemId &&
          type == other.type &&
          quantityDelta == other.quantityDelta &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      Object.hash(id, inventoryItemId, type, quantityDelta, createdAt);

  @override
  String toString() =>
      'StockMovement(id: $id, itemId: $inventoryItemId, type: $type, delta: $quantityDelta, createdAt: $createdAt)';
}
