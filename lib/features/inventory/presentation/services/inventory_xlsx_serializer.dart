import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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

      final effectiveIsLegacy =
          isLegacy ||
          (columns == null &&
              effectiveColumns == InventoryExportFields.legacyHeaders);

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
              DateCellValue(year: val.year, month: val.month, day: val.day),
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

      // excel 4.0.6 leaves the worksheet dimension at A1 even after rows are
      // appended. Readers that trust this OOXML range (including openpyxl's
      // streaming reader) then see only the first cell of an otherwise full
      // workbook. Correct the range before offering the file for download.
      final archive = ZipDecoder().decodeBytes(bytes);
      const worksheetPath = 'xl/worksheets/sheet1.xml';
      final worksheet = archive.findFile(worksheetPath);
      if (worksheet == null) {
        throw const InventoryXlsxSerializerException(
          'Encoded workbook is missing its inventory worksheet',
        );
      }
      worksheet.decompress();
      final xml = utf8.decode(worksheet.content as List<int>);
      final dimension =
          'A1:${_columnLabel(effectiveColumns.length)}${items.length + 1}';
      final updatedXml = xml.replaceFirst(
        RegExp(r'<dimension ref="[^"]*"\s*/>'),
        '<dimension ref="$dimension"/>',
      );
      if (updatedXml == xml) {
        throw const InventoryXlsxSerializerException(
          'Encoded workbook has no worksheet dimension',
        );
      }
      final updatedBytes = utf8.encode(updatedXml);
      archive.addFile(
        ArchiveFile(worksheetPath, updatedBytes.length, updatedBytes),
      );
      final corrected = ZipEncoder().encode(archive);
      if (corrected == null) {
        throw const InventoryXlsxSerializerException(
          'Failed to finalize Excel workbook',
        );
      }
      return Uint8List.fromList(corrected);
    } on InventoryXlsxSerializerException {
      rethrow;
    } catch (e) {
      throw InventoryXlsxSerializerException(
        'Failed to serialize XLSX workbook: $e',
      );
    }
  }

  String _columnLabel(int count) {
    var index = count;
    var label = '';
    while (index > 0) {
      index--;
      label = String.fromCharCode(65 + index % 26) + label;
      index ~/= 26;
    }
    return label;
  }
}
