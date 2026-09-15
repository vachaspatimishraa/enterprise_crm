import '../../domain/entities/lead_source.dart';

/// Represents a single sheet of parsed tabular data.
class LeadImportParsedSheet {
  const LeadImportParsedSheet({required this.name, required this.rows});

  /// The name of the worksheet or synthetic name ('CSV').
  final String name;

  /// The raw parsed table rows. No headers or column roles are inferred.
  final List<List<String>> rows;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportParsedSheet &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          _areRowsEqual(rows, other.rows);

  @override
  int get hashCode => Object.hash(name, rows.length);

  static bool _areRowsEqual(List<List<String>> a, List<List<String>> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (var j = 0; j < a[i].length; j++) {
        if (a[i][j] != b[i][j]) return false;
      }
    }
    return true;
  }

  @override
  String toString() =>
      'LeadImportParsedSheet(name: $name, rowCount: ${rows.length})';
}

/// Format-neutral representation of a parsed import file.
///
/// Contains raw tabular sheets without domain mapping or header inference.
/// Retains no permanent raw-byte buffers.
class LeadImportParsedFile {
  const LeadImportParsedFile({
    required this.fileName,
    required this.source,
    required this.sheets,
  });

  final String fileName;
  final LeadSource source;
  final List<LeadImportParsedSheet> sheets;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportParsedFile &&
          runtimeType == other.runtimeType &&
          fileName == other.fileName &&
          source == other.source &&
          _areSheetsEqual(sheets, other.sheets);

  @override
  int get hashCode => Object.hash(fileName, source, sheets.length);

  static bool _areSheetsEqual(
    List<LeadImportParsedSheet> a,
    List<LeadImportParsedSheet> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'LeadImportParsedFile(fileName: $fileName, source: $source, sheetCount: ${sheets.length})';
}
