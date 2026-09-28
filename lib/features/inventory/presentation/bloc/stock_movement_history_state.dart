import 'package:flutter/foundation.dart';
import '../../domain/entities/stock_movement_record.dart';

/// Immutable states representing the lifecycle and outcomes of stock movement history loading.
@immutable
sealed class StockMovementHistoryState {
  const StockMovementHistoryState();
}

/// Initial state before any history request is initiated.
final class StockMovementHistoryInitial extends StockMovementHistoryState {
  const StockMovementHistoryInitial();
}

/// Emitted when an authorized request to fetch stock movement history is in progress.
final class StockMovementHistoryLoading extends StockMovementHistoryState {
  final String itemId;

  const StockMovementHistoryLoading(this.itemId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovementHistoryLoading &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId;

  @override
  int get hashCode => itemId.hashCode;

  @override
  String toString() => 'StockMovementHistoryLoading(itemId: $itemId)';
}

/// Emitted when movement records are successfully retrieved for an item.
final class StockMovementHistoryLoaded extends StockMovementHistoryState {
  final String itemId;
  final List<StockMovementRecord> records;

  StockMovementHistoryLoaded({
    required this.itemId,
    required List<StockMovementRecord> records,
  }) : records = List.unmodifiable(records);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovementHistoryLoaded &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId &&
          listEquals(records, other.records);

  @override
  int get hashCode => Object.hash(itemId, Object.hashAll(records));

  @override
  String toString() =>
      'StockMovementHistoryLoaded(itemId: $itemId, recordCount: ${records.length})';
}

/// Emitted when the item exists but has zero recorded movements in the ledger.
final class StockMovementHistoryEmpty extends StockMovementHistoryState {
  final String itemId;

  const StockMovementHistoryEmpty(this.itemId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovementHistoryEmpty &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId;

  @override
  int get hashCode => itemId.hashCode;

  @override
  String toString() => 'StockMovementHistoryEmpty(itemId: $itemId)';
}

/// Emitted when the requested item does not exist or has been permanently deleted.
final class StockMovementHistoryNotFound extends StockMovementHistoryState {
  final String itemId;

  const StockMovementHistoryNotFound(this.itemId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovementHistoryNotFound &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId;

  @override
  int get hashCode => itemId.hashCode;

  @override
  String toString() => 'StockMovementHistoryNotFound(itemId: $itemId)';
}

/// Emitted when the user lacks authorization to view inventory stock movement history.
final class StockMovementHistoryRestricted extends StockMovementHistoryState {
  final String itemId;

  const StockMovementHistoryRestricted(this.itemId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovementHistoryRestricted &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId;

  @override
  int get hashCode => itemId.hashCode;

  @override
  String toString() => 'StockMovementHistoryRestricted(itemId: $itemId)';
}

/// Emitted when an unexpected error occurs while retrieving stock movement history.
final class StockMovementHistoryFailure extends StockMovementHistoryState {
  final String itemId;
  final String message;

  const StockMovementHistoryFailure({
    required this.itemId,
    required this.message,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovementHistoryFailure &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId &&
          message == other.message;

  @override
  int get hashCode => Object.hash(itemId, message);

  @override
  String toString() =>
      'StockMovementHistoryFailure(itemId: $itemId, message: $message)';
}
