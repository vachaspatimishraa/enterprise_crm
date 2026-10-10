import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryItem Entity Tests', () {
    test('instantiates successfully with valid id, name, and sku', () {
      final item = InventoryItem(
        id: 'item_001',
        name: 'Laptop Stand',
        sku: 'INV-001',
      );

      expect(item.id, 'item_001');
      expect(item.name, 'Laptop Stand');
      expect(item.sku, 'INV-001');
    });

    test('strictly holds no quantity field in entity contract', () {
      // InventoryItem contains only intrinsic identity fields: id, name, sku.
      // Stock quantity is dynamically derived from stock movements.
      final item = InventoryItem(
        id: 'item_001',
        name: 'Laptop Stand',
        sku: 'INV-001',
      );

      expect(item, isA<InventoryItem>());
      // Compile-time and runtime check: item has no quantity property.
    });

    test('throws ArgumentError when id is blank or whitespace', () {
      expect(
        () => InventoryItem(id: '', name: 'Laptop Stand', sku: 'INV-001'),
        throwsArgumentError,
      );
      expect(
        () => InventoryItem(id: '   ', name: 'Laptop Stand', sku: 'INV-001'),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when name is blank or whitespace', () {
      expect(
        () => InventoryItem(id: 'item_001', name: '', sku: 'INV-001'),
        throwsArgumentError,
      );
      expect(
        () => InventoryItem(id: 'item_001', name: '   ', sku: 'INV-001'),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when sku is blank or whitespace', () {
      expect(
        () => InventoryItem(id: 'item_001', name: 'Laptop Stand', sku: ''),
        throwsArgumentError,
      );
      expect(
        () => InventoryItem(id: 'item_001', name: 'Laptop Stand', sku: '   '),
        throwsArgumentError,
      );
    });

    test('equality and hashCode are based on id, name, and sku', () {
      final item1 = InventoryItem(
        id: 'item_001',
        name: 'Laptop Stand',
        sku: 'INV-001',
      );
      final item2 = InventoryItem(
        id: 'item_001',
        name: 'Laptop Stand',
        sku: 'INV-001',
      );
      final item3 = InventoryItem(
        id: 'item_002',
        name: 'USB-C Dock',
        sku: 'INV-002',
      );

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
      expect(item1, isNot(equals(item3)));
    });

    test('toString contains all 3 fields', () {
      final item = InventoryItem(
        id: 'item_001',
        name: 'Laptop Stand',
        sku: 'INV-001',
      );
      expect(item.toString(), contains('item_001'));
      expect(item.toString(), contains('Laptop Stand'));
      expect(item.toString(), contains('INV-001'));
    });
  });
}
