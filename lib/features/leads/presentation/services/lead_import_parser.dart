import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../../domain/entities/lead_source.dart';
import '../models/lead_import_parsed_file.dart';
import '../models/lead_import_selected_file.dart';

/// Exception thrown when file parsing fails with a user-safe message.
class LeadImportParseException implements Exception {
  const LeadImportParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Abstract interface for parsing selected Lead import files.
abstract interface class LeadImportParser {
  Future<LeadImportParsedFile> parse(LeadImportSelectedFile file);
}

/// Default implementation of [LeadImportParser] supporting CSV and XLSX formats.
class DefaultLeadImportParser implements LeadImportParser {
  const DefaultLeadImportParser();

  @override
  Future<LeadImportParsedFile> parse(LeadImportSelectedFile file) async {
    final ext = file.extension.trim().toLowerCase();

    // Validate extension and source consistency
    if (ext == 'csv' && file.source != LeadSource.csv) {
      throw const LeadImportParseException(
        'Unsupported or inconsistent import file.',
      );
    }
    if (ext == 'xlsx' && file.source != LeadSource.excel) {
      throw const LeadImportParseException(
        'Unsupported or inconsistent import file.',
      );
    }
    if (ext != 'csv' && ext != 'xlsx') {
      throw const LeadImportParseException('Unsupported file type.');
    }

    try {
      if (ext == 'csv') {
        return await _parseCsv(file);
      } else {
        return await _parseXlsx(file);
      }
    } on LeadImportParseException {
      rethrow;
    } catch (_) {
      if (ext == 'csv') {
        throw const LeadImportParseException('Unable to read this CSV file.');
      } else {
        throw const LeadImportParseException('Unable to read this Excel file.');
      }
    }
  }

  Future<LeadImportParsedFile> _parseCsv(LeadImportSelectedFile file) async {
    final Uint8List bytes;
    try {
      bytes = await file.content.readAsBytes();
    } catch (_) {
      throw const LeadImportParseException('Unable to read this CSV file.');
    }

    String csvText;
    try {
      csvText = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const LeadImportParseException('Unable to read this CSV file.');
    } catch (_) {
      throw const LeadImportParseException('Unable to read this CSV file.');
    }

    // Strip UTF-8 BOM if present
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
      throw const LeadImportParseException('Unable to read this CSV file.');
    }

    final parsedRows = rawRows
        .map(
          (row) => List<String>.unmodifiable(
            row.map((cell) => cell?.toString() ?? ''),
          ),
        )
        .toList(growable: false);

    return LeadImportParsedFile(
      fileName: file.name,
      source: LeadSource.csv,
      sheets: List.unmodifiable([
        LeadImportParsedSheet(name: 'CSV', rows: List.unmodifiable(parsedRows)),
      ]),
    );
  }

  Future<LeadImportParsedFile> _parseXlsx(LeadImportSelectedFile file) async {
    final Uint8List bytes;
    try {
      bytes = await file.content.readAsBytes();
    } catch (_) {
      throw const LeadImportParseException('Unable to read this Excel file.');
    }

    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      throw const LeadImportParseException('Unable to read this Excel file.');
    }

    final parsedSheets = <LeadImportParsedSheet>[];

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
            final cell = rawRow[i];
            rowCells.add(_convertCellValue(cell?.value));
          } else {
            rowCells.add('');
          }
        }
        parsedRows.add(List<String>.unmodifiable(rowCells));
      }

      parsedSheets.add(
        LeadImportParsedSheet(
          name: sheetName,
          rows: List<List<String>>.unmodifiable(parsedRows),
        ),
      );
    }

    return LeadImportParsedFile(
      fileName: file.name,
      source: LeadSource.excel,
      sheets: List.unmodifiable(parsedSheets),
    );
  }

  String _convertCellValue(CellValue? value) {
    if (value == null) return '';
    switch (value) {
      case TextCellValue(:final value):
        return value.toString();
      case IntCellValue(:final value):
        return value.toString();
      case DoubleCellValue(:final value):
        return value.toString();
      case BoolCellValue(:final value):
        return value.toString();
      case DateCellValue(:final year, :final month, :final day):
        final y = year.toString().padLeft(4, '0');
        final m = month.toString().padLeft(2, '0');
        final d = day.toString().padLeft(2, '0');
        return '$y-$m-$d';
      case DateTimeCellValue(
        :final year,
        :final month,
        :final day,
        :final hour,
        :final minute,
        :final second,
      ):
        final y = year.toString().padLeft(4, '0');
        final m = month.toString().padLeft(2, '0');
        final d = day.toString().padLeft(2, '0');
        final hh = hour.toString().padLeft(2, '0');
        final mm = minute.toString().padLeft(2, '0');
        final ss = second.toString().padLeft(2, '0');
        return '$y-$m-${d}T$hh:$mm:$ss';
      case TimeCellValue(:final hour, :final minute, :final second):
        final hh = hour.toString().padLeft(2, '0');
        final mm = minute.toString().padLeft(2, '0');
        final ss = second.toString().padLeft(2, '0');
        return '$hh:$mm:$ss';
      case FormulaCellValue(:final formula):
        return formula;
    }
  }
}
