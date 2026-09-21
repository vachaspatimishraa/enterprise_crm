import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StockMovement Domain Tests', () {
    final testDate = DateTime.utc(2026, 1, 1, 9, 0);

    test('instantiates valid StockMovement with all required fields', () {
      final movement = StockMovement(
        id: 'mov_001',
        inventoryItemId: 'item_001',
        type: StockMovementType.openingStock,
        quantityDelta: 25.0,
        createdAt: testDate,
      );

      expect(movement.id, 'mov_001');
      expect(movement.inventoryItemId, 'item_001');
      expect(movement.type, StockMovementType.openingStock);
      expect(movement.quantityDelta, 25.0);
      expect(movement.createdAt, testDate);
    });

    test('StockMovementType contains exactly openingStock in INVENTORY-1', () {
      expect(StockMovementType.values, [StockMovementType.openingStock]);
    });

    test('throws ArgumentError when id is blank or whitespace', () {
      expect(
        () => StockMovement(
          id: '',
          inventoryItemId: 'item_001',
          type: StockMovementType.openingStock,
          quantityDelta: 10.0,
          createdAt: testDate,
        ),
        throwsArgumentError,
      );
      expect(
        () => StockMovement(
          id: '   ',
          inventoryItemId: 'item_001',
          type: StockMovementType.openingStock,
          quantityDelta: 10.0,
          createdAt: testDate,
        ),
        throwsArgumentError,
      );
    });

    test(
      'throws ArgumentError when inventoryItemId is blank or whitespace',
      () {
        expect(
          () => StockMovement(
            id: 'mov_001',
            inventoryItemId: '',
            type: StockMovementType.openingStock,
            quantityDelta: 10.0,
            createdAt: testDate,
          ),
          throwsArgumentError,
        );
        expect(
          () => StockMovement(
            id: 'mov_001',
            inventoryItemId: '   ',
            type: StockMovementType.openingStock,
            quantityDelta: 10.0,
            createdAt: testDate,
          ),
          throwsArgumentError,
        );
      },
    );

    test('value equality, hashCode, and toString operate correctly', () {
      final mov1 = StockMovement(
        id: 'mov_001',
        inventoryItemId: 'item_001',
        type: StockMovementType.openingStock,
        quantityDelta: 25.0,
        createdAt: testDate,
      );
      final mov2 = StockMovement(
        id: 'mov_001',
        inventoryItemId: 'item_001',
        type: StockMovementType.openingStock,
        quantityDelta: 25.0,
        createdAt: testDate,
      );
      final mov3 = StockMovement(
        id: 'mov_002',
        inventoryItemId: 'item_001',
        type: StockMovementType.openingStock,
        quantityDelta: 10.0,
        createdAt: testDate,
      );

      expect(mov1, equals(mov2));
      expect(mov1.hashCode, equals(mov2.hashCode));
      expect(mov1, isNot(equals(mov3)));
      expect(mov1.toString(), contains('mov_001'));
      expect(mov1.toString(), contains('item_001'));
      expect(mov1.toString(), contains('25.0'));
    });
  });
}
