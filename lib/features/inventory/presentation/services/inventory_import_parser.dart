// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:xml/xml.dart';

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
    // 1. Attempt direct OOXML parse to preserve types and avoid styling/namespace bugs
    try {
      final parsed = _tryDirectOoxmlParse(file);
      if (parsed != null && parsed.sheets.isNotEmpty) {
        return parsed;
      }
    } catch (_) {
      // Fallback below
    }

    // 2. Fallback to excel package
    final excel_pkg.Excel excel;
    try {
      excel = excel_pkg.Excel.decodeBytes(file.bytes);
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

  InventoryImportParsedFile? _tryDirectOoxmlParse(
    InventoryImportSelectedFile file,
  ) {
    final archive = ZipDecoder().decodeBytes(file.bytes);

    // Read shared strings if present
    final sharedStrings = <String>[];
    final ssFile = archive.findFile('xl/sharedStrings.xml');
    if (ssFile != null) {
      ssFile.decompress();
      final ssContent = utf8.decode(ssFile.content, allowMalformed: true);
      final ssDoc = XmlDocument.parse(ssContent);
      for (final si in ssDoc
          .findAllElements('*')
          .where((e) => e.name.local == 'si')) {
        final text = si
            .findAllElements('*')
            .where((e) => e.name.local == 't')
            .map((e) => e.innerText)
            .join();
        sharedStrings.add(text);
      }
    }

    // Read relationship targets
    final relsFile = archive.findFile('xl/_rels/workbook.xml.rels');
    final relMap = <String, String>{};
    if (relsFile != null) {
      relsFile.decompress();
      final relsContent = utf8.decode(relsFile.content, allowMalformed: true);
      final relsDoc = XmlDocument.parse(relsContent);
      for (final r in relsDoc
          .findAllElements('*')
          .where((e) => e.name.local == 'Relationship')) {
        final id = r.getAttribute('Id');
        var target = r.getAttribute('Target') ?? '';
        if (target.startsWith('/')) target = target.substring(1);
        if (!target.startsWith('xl/')) target = 'xl/$target';
        if (id != null) relMap[id] = target;
      }
    }

    final wbFile = archive.findFile('xl/workbook.xml');
    if (wbFile == null) return null;
    wbFile.decompress();
    final wbContent = utf8.decode(wbFile.content, allowMalformed: true);
    final wbDoc = XmlDocument.parse(wbContent);

    final parsedSheets = <InventoryImportParsedSheet>[];
    for (final s in wbDoc
        .findAllElements('*')
        .where((e) => e.name.local == 'sheet')) {
      final name = s.getAttribute('name');
      final rId = s.getAttribute('r:id') ?? s.getAttribute('id') ?? '';
      if (name == null) continue;
      final target = relMap[rId];
      if (target == null) continue;

      final wsFile = archive.findFile(target);
      if (wsFile == null) continue;
      wsFile.decompress();
      final wsContent = utf8.decode(wsFile.content, allowMalformed: true);
      final wsDoc = XmlDocument.parse(wsContent);

      final rows = <List<String>>[];
      for (final r in wsDoc
          .findAllElements('*')
          .where((e) => e.name.local == 'row')) {
        final cellMap = <int, String>{};
        var maxCol = 0;
        for (final c in r
            .findAllElements('*')
            .where((e) => e.name.local == 'c')) {
          final ref = c.getAttribute('r') ?? '';
          final colIdx = _colRefToIndex(ref);
          final t = c.getAttribute('t');
          final v = c
              .findAllElements('*')
              .where((e) => e.name.local == 'v')
              .firstOrNull
              ?.innerText ??
              '';
          final inlineStr = c
              .findAllElements('*')
              .where((e) => e.name.local == 'is')
              .firstOrNull
              ?.findAllElements('*')
              .where((e) => e.name.local == 't')
              .firstOrNull
              ?.innerText;

          final String cellVal;
          if (t == 's') {
            final idx = int.tryParse(v);
            cellVal = idx != null && idx < sharedStrings.length
                ? sharedStrings[idx]
                : '';
          } else if (inlineStr != null) {
            cellVal = inlineStr;
          } else {
            cellVal = v;
          }

          cellMap[colIdx] = cellVal;
          if (colIdx >= maxCol) maxCol = colIdx + 1;
        }

        final rowCells = List<String>.generate(
          maxCol,
          (i) => cellMap[i] ?? '',
          growable: false,
        );
        rows.add(rowCells);
      }

      parsedSheets.add(
        InventoryImportParsedSheet(
          name: name,
          rows: List.unmodifiable(rows),
        ),
      );
    }

    if (parsedSheets.isEmpty) return null;

    return InventoryImportParsedFile(
      fileName: file.name,
      fileType: InventoryImportFileType.xlsx,
      sheets: List.unmodifiable(parsedSheets),
    );
  }

  static int _colRefToIndex(String cellRef) {
    var col = 0;
    for (var i = 0; i < cellRef.length; i++) {
      final code = cellRef.codeUnitAt(i);
      if (code >= 65 && code <= 90) {
        col = col * 26 + (code - 64);
      } else if (code >= 97 && code <= 122) {
        col = col * 26 + (code - 96);
      } else {
        break;
      }
    }
    return col > 0 ? col - 1 : 0;
  }

  String _convertCellValue(excel_pkg.CellValue? value) {
    if (value == null) return '';
    return switch (value) {
      excel_pkg.TextCellValue(:final value) => value.toString(),
      excel_pkg.IntCellValue(:final value) => value.toString(),
      excel_pkg.DoubleCellValue(:final value) => value.toString(),
      excel_pkg.BoolCellValue(:final value) => value.toString(),
      excel_pkg.DateCellValue(:final year, :final month, :final day) =>
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
      excel_pkg.DateTimeCellValue(
        :final year,
        :final month,
        :final day,
        :final hour,
        :final minute,
        :final second,
      ) =>
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}T${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}',
      excel_pkg.TimeCellValue(:final hour, :final minute, :final second) =>
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}',
      excel_pkg.FormulaCellValue(:final formula) => formula,
    };
  }
}
