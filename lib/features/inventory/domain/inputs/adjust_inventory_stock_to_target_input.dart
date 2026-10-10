import 'package:flutter/foundation.dart';

/// Domain input for adjusting stock quantity towards a target balance for an initialized item.
@immutable
class AdjustInventoryStockToTargetInput {
  final String itemId;
  final double targetQuantity;
  final String reason;
  final String performedByUserId;

  const AdjustInventoryStockToTargetInput({
    required this.itemId,
    required this.targetQuantity,
    required this.reason,
    required this.performedByUserId,
  });
}
