/// Formatters for presentation of inventory numbers and metadata.
abstract final class InventoryDisplayFormatters {
  /// Formats a quantity value cleanly: `10.0 -> '10'`, `10.5 -> '10.5'`.
  static String formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity.toString();
  }

  /// Formats a signed quantity delta explicitly: `+50`, `-10`, `0`.
  static String formatSignedQuantity(double delta) {
    final formatted = formatQuantity(delta.abs());
    if (delta > 0) return '+$formatted';
    if (delta < 0) return '-$formatted';
    return '0';
  }

  /// Formats a [DateTime] into standard presentation format (e.g. `2026-09-28 10:30 AM`).
  static String formatDateTime(DateTime dt) {
    final year = dt.year.toString();
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    var hour = dt.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute $period';
  }
}
