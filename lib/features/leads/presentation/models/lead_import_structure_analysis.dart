import '../../domain/entities/lead_source.dart';

/// Severity of a structural issue discovered during import structure analysis.
enum LeadImportStructureIssueSeverity { warning, error }

/// Represents a structural finding or validation issue in the spreadsheet.
class LeadImportStructureIssue {
  const LeadImportStructureIssue({
    required this.severity,
    required this.message,
  });

  final LeadImportStructureIssueSeverity severity;
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportStructureIssue &&
          runtimeType == other.runtimeType &&
          severity == other.severity &&
          message == other.message;

  @override
  int get hashCode => Object.hash(severity, message);

  @override
  String toString() => 'LeadImportStructureIssue($severity: $message)';
}

/// Metadata for a discovered spreadsheet column based on the selected header row.
class LeadImportDiscoveredColumn {
  const LeadImportDiscoveredColumn({
    required this.index,
    required this.rawHeader,
    required this.displayHeader,
  });

  /// Zero-based column index in the spreadsheet. Serves as stable column identity.
  final int index;

  /// Raw header text as parsed, without modification or trimming.
  final String rawHeader;

  /// User-friendly display label (trimmed header or synthetic 'Column N' if blank).
  final String displayHeader;

  bool get isBlankHeader => rawHeader.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportDiscoveredColumn &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          rawHeader == other.rawHeader &&
          displayHeader == other.displayHeader;

  @override
  int get hashCode => Object.hash(index, rawHeader, displayHeader);

  @override
  String toString() =>
      'LeadImportDiscoveredColumn(index: $index, raw: "$rawHeader", display: "$displayHeader")';
}

/// Result of analyzing spreadsheet structure and column discovery for an import file.
class LeadImportStructureAnalysis {
  const LeadImportStructureAnalysis({
    required this.fileName,
    required this.source,
    required this.sheetIndex,
    required this.sheetName,
    required this.headerRowIndex,
    required this.columns,
    required this.dataRowCount,
    required this.issues,
  });

  final String fileName;
  final LeadSource source;
  final int sheetIndex;
  final String? sheetName;
  final int headerRowIndex;
  final List<LeadImportDiscoveredColumn> columns;
  final int dataRowCount;
  final List<LeadImportStructureIssue> issues;

  /// True if there are any blocking errors preventing import progression.
  bool get hasBlockingErrors =>
      issues.any((i) => i.severity == LeadImportStructureIssueSeverity.error);

  /// True if the structure has no blocking errors (warnings are permitted).
  bool get isValid => !hasBlockingErrors;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportStructureAnalysis &&
          runtimeType == other.runtimeType &&
          fileName == other.fileName &&
          source == other.source &&
          sheetIndex == other.sheetIndex &&
          sheetName == other.sheetName &&
          headerRowIndex == other.headerRowIndex &&
          dataRowCount == other.dataRowCount &&
          _areColumnsEqual(columns, other.columns) &&
          _areIssuesEqual(issues, other.issues);

  @override
  int get hashCode => Object.hash(
    fileName,
    source,
    sheetIndex,
    sheetName,
    headerRowIndex,
    dataRowCount,
    columns.length,
    issues.length,
  );

  static bool _areColumnsEqual(
    List<LeadImportDiscoveredColumn> a,
    List<LeadImportDiscoveredColumn> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _areIssuesEqual(
    List<LeadImportStructureIssue> a,
    List<LeadImportStructureIssue> b,
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
      'LeadImportStructureAnalysis(file: $fileName, sheet: ${sheetName ?? "none"}, headerRow: $headerRowIndex, columns: ${columns.length}, dataRows: $dataRowCount, valid: $isValid)';
}
