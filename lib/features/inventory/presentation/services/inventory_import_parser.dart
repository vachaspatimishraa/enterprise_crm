import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../../domain/entities/inventory_import_models.dart';
import 'inventory_import_file_picker.dart';

/// Exception thrown when file parsing fails with a user-safe message.
class InventoryImportParseException implements Exception {
  const InventoryImportParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Represents a single sheet of parsed tabular string cells.
class InventoryImportParsedSheet {
  const InventoryImportParsedSheet({required this.name, required this.rows});

  final String name;
  final List<List<String>> rows;
}

/// Representation of a parsed CSV or XLSX file containing one or more tabular sheets.
class InventoryImportParsedFile {
  const InventoryImportParsedFile({
    required this.fileName,
    required this.fileType,
    required this.sheets,
  });

  final String fileName;
  final InventoryImportFileType fileType;
  final List<InventoryImportParsedSheet> sheets;
}

/// Abstract interface for tabular file parsing.
abstract interface class InventoryImportParser {
  Future<InventoryImportParsedFile> parse(InventoryImportSelectedFile file);
}

/// Default implementation of [InventoryImportParser] for CSV and XLSX files.
class DefaultInventoryImportParser implements InventoryImportParser {
  const DefaultInventoryImportParser();

  @override
  Future<InventoryImportParsedFile> parse(
    InventoryImportSelectedFile file,
  ) async {
    final ext = file.extension.trim().toLowerCase();
    if (ext != 'csv' && ext != 'xlsx') {
      throw const InventoryImportParseException(
        'Please select a CSV or XLSX file.',
      );
    }

    try {
      if (ext == 'csv') {
        return _parseCsv(file);
      } else {
        return _parseXlsx(file);
      }
    } on InventoryImportParseException {
      rethrow;
    } catch (_) {
      throw const InventoryImportParseException('Unable to read this file.');
    }
  }

  InventoryImportParsedFile _parseCsv(InventoryImportSelectedFile file) {
    String csvText;
    try {
      csvText = utf8.decode(file.bytes, allowMalformed: false);
    } on FormatException {
      throw const InventoryImportParseException('Unable to read this file.');
    } catch (_) {
      throw const InventoryImportParseException('Unable to read this file.');
    }

    if (csvText.startsWith('\uFEFF')) {
      csvText = csvText.substring(1);
    }

    const decoder = CsvDecoder(
      dynamicTyping: false,
      parseHeaders: false,
      skipEmptyLines: false,
    );

    final List<List<dynamic>> rawRows;
    try {
      rawRows = decoder.convert(csvText);
    } catch (_) {
      throw const InventoryImportParseException('Unable to read this file.');
    }

    final parsedRows = rawRows
        .map(
          (row) => List<String>.unmodifiable(
            row.map((cell) => cell?.toString() ?? ''),
          ),
        )
        .toList(growable: false);

    return InventoryImportParsedFile(
      fileName: file.name,
      fileType: InventoryImportFileType.csv,
      sheets: List.unmodifiable([
        InventoryImportParsedSheet(
          name: 'CSV',
          rows: List.unmodifiable(parsedRows),
        ),
      ]),
    );
  }

  InventoryImportParsedFile _parseXlsx(InventoryImportSelectedFile file) {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(file.bytes);
    } catch (_) {
      throw const InventoryImportParseException('Unable to read this file.');
    }

    final parsedSheets = <InventoryImportParsedSheet>[];
    for (final entry in excel.tables.entries) {
      final sheetName = entry.key;
      final sheet = entry.value;
      final maxCols = sheet.maxColumns;

      final parsedRows = <List<String>>[];
      for (final rawRow in sheet.rows) {
        final rowCells = <String>[];
        final colCount = maxCols > rawRow.length ? maxCols : rawRow.length;

        for (var i = 0; i < colCount; i++) {
          if (i < rawRow.length) {
            rowCells.add(_convertCellValue(rawRow[i]?.value));
          } else {
            rowCells.add('');
          }
        }
        parsedRows.add(List.unmodifiable(rowCells));
      }

      parsedSheets.add(
        InventoryImportParsedSheet(
          name: sheetName,
          rows: List.unmodifiable(parsedRows),
        ),
      );
    }

    if (parsedSheets.isEmpty) {
      throw const InventoryImportParseException('Unable to read this file.');
    }

    return InventoryImportParsedFile(
      fileName: file.name,
      fileType: InventoryImportFileType.xlsx,
      sheets: List.unmodifiable(parsedSheets),
    );
  }

  String _convertCellValue(CellValue? value) {
    if (value == null) return '';
    return switch (value) {
      TextCellValue(:final value) => value.toString(),
      IntCellValue(:final value) => value.toString(),
      DoubleCellValue(:final value) => value.toString(),
      BoolCellValue(:final value) => value.toString(),
      DateCellValue(:final year, :final month, :final day) =>
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
      DateTimeCellValue(
        :final year,
        :final month,
        :final day,
        :final hour,
        :final minute,
        :final second,
      ) =>
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}T${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}',
      TimeCellValue(:final hour, :final minute, :final second) =>
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}',
      FormulaCellValue(:final formula) => formula,
    };
  }
}
