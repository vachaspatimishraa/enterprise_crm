import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../../domain/entities/inventory_import_models.dart';

/// Serializes row-level import failures into a safe, downloadable CSV report.
class InventoryImportErrorReportService {
  const InventoryImportErrorReportService();

  Uint8List toBytes(Iterable<InventoryImportRowFailure> failures) {
    final rows = <List<String>>[
      ['Source Row', 'SKU', 'Error'],
      for (final failure in failures)
        [
          failure.sourceRowNumber.toString(),
          _neutralizeFormula(failure.sku),
          _neutralizeFormula(failure.reason),
        ],
    ];
    return Uint8List.fromList(
      utf8.encode(
        const CsvEncoder(
          fieldDelimiter: ',',
          lineDelimiter: '\r\n',
        ).convert(rows),
      ),
    );
  }

  String _neutralizeFormula(String value) {
    final trimmed = value.trimLeft();
    if (trimmed.isNotEmpty && '=+-@'.contains(trimmed[0])) {
      return "'$value";
    }
    return value;
  }
}
