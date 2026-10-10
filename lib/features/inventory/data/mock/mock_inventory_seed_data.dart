import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/entities/stock_movement_type.dart';

/// Seed data generator for mock inventory items and opening stock movements.
abstract final class MockInventorySeedData {
  static final DateTime _baseDate = DateTime.utc(2026, 1, 1, 9, 0);

  /// Default list of 25 generic physical stock items.
  static List<InventoryItem> createDefaultItems() {
    return [
      InventoryItem(id: 'item_001', name: 'Laptop Stand', sku: 'INV-001'),
      InventoryItem(
        id: 'item_002',
        name: 'USB-C Multiport Dock',
        sku: 'INV-002',
      ),
      InventoryItem(
        id: 'item_003',
        name: 'Wireless Mechanical Keyboard',
        sku: 'INV-003',
      ),
      InventoryItem(
        id: 'item_004',
        name: 'Ergonomic Optical Mouse',
        sku: 'INV-004',
      ),
      InventoryItem(id: 'item_005', name: '27-inch 4K Monitor', sku: 'INV-005'),
      InventoryItem(id: 'item_006', name: 'HD Webcam 1080p', sku: 'INV-006'),
      InventoryItem(
        id: 'item_007',
        name: 'Noise-Cancelling Headset',
        sku: 'INV-007',
      ),
      InventoryItem(
        id: 'item_008',
        name: 'Monitor Desk Mount Arm',
        sku: 'INV-008',
      ),
      InventoryItem(
        id: 'item_009',
        name: 'Cat6 Ethernet Cable (3m)',
        sku: 'INV-009',
      ),
      InventoryItem(
        id: 'item_010',
        name: 'HDMI 2.1 Ultra High Speed Cable',
        sku: 'INV-010',
      ),
      InventoryItem(
        id: 'item_011',
        name: 'External SSD 1TB USB-C',
        sku: 'INV-011',
      ),
      InventoryItem(
        id: 'item_012',
        name: 'Desk LED Lamp with Dimmer',
        sku: 'INV-012',
      ),
      InventoryItem(
        id: 'item_013',
        name: 'Desk Mat XL Leatherette',
        sku: 'INV-013',
      ),
      InventoryItem(
        id: 'item_014',
        name: 'Cable Management Tray Underdesk',
        sku: 'INV-014',
      ),
      InventoryItem(
        id: 'item_015',
        name: 'Power Strip Surge Protector 8-Outlet',
        sku: 'INV-015',
      ),
      InventoryItem(
        id: 'item_016',
        name: 'USB-C to DisplayPort Adapter',
        sku: 'INV-016',
      ),
      InventoryItem(
        id: 'item_017',
        name: 'Bluetooth Conference Speakerphone',
        sku: 'INV-017',
      ),
      InventoryItem(
        id: 'item_018',
        name: 'Microfiber Cleaning Cloths (5-Pack)',
        sku: 'INV-018',
      ),
      InventoryItem(
        id: 'item_019',
        name: 'Adjustable Footrest Ergonomic',
        sku: 'INV-019',
      ),
      InventoryItem(
        id: 'item_020',
        name: 'Screen Privacy Filter 24-inch',
        sku: 'INV-020',
      ),
      InventoryItem(
        id: 'item_021',
        name: 'Wireless Presenter with Laser',
        sku: 'INV-021',
      ),
      InventoryItem(
        id: 'item_022',
        name: 'Dual Monitor Stand Desktop',
        sku: 'INV-022',
      ),
      InventoryItem(
        id: 'item_023',
        name: 'Magnetic Whiteboard 90x60cm',
        sku: 'INV-023',
      ),
      InventoryItem(
        id: 'item_024',
        name: 'Rechargeable AA Battery Set',
        sku: 'INV-024',
      ),
      InventoryItem(
        id: 'item_025',
        name: 'Surge Protected Extension Cord 5m',
        sku: 'INV-025',
      ),
    ];
  }

  /// Corresponding opening stock movements for the default items.
  ///
  /// Contains positive balances and at least one zero-stock item (`item_003` has delta 0).
  static List<StockMovement> createDefaultMovements() {
    return [
      StockMovement(
        id: 'mov_001',
        inventoryItemId: 'item_001',
        type: StockMovementType.openingStock,
        quantityDelta: 25.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_002',
        inventoryItemId: 'item_002',
        type: StockMovementType.openingStock,
        quantityDelta: 10.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_003',
        inventoryItemId: 'item_003',
        type: StockMovementType.openingStock,
        quantityDelta: 0.0, // Item with zero stock on hand
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_004',
        inventoryItemId: 'item_004',
        type: StockMovementType.openingStock,
        quantityDelta: 45.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_005',
        inventoryItemId: 'item_005',
        type: StockMovementType.openingStock,
        quantityDelta: 8.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_006',
        inventoryItemId: 'item_006',
        type: StockMovementType.openingStock,
        quantityDelta: 15.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_007',
        inventoryItemId: 'item_007',
        type: StockMovementType.openingStock,
        quantityDelta: 30.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_008',
        inventoryItemId: 'item_008',
        type: StockMovementType.openingStock,
        quantityDelta: 12.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_009',
        inventoryItemId: 'item_009',
        type: StockMovementType.openingStock,
        quantityDelta: 100.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_010',
        inventoryItemId: 'item_010',
        type: StockMovementType.openingStock,
        quantityDelta: 60.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_011',
        inventoryItemId: 'item_011',
        type: StockMovementType.openingStock,
        quantityDelta: 18.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_012',
        inventoryItemId: 'item_012',
        type: StockMovementType.openingStock,
        quantityDelta: 22.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_013',
        inventoryItemId: 'item_013',
        type: StockMovementType.openingStock,
        quantityDelta: 35.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_014',
        inventoryItemId: 'item_014',
        type: StockMovementType.openingStock,
        quantityDelta: 14.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_015',
        inventoryItemId: 'item_015',
        type: StockMovementType.openingStock,
        quantityDelta: 28.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_016',
        inventoryItemId: 'item_016',
        type: StockMovementType.openingStock,
        quantityDelta: 50.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_017',
        inventoryItemId: 'item_017',
        type: StockMovementType.openingStock,
        quantityDelta: 7.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_018',
        inventoryItemId: 'item_018',
        type: StockMovementType.openingStock,
        quantityDelta: 85.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_019',
        inventoryItemId: 'item_019',
        type: StockMovementType.openingStock,
        quantityDelta: 11.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_020',
        inventoryItemId: 'item_020',
        type: StockMovementType.openingStock,
        quantityDelta: 19.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_021',
        inventoryItemId: 'item_021',
        type: StockMovementType.openingStock,
        quantityDelta: 16.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_022',
        inventoryItemId: 'item_022',
        type: StockMovementType.openingStock,
        quantityDelta: 9.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_023',
        inventoryItemId: 'item_023',
        type: StockMovementType.openingStock,
        quantityDelta: 5.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_024',
        inventoryItemId: 'item_024',
        type: StockMovementType.openingStock,
        quantityDelta: 40.0,
        createdAt: _baseDate,
      ),
      StockMovement(
        id: 'mov_025',
        inventoryItemId: 'item_025',
        type: StockMovementType.openingStock,
        quantityDelta: 20.0,
        createdAt: _baseDate,
      ),
    ];
  }
}
