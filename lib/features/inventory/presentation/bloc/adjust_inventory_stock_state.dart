import 'package:flutter/foundation.dart';

import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/entities/inventory_stock_mutation_result.dart';

/// Presentation-only direction for manual stock adjustments.
enum StockAdjustmentDirection { increase, decrease }

/// States for [AdjustInventoryStockCubit].
@immutable
sealed class AdjustInventoryStockState {
  const AdjustInventoryStockState();
}

final class AdjustInventoryStockInitial extends AdjustInventoryStockState {
  const AdjustInventoryStockInitial();
}

final class AdjustInventoryStockLoading extends AdjustInventoryStockState {
  const AdjustInventoryStockLoading();
}

final class AdjustInventoryStockReady extends AdjustInventoryStockState {
  final InventoryItemSummary item;

  const AdjustInventoryStockReady(this.item);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdjustInventoryStockReady &&
          runtimeType == other.runtimeType &&
          item == other.item;

  @override
  int get hashCode => item.hashCode;
}

final class AdjustInventoryStockUnavailable extends AdjustInventoryStockState {
  final String message;

  const AdjustInventoryStockUnavailable(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdjustInventoryStockUnavailable &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

final class AdjustInventoryStockSubmitting extends AdjustInventoryStockState {
  final InventoryItemSummary item;

  const AdjustInventoryStockSubmitting(this.item);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdjustInventoryStockSubmitting &&
          runtimeType == other.runtimeType &&
          item == other.item;

  @override
  int get hashCode => item.hashCode;
}

final class AdjustInventoryStockSuccess extends AdjustInventoryStockState {
  final InventoryStockMutationResult result;

  const AdjustInventoryStockSuccess(this.result);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdjustInventoryStockSuccess &&
          runtimeType == other.runtimeType &&
          result == other.result;

  @override
  int get hashCode => result.hashCode;
}

final class AdjustInventoryStockNotFound extends AdjustInventoryStockState {
  final String itemId;

  const AdjustInventoryStockNotFound(this.itemId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdjustInventoryStockNotFound &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId;

  @override
  int get hashCode => itemId.hashCode;
}

final class AdjustInventoryStockFailure extends AdjustInventoryStockState {
  final String message;
  final InventoryItemSummary? item;

  const AdjustInventoryStockFailure({required this.message, this.item});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdjustInventoryStockFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          item == other.item;

  @override
  int get hashCode => Object.hash(message, item);
}
