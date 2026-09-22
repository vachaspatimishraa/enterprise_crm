/// Base class for all domain-level inventory exceptions.
abstract class InventoryException implements Exception {
  final String message;

  const InventoryException([this.message = 'An inventory error occurred.']);

  @override
  String toString() => message;
}

/// Thrown when inventory item data fails validation (e.g. blank name or SKU).
class InventoryValidationException extends InventoryException {
  const InventoryValidationException(super.message);
}

/// Thrown when an inventory item with a duplicate normalized SKU is submitted.
class InventoryDuplicateSkuException extends InventoryException {
  const InventoryDuplicateSkuException([
    super.message = 'An item with this SKU already exists.',
  ]);
}

/// Thrown when an inventory item cannot be found by its identifier.
class InventoryItemNotFoundException extends InventoryException {
  const InventoryItemNotFoundException([
    super.message = 'Inventory item not found.',
  ]);
}

/// Thrown when attempting to record opening stock for an item that already has movements.
class InventoryOpeningStockAlreadyRecordedException extends InventoryException {
  const InventoryOpeningStockAlreadyRecordedException([
    super.message = 'Opening stock has already been recorded for this item.',
  ]);
}

/// Thrown when a manual adjustment would result in negative stock balance.
class InventoryNegativeStockException extends InventoryException {
  const InventoryNegativeStockException([
    super.message = 'Adjustment would cause negative stock balance.',
  ]);
}

/// Thrown when attempting to adjust stock for an uninitialized item (0 movements).
class InventoryUninitializedStockException extends InventoryException {
  const InventoryUninitializedStockException([
    super.message =
        'Stock must be initialized before manual adjustments can be applied.',
  ]);
}
