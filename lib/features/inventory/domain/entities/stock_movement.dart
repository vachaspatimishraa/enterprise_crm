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
  final String? performedByUserId;
  final String? reason;

  StockMovement({
    required this.id,
    required this.inventoryItemId,
    required this.type,
    required this.quantityDelta,
    required this.createdAt,
    this.performedByUserId,
    this.reason,
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
    if (performedByUserId != null && performedByUserId!.trim().isEmpty) {
      throw ArgumentError.value(
        performedByUserId,
        'performedByUserId',
        'Performed by user ID cannot be blank if provided.',
      );
    }
    if (reason != null && reason!.trim().isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Reason cannot be blank if provided.',
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
          createdAt == other.createdAt &&
          performedByUserId == other.performedByUserId &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(
    id,
    inventoryItemId,
    type,
    quantityDelta,
    createdAt,
    performedByUserId,
    reason,
  );

  @override
  String toString() =>
      'StockMovement(id: $id, itemId: $inventoryItemId, type: $type, delta: $quantityDelta, createdAt: $createdAt, actor: $performedByUserId, reason: $reason)';
}
