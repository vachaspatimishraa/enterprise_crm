import '../../domain/entities/lead_source.dart';
import 'lead_import_column_mapping.dart';

/// Row-level status classification for prospective import rows.
enum LeadImportPreviewRowStatus { valid, invalid, blank }

/// Severity level of an issue identified on an import preview row.
enum LeadImportPreviewIssueSeverity { warning, error }

/// Issue associated with a specific prospective import row or field.
class LeadImportPreviewIssue {
  const LeadImportPreviewIssue({
    this.field,
    required this.severity,
    required this.message,
  });

  final LeadImportTargetField? field;
  final LeadImportPreviewIssueSeverity severity;
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportPreviewIssue &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          severity == other.severity &&
          message == other.message;

  @override
  int get hashCode => Object.hash(field, severity, message);

  @override
  String toString() => 'LeadImportPreviewIssue($field, $severity: $message)';
}

/// Normalized candidate Lead data for a single spreadsheet data row.
class LeadImportPreviewRow {
  const LeadImportPreviewRow({
    required this.sourceRowIndex,
    this.name,
    this.phone,
    this.email,
    required this.status,
    this.issues = const [],
  });

  /// Zero-based row index in the original parsed worksheet.
  final int sourceRowIndex;

  /// User-friendly 1-based display row number (always `sourceRowIndex + 1`).
  int get displayRowNumber => sourceRowIndex + 1;

  /// Candidate Lead name. Null if [LeadImportTargetField.name] is unmapped;
  /// empty string if mapped but cell is blank.
  final String? name;

  /// Candidate Lead phone. Null if [LeadImportTargetField.phone] is unmapped;
  /// empty string if mapped but cell is blank.
  final String? phone;

  /// Candidate Lead email. Null if [LeadImportTargetField.email] is unmapped;
  /// empty string if mapped but cell is blank.
  final String? email;

  final LeadImportPreviewRowStatus status;
  final List<LeadImportPreviewIssue> issues;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportPreviewRow &&
          runtimeType == other.runtimeType &&
          sourceRowIndex == other.sourceRowIndex &&
          name == other.name &&
          phone == other.phone &&
          email == other.email &&
          status == other.status &&
          _areIssuesEqual(issues, other.issues);

  @override
  int get hashCode =>
      Object.hash(sourceRowIndex, name, phone, email, status, issues.length);

  static bool _areIssuesEqual(
    List<LeadImportPreviewIssue> a,
    List<LeadImportPreviewIssue> b,
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
      'LeadImportPreviewRow(row: $displayRowNumber, name: "$name", phone: "$phone", email: "$email", status: $status)';
}

/// Result of evaluating candidate data rows against mapped Lead fields.
class LeadImportPreview {
  const LeadImportPreview({
    required this.fileName,
    required this.source,
    required this.sheetIndex,
    required this.sheetName,
    required this.headerRowIndex,
    required this.mapping,
    required this.rows,
  });

  final String fileName;
  final LeadSource source;
  final int sheetIndex;
  final String sheetName;
  final int headerRowIndex;
  final LeadImportColumnMapping mapping;
  final List<LeadImportPreviewRow> rows;

  /// Total count of candidate data rows evaluated.
  int get totalRowCount => rows.length;

  /// Count of valid rows ready for import.
  int get validRowCount =>
      rows.where((r) => r.status == LeadImportPreviewRowStatus.valid).length;

  /// Count of invalid rows with validation errors.
  int get invalidRowCount =>
      rows.where((r) => r.status == LeadImportPreviewRowStatus.invalid).length;

  /// Count of rows with zero mapped Lead values.
  int get blankRowCount =>
      rows.where((r) => r.status == LeadImportPreviewRowStatus.blank).length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportPreview &&
          runtimeType == other.runtimeType &&
          fileName == other.fileName &&
          source == other.source &&
          sheetIndex == other.sheetIndex &&
          sheetName == other.sheetName &&
          headerRowIndex == other.headerRowIndex &&
          mapping == other.mapping &&
          _areRowsEqual(rows, other.rows);

  @override
  int get hashCode => Object.hash(
    fileName,
    source,
    sheetIndex,
    sheetName,
    headerRowIndex,
    mapping,
    rows.length,
  );

  static bool _areRowsEqual(
    List<LeadImportPreviewRow> a,
    List<LeadImportPreviewRow> b,
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
      'LeadImportPreview(file: $fileName, sheet: $sheetName, total: $totalRowCount, valid: $validRowCount, invalid: $invalidRowCount, blank: $blankRowCount)';
}
