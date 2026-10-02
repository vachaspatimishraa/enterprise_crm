import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../domain/entities/inventory_item_summary.dart';

/// Exception thrown when XLSX workbook serialization fails.
class InventoryXlsxSerializerException implements Exception {
  final String message;
  const InventoryXlsxSerializerException(this.message);

  @override
  String toString() => 'InventoryXlsxSerializerException: $message';
}

/// Pure-Dart serializer for generating Inventory XLSX workbooks.
class InventoryXlsxSerializer {
  static const String sheetName = 'Inventory';

  /// Converts a list of [InventoryItemSummary] into an XLSX byte array.
  Uint8List convertToBytes(List<InventoryItemSummary> items) {
    try {
      final excel = Excel.createExcel();

      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != sheetName) {
        excel.rename(defaultSheet, sheetName);
      }
      final sheet = excel[sheetName];

      if (defaultSheet != null &&
          defaultSheet != sheetName &&
          excel.tables.containsKey(defaultSheet)) {
        excel.delete(defaultSheet);
      }

      sheet.appendRow([
        TextCellValue('Item Name'),
        TextCellValue('SKU'),
        TextCellValue('Current Quantity'),
      ]);

      for (final summary in items) {
        final item = summary.item;
        final qty = summary.quantityOnHand;

        if (!qty.isFinite) {
          throw InventoryXlsxSerializerException(
            'Invalid non-finite quantity for item "${item.name}" (SKU: ${item.sku}): $qty',
          );
        }

        final CellValue quantityCell = qty % 1 == 0
            ? IntCellValue(qty.toInt())
            : DoubleCellValue(qty);

        sheet.appendRow([
          TextCellValue(item.name),
          TextCellValue(item.sku),
          quantityCell,
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) {
        throw const InventoryXlsxSerializerException(
          'Failed to encode Excel workbook',
        );
      }

      return Uint8List.fromList(bytes);
    } on InventoryXlsxSerializerException {
      rethrow;
    } catch (e) {
      throw InventoryXlsxSerializerException(
        'Failed to serialize XLSX workbook: $e',
      );
    }
  }
}
