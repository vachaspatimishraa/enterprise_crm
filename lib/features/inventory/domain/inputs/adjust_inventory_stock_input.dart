import 'package:flutter/foundation.dart';

/// Domain input for recording a manual stock adjustment for an initialized item.
@immutable
class AdjustInventoryStockInput {
  final String itemId;
  final double quantityDelta;
  final String reason;
  final String performedByUserId;

  const AdjustInventoryStockInput({
    required this.itemId,
    required this.quantityDelta,
    required this.reason,
    required this.performedByUserId,
  });
}
