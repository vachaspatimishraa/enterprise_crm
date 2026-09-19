import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_export.dart';

/// Strongly typed result of serializing leads into export bytes.
class LeadExportContent {
  const LeadExportContent({
    required this.bytes,
    required this.extension,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String extension;
  final String mimeType;
}

/// Abstract interface for in-memory lead export serialization.
abstract interface class LeadExportSerializer {
  LeadExportContent serialize({
    required List<Lead> leads,
    required LeadExportFormat format,
  });
}

/// Default implementation of [LeadExportSerializer] converting [Lead] objects
/// into CSV (UTF-8) or XLSX (Excel) bytes following the frozen L7A column policy.
class DefaultLeadExportSerializer implements LeadExportSerializer {
  const DefaultLeadExportSerializer();

  /// Frozen L7A export column headers in authoritative order.
  static const List<String> exportHeaders = [
    'Name',
    'Phone',
    'Email',
    'Status',
    'Source',
    'Assigned To',
    'Created At',
    'Updated At',
  ];

  static const String csvMimeType = 'text/csv';
  static const String excelMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const String excelSheetName = 'Leads';

  @override
  LeadExportContent serialize({
    required List<Lead> leads,
    required LeadExportFormat format,
  }) {
    switch (format) {
      case LeadExportFormat.csv:
        return _serializeCsv(leads);
      case LeadExportFormat.excel:
        return _serializeExcel(leads);
    }
  }

  LeadExportContent _serializeCsv(List<Lead> leads) {
    final rows = <List<dynamic>>[];
    rows.add(exportHeaders);

    for (final lead in leads) {
      rows.add(_leadToRow(lead));
    }

    final csvString = const CsvEncoder().convert(rows);
    final bytes = Uint8List.fromList(utf8.encode(csvString));

    return LeadExportContent(
      bytes: bytes,
      extension: 'csv',
      mimeType: csvMimeType,
    );
  }

  LeadExportContent _serializeExcel(List<Lead> leads) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    final sheet = excel[excelSheetName];

    final headerCells = exportHeaders
        .map<CellValue?>((h) => TextCellValue(h))
        .toList();
    sheet.appendRow(headerCells);

    for (final lead in leads) {
      final row = _leadToRow(lead);
      final cells = row
          .map<CellValue?>((val) => val.isEmpty ? null : TextCellValue(val))
          .toList();
      sheet.appendRow(cells);
    }

    if (defaultSheet != null && defaultSheet != excelSheetName) {
      excel.delete(defaultSheet);
    }

    final encoded = excel.encode();
    final bytes = Uint8List.fromList(encoded ?? []);

    return LeadExportContent(
      bytes: bytes,
      extension: 'xlsx',
      mimeType: excelMimeType,
    );
  }

  List<String> _leadToRow(Lead lead) {
    return [
      lead.name ?? '',
      lead.phone ?? '',
      lead.email ?? '',
      lead.status?.value ?? '',
      lead.source.name,
      lead.assignedUserName ?? '',
      lead.createdAt?.toIso8601String() ?? '',
      lead.updatedAt?.toIso8601String() ?? '',
    ];
  }
}
