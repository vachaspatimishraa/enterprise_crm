import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../../domain/entities/inventory_item_summary.dart';

/// Exception thrown when CSV export serialization fails.
class InventoryCsvSerializerException implements Exception {
  const InventoryCsvSerializerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Service responsible for securely formatting and serializing Inventory item
/// summaries into UTF-8 encoded CSV bytes.
class InventoryCsvSerializer {
  const InventoryCsvSerializer();

  static const String headerName = 'Item Name';
  static const String headerSku = 'SKU';
  static const String headerQuantity = 'Current Quantity';

  /// Converts a list of [InventoryItemSummary] records into a UTF-8 CSV string.
  String convertToString(List<InventoryItemSummary> items) {
    final rows = <List<dynamic>>[
      [headerName, headerSku, headerQuantity],
    ];

    for (final summary in items) {
      if (!summary.quantityOnHand.isFinite) {
        throw InventoryCsvSerializerException(
          'Invalid non-finite quantity for item SKU "${summary.item.sku}": ${summary.quantityOnHand}',
        );
      }

      final safeName = _neutralizeFormula(summary.item.name);
      final safeSku = _neutralizeFormula(summary.item.sku);
      final formattedQuantity = _formatQuantity(summary.quantityOnHand);

      rows.add([safeName, safeSku, formattedQuantity]);
    }

    const encoder = CsvEncoder(
      fieldDelimiter: ',',
      lineDelimiter: '\r\n',
    );

    return encoder.convert(rows);
  }

  /// Converts a list of [InventoryItemSummary] records into UTF-8 CSV bytes.
  Uint8List convertToBytes(List<InventoryItemSummary> items) {
    final csvString = convertToString(items);
    return Uint8List.fromList(utf8.encode(csvString));
  }

  /// Neutralizes potential spreadsheet formula injection triggers (=, +, -, @).
  static String _neutralizeFormula(String input) {
    if (input.isEmpty) return input;

    final trimmedLeading = input.trimLeft();
    if (trimmedLeading.isEmpty) return input;

    final firstChar = trimmedLeading[0];
    if (firstChar == '=' || firstChar == '+' || firstChar == '-' || firstChar == '@') {
      return "'$input";
    }

    return input;
  }

  /// Formats quantity as a clean numeric string preserving exact value without locale commas.
  static String _formatQuantity(double quantity) {
    if (quantity == quantity.toInt()) {
      return quantity.toInt().toString();
    }
    return quantity.toString();
  }
}
