/// Input data for updating an existing inventory item.
///
/// Supports updating standard and custom attributes while preserving immutable
/// ledger-derived stock quantities and existing values for omitted fields.
/// Nullable fields can be explicitly cleared by setting their corresponding `clear<Field>` flag to `true`.
class UpdateInventoryItemInput {
  final String id;
  final String name;
  final String sku;
  final String? category;
  final String? brand;
  final bool clearBrand;
  final String? unit;
  final String? barcode;
  final bool clearBarcode;
  final String? warehouse;
  final String? binLocation;
  final bool clearBinLocation;
  final String? supplier;
  final bool clearSupplier;
  final double? unitCostInr;
  final bool clearUnitCostInr;
  final double? sellingPriceInr;
  final bool clearSellingPriceInr;
  final double? reorderLevel;
  final bool clearReorderLevel;
  final double? maxStock;
  final bool clearMaxStock;
  final double? gstPercent;
  final bool clearGstPercent;
  final String? batchNumber;
  final bool clearBatchNumber;
  final DateTime? expiryDate;
  final bool clearExpiryDate;
  final DateTime? lastRestockedDate;
  final bool clearLastRestockedDate;
  final bool? isActive;
  final String? notes;
  final bool clearNotes;
  final Map<String, dynamic>? customFields;

  const UpdateInventoryItemInput({
    required this.id,
    required this.name,
    required this.sku,
    this.category,
    this.brand,
    this.clearBrand = false,
    this.unit,
    this.barcode,
    this.clearBarcode = false,
    this.warehouse,
    this.binLocation,
    this.clearBinLocation = false,
    this.supplier,
    this.clearSupplier = false,
    this.unitCostInr,
    this.clearUnitCostInr = false,
    this.sellingPriceInr,
    this.clearSellingPriceInr = false,
    this.reorderLevel,
    this.clearReorderLevel = false,
    this.maxStock,
    this.clearMaxStock = false,
    this.gstPercent,
    this.clearGstPercent = false,
    this.batchNumber,
    this.clearBatchNumber = false,
    this.expiryDate,
    this.clearExpiryDate = false,
    this.lastRestockedDate,
    this.clearLastRestockedDate = false,
    this.isActive,
    this.notes,
    this.clearNotes = false,
    this.customFields,
  });
}
