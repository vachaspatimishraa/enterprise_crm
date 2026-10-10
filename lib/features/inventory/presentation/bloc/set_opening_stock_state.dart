import 'package:flutter/foundation.dart';

import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/entities/inventory_stock_mutation_result.dart';

/// States for [SetOpeningStockCubit].
@immutable
sealed class SetOpeningStockState {
  const SetOpeningStockState();
}

final class SetOpeningStockInitial extends SetOpeningStockState {
  const SetOpeningStockInitial();
}

final class SetOpeningStockLoading extends SetOpeningStockState {
  const SetOpeningStockLoading();
}

final class SetOpeningStockReady extends SetOpeningStockState {
  final InventoryItemSummary item;

  const SetOpeningStockReady(this.item);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetOpeningStockReady &&
          runtimeType == other.runtimeType &&
          item == other.item;

  @override
  int get hashCode => item.hashCode;
}

final class SetOpeningStockUnavailable extends SetOpeningStockState {
  final String message;

  const SetOpeningStockUnavailable(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetOpeningStockUnavailable &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

final class SetOpeningStockSubmitting extends SetOpeningStockState {
  final InventoryItemSummary item;

  const SetOpeningStockSubmitting(this.item);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetOpeningStockSubmitting &&
          runtimeType == other.runtimeType &&
          item == other.item;

  @override
  int get hashCode => item.hashCode;
}

final class SetOpeningStockSuccess extends SetOpeningStockState {
  final InventoryStockMutationResult result;

  const SetOpeningStockSuccess(this.result);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetOpeningStockSuccess &&
          runtimeType == other.runtimeType &&
          result == other.result;

  @override
  int get hashCode => result.hashCode;
}

final class SetOpeningStockNotFound extends SetOpeningStockState {
  final String itemId;

  const SetOpeningStockNotFound(this.itemId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetOpeningStockNotFound &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId;

  @override
  int get hashCode => itemId.hashCode;
}

final class SetOpeningStockFailure extends SetOpeningStockState {
  final String message;
  final InventoryItemSummary? item;

  const SetOpeningStockFailure({required this.message, this.item});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetOpeningStockFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          item == other.item;

  @override
  int get hashCode => Object.hash(message, item);
}
