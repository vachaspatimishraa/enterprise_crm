/// Formatters for presentation of inventory numbers and metadata.
abstract final class InventoryDisplayFormatters {
  /// Formats a quantity value cleanly: `10.0 -> '10'`, `10.5 -> '10.5'`.
  static String formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity.toString();
  }
}
