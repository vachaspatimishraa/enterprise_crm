import 'package:flutter/foundation.dart';
import '../../domain/entities/inventory_item_summary.dart';

/// States emitted by [InventoryItemDetailsCubit].
@immutable
sealed class InventoryItemDetailsState {
  const InventoryItemDetailsState();
}

final class InventoryItemDetailsInitial extends InventoryItemDetailsState {
  const InventoryItemDetailsInitial();
}

final class InventoryItemDetailsLoading extends InventoryItemDetailsState {
  const InventoryItemDetailsLoading();
}

final class InventoryItemDetailsLoaded extends InventoryItemDetailsState {
  final InventoryItemSummary summary;
  final bool hasStockMovements;

  const InventoryItemDetailsLoaded(
    this.summary, {
    this.hasStockMovements = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryItemDetailsLoaded &&
          runtimeType == other.runtimeType &&
          summary == other.summary &&
          hasStockMovements == other.hasStockMovements;

  @override
  int get hashCode => Object.hash(summary, hasStockMovements);
}

final class InventoryItemDetailsNotFound extends InventoryItemDetailsState {
  final String id;

  const InventoryItemDetailsNotFound(this.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryItemDetailsNotFound &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

final class InventoryItemDetailsFailure extends InventoryItemDetailsState {
  final String message;
  final String id;

  const InventoryItemDetailsFailure({required this.message, required this.id});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryItemDetailsFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          id == other.id;

  @override
  int get hashCode => Object.hash(message, id);
}
