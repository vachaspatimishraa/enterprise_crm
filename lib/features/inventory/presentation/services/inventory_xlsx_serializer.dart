import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_export_fields.dart';
import '../../domain/entities/inventory_item_summary.dart';

/// Exception thrown when XLSX workbook serialization fails.
class InventoryXlsxSerializerException implements Exception {
  final String message;
  const InventoryXlsxSerializerException(this.message);

  @override
  String toString() => 'InventoryXlsxSerializerException: $message';
}

/// Pure-Dart serializer for generating Inventory XLSX workbooks with user-selected
/// columns, cell typing, and leading-zero preservation.
class InventoryXlsxSerializer {
  static const String sheetName = 'Inventory';

  /// Converts a list of [InventoryItemSummary] into an XLSX byte array.
  ///
  /// If [columns] is null or empty, defaults to the legacy 3-column schema.
  Uint8List convertToBytes(
    List<InventoryItemSummary> items, {
    List<String>? columns,
    List<CustomFieldDefinition>? customFieldDefinitions,
    bool isLegacy = false,
  }) {
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

      final effectiveColumns = columns != null && columns.isNotEmpty
          ? columns
          : InventoryExportFields.legacyHeaders;

      final effectiveIsLegacy = isLegacy ||
          (columns == null && effectiveColumns == InventoryExportFields.legacyHeaders);

      final headerCells = effectiveColumns
          .map<CellValue>(
            (c) => TextCellValue(
              InventoryExportFields.getHeaderLabel(
                c,
                customFieldDefinitions: customFieldDefinitions,
                isLegacy: effectiveIsLegacy,
              ),
            ),
          )
          .toList();

      sheet.appendRow(headerCells);

      for (final summary in items) {
        final rowCells = <CellValue?>[];

        for (final col in effectiveColumns) {
          final norm = InventoryExportFields.normalizeKey(col);
          final val = InventoryExportFields.extractValue(
            summary,
            col,
            customFieldDefinitions: customFieldDefinitions,
          );

          if (val == null) {
            rowCells.add(null);
          } else if (norm == 'sku' || norm == 'barcode') {
            // Text storage strictly required for SKU and barcode to preserve leading zeroes
            rowCells.add(TextCellValue(val.toString()));
          } else if (val is num) {
            if (!val.toDouble().isFinite) {
              throw InventoryXlsxSerializerException(
                'Invalid non-finite quantity for item "${summary.item.name}" (SKU: ${summary.item.sku}): $val',
              );
            }
            if (val % 1 == 0) {
              rowCells.add(IntCellValue(val.toInt()));
            } else {
              rowCells.add(DoubleCellValue(val.toDouble()));
            }
          } else if (val is bool) {
            rowCells.add(BoolCellValue(val));
          } else if (val is DateTime) {
            rowCells.add(
              DateCellValue(
                year: val.year,
                month: val.month,
                day: val.day,
              ),
            );
          } else {
            rowCells.add(TextCellValue(val.toString()));
          }
        }

        sheet.appendRow(rowCells);
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
