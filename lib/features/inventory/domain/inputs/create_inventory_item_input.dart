/// Input data for creating a new inventory item.
///
/// Supports all standard 21 fields and custom fields while maintaining 100%
/// backward compatibility with legacy callers specifying only [name] and [sku].
/// Stock movements and quantities remain managed strictly through the ledger.
class CreateInventoryItemInput {
  final String name;
  final String sku;
  final double? openingStock;
  final String? performedByUserId;
  final String category;
  final String? brand;
  final String unit;
  final String? barcode;
  final String warehouse;
  final String? binLocation;
  final String? supplier;
  final double? unitCostInr;
  final double? sellingPriceInr;
  final double? reorderLevel;
  final double? maxStock;
  final double? gstPercent;
  final String? batchNumber;
  final DateTime? expiryDate;
  final DateTime? lastRestockedDate;
  final bool isActive;
  final String? notes;
  final Map<String, dynamic> customFields;

  const CreateInventoryItemInput({
    required this.name,
    required this.sku,
    this.openingStock,
    this.performedByUserId,
    this.category = 'General',
    this.brand,
    this.unit = 'piece',
    this.barcode,
    this.warehouse = 'Default',
    this.binLocation,
    this.supplier,
    this.unitCostInr,
    this.sellingPriceInr,
    this.reorderLevel,
    this.maxStock,
    this.gstPercent,
    this.batchNumber,
    this.expiryDate,
    this.lastRestockedDate,
    this.isActive = true,
    this.notes,
    this.customFields = const {},
  });
}
