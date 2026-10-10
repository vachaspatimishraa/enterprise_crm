import 'package:flutter/foundation.dart';

/// Status lifecycle for a pending inventory deletion.
enum PendingDeletionStatus { pending, cancelled, finalized }

/// Entity representing an item scheduled for permanent deletion within the 60-second Undo window.
@immutable
class PendingInventoryDeletion {
  final String itemId;
  final String itemName;
  final String itemSku;
  final String initiatedByUserId;
  final DateTime requestedAt;
  final DateTime undoDeadline;
  final PendingDeletionStatus status;

  const PendingInventoryDeletion({
    required this.itemId,
    required this.itemName,
    required this.itemSku,
    required this.initiatedByUserId,
    required this.requestedAt,
    required this.undoDeadline,
    this.status = PendingDeletionStatus.pending,
  });

  /// Whether the deletion is currently active and can still be undone.
  bool isPendingAt(DateTime currentTime) {
    return status == PendingDeletionStatus.pending &&
        currentTime.isBefore(undoDeadline);
  }

  /// Whether the undo deadline has expired and the item is eligible for permanent finalization.
  bool isExpiredAt(DateTime currentTime) {
    return status == PendingDeletionStatus.pending &&
        !currentTime.isBefore(undoDeadline);
  }

  PendingInventoryDeletion copyWith({PendingDeletionStatus? status}) {
    return PendingInventoryDeletion(
      itemId: itemId,
      itemName: itemName,
      itemSku: itemSku,
      initiatedByUserId: initiatedByUserId,
      requestedAt: requestedAt,
      undoDeadline: undoDeadline,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingInventoryDeletion &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId &&
          status == other.status &&
          undoDeadline == other.undoDeadline;

  @override
  int get hashCode => Object.hash(itemId, status, undoDeadline);
}
