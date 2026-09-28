import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_record.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StockMovementRecord Domain Projection', () {
    final sampleMovement = StockMovement(
      id: 'mov_001',
      inventoryItemId: 'item_001',
      type: StockMovementType.openingStock,
      quantityDelta: 50.0,
      createdAt: DateTime.utc(2026, 1, 1, 9, 0),
      performedByUserId: 'usr_admin',
      reason: null,
    );

    test(
      'creates valid record with movement reference and running balance',
      () {
        final record = StockMovementRecord(
          movement: sampleMovement,
          runningBalance: 50.0,
        );

        expect(record.movement, equals(sampleMovement));
        expect(record.runningBalance, 50.0);
      },
    );

    test('rejects non-finite running balance values', () {
      expect(
        () => StockMovementRecord(
          movement: sampleMovement,
          runningBalance: double.nan,
        ),
        throwsArgumentError,
      );

      expect(
        () => StockMovementRecord(
          movement: sampleMovement,
          runningBalance: double.infinity,
        ),
        throwsArgumentError,
      );

      expect(
        () => StockMovementRecord(
          movement: sampleMovement,
          runningBalance: double.negativeInfinity,
        ),
        throwsArgumentError,
      );
    });

    test('supports zero, negative, and decimal running balances', () {
      final zeroRecord = StockMovementRecord(
        movement: sampleMovement,
        runningBalance: 0.0,
      );
      expect(zeroRecord.runningBalance, 0.0);

      final negRecord = StockMovementRecord(
        movement: sampleMovement,
        runningBalance: -10.5,
      );
      expect(negRecord.runningBalance, -10.5);

      final decRecord = StockMovementRecord(
        movement: sampleMovement,
        runningBalance: 123.456,
      );
      expect(decRecord.runningBalance, 123.456);
    });

    test('implements value equality and hashCode correctly', () {
      final recordA = StockMovementRecord(
        movement: sampleMovement,
        runningBalance: 50.0,
      );
      final recordB = StockMovementRecord(
        movement: sampleMovement,
        runningBalance: 50.0,
      );
      final recordC = StockMovementRecord(
        movement: sampleMovement,
        runningBalance: 75.0,
      );

      expect(recordA, equals(recordB));
      expect(recordA.hashCode, equals(recordB.hashCode));
      expect(recordA, isNot(equals(recordC)));
    });

    test('provides informative toString implementation', () {
      final record = StockMovementRecord(
        movement: sampleMovement,
        runningBalance: 50.0,
      );

      expect(record.toString(), contains('StockMovementRecord'));
      expect(record.toString(), contains('runningBalance: 50.0'));
      expect(record.toString(), contains('mov_001'));
    });
  });
}
