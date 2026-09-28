import 'package:flutter/foundation.dart';
import 'stock_movement.dart';

/// Read projection associating an immutable historical [StockMovement] with its
/// authoritative resulting [runningBalance] immediately following that movement.
///
/// Running balances are calculated from the complete authoritative movement ledger
/// chronologically forward from genesis.
@immutable
class StockMovementRecord {
  final StockMovement movement;
  final double runningBalance;

  StockMovementRecord({required this.movement, required this.runningBalance}) {
    if (!runningBalance.isFinite) {
      throw ArgumentError.value(
        runningBalance,
        'runningBalance',
        'Running balance must be a finite number.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovementRecord &&
          runtimeType == other.runtimeType &&
          movement == other.movement &&
          runningBalance == other.runningBalance;

  @override
  int get hashCode => Object.hash(movement, runningBalance);

  @override
  String toString() =>
      'StockMovementRecord(movement: $movement, runningBalance: $runningBalance)';
}
