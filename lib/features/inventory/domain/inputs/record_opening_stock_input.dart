import 'package:flutter/foundation.dart';

/// Domain input for recording initial opening stock for an uninitialized item.
@immutable
class RecordOpeningStockInput {
  final String itemId;
  final double quantity;
  final String performedByUserId;

  const RecordOpeningStockInput({
    required this.itemId,
    required this.quantity,
    required this.performedByUserId,
  });
}
