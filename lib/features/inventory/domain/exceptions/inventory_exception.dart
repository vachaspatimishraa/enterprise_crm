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
