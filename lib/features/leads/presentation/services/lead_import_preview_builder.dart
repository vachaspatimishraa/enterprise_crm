import '../models/lead_import_column_mapping.dart';
import '../models/lead_import_parsed_file.dart';
import '../models/lead_import_preview.dart';
import '../models/lead_import_structure_analysis.dart';
import '../utils/lead_field_validators.dart';

/// Exception thrown when the import workflow configuration artifacts are inconsistent or invalid.
class LeadImportPreviewException implements Exception {
  const LeadImportPreviewException([
    this.message = 'The import configuration is no longer valid.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Service interface for constructing a [LeadImportPreview] from workflow artifacts.
abstract interface class LeadImportPreviewBuilder {
  LeadImportPreview build({
    required LeadImportParsedFile parsedFile,
    required LeadImportStructureAnalysis analysis,
    required LeadImportColumnMapping mapping,
  });
}

/// Default in-memory implementation of [LeadImportPreviewBuilder].
class DefaultLeadImportPreviewBuilder implements LeadImportPreviewBuilder {
  const DefaultLeadImportPreviewBuilder();

  @override
  LeadImportPreview build({
    required LeadImportParsedFile parsedFile,
    required LeadImportStructureAnalysis analysis,
    required LeadImportColumnMapping mapping,
  }) {
    // 1. Verify parsedFile and analysis identity
    if (parsedFile.fileName != analysis.fileName ||
        parsedFile.source != analysis.source) {
      throw const LeadImportPreviewException();
    }

    // 2. Verify analysis has no blocking errors
    if (analysis.hasBlockingErrors) {
      throw const LeadImportPreviewException();
    }

    // 3. Verify sheet index within bounds
    if (analysis.sheetIndex < 0 ||
        analysis.sheetIndex >= parsedFile.sheets.length) {
      throw const LeadImportPreviewException();
    }

    final sheet = parsedFile.sheets[analysis.sheetIndex];

    // 4. Verify analysis.sheetName is non-null and matches actual sheet
    if (analysis.sheetName == null || analysis.sheetName != sheet.name) {
      throw const LeadImportPreviewException();
    }

    // 5. Verify header row index within actual sheet rows bounds
    if (analysis.headerRowIndex < 0 ||
        analysis.headerRowIndex >= sheet.rows.length) {
      throw const LeadImportPreviewException();
    }

    // 6. Verify analysis columns: no negative or duplicate indices
    final analysisColIndices = analysis.columns.map((c) => c.index).toList();
    if (analysisColIndices.any((idx) => idx < 0)) {
      throw const LeadImportPreviewException();
    }
    if (analysisColIndices.toSet().length != analysisColIndices.length) {
      throw const LeadImportPreviewException();
    }

    // 7. Verify mapping metadata matches analysis
    if (mapping.sheetIndex != analysis.sheetIndex ||
        mapping.headerRowIndex != analysis.headerRowIndex) {
      throw const LeadImportPreviewException();
    }

    // 8. Verify mapping has at least one mapped field
    if (!mapping.hasAnyMapping) {
      throw const LeadImportPreviewException();
    }

    // 9. Calculate effective column count across actual sheet
    final effectiveColumnCount = sheet.rows.fold<int>(
      0,
      (maxWidth, row) => row.length > maxWidth ? row.length : maxWidth,
    );

    // 10. Verify mapped column indices are valid and exist in analysis and sheet width
    final analysisColSet = analysisColIndices.toSet();
    final mappedIndicesList = <int>[
      if (mapping.nameColumnIndex != null) mapping.nameColumnIndex!,
      if (mapping.phoneColumnIndex != null) mapping.phoneColumnIndex!,
      if (mapping.emailColumnIndex != null) mapping.emailColumnIndex!,
    ];

    // Ensure no duplicate source column mappings
    if (mappedIndicesList.toSet().length != mappedIndicesList.length) {
      throw const LeadImportPreviewException();
    }

    for (final colIndex in mappedIndicesList) {
      if (colIndex < 0 ||
          colIndex >= effectiveColumnCount ||
          !analysisColSet.contains(colIndex)) {
        throw const LeadImportPreviewException();
      }
    }

    // 11. Process data rows strictly after headerRowIndex
    final previewRows = <LeadImportPreviewRow>[];

    for (var i = analysis.headerRowIndex + 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];

      String? extractMapped(int? colIndex) {
        if (colIndex == null) return null;
        if (colIndex >= row.length) return '';
        return row[colIndex].trim();
      }

      final name = extractMapped(mapping.nameColumnIndex);
      final phone = extractMapped(mapping.phoneColumnIndex);
      final email = extractMapped(mapping.emailColumnIndex);

      final hasName = name != null && name.isNotEmpty;
      final hasPhone = phone != null && phone.isNotEmpty;
      final hasEmail = email != null && email.isNotEmpty;

      if (!hasName && !hasPhone && !hasEmail) {
        // Blank row: none of the mapped fields have content
        previewRows.add(
          LeadImportPreviewRow(
            sourceRowIndex: i,
            name: name,
            phone: phone,
            email: email,
            status: LeadImportPreviewRowStatus.blank,
            issues: const [
              LeadImportPreviewIssue(
                field: null,
                severity: LeadImportPreviewIssueSeverity.warning,
                message: 'No mapped Lead values were found in this row.',
              ),
            ],
          ),
        );
      } else {
        final issues = <LeadImportPreviewIssue>[];
        var isRowValid = true;

        if (hasEmail) {
          if (!isValidOptionalLeadEmail(email)) {
            isRowValid = false;
            issues.add(
              const LeadImportPreviewIssue(
                field: LeadImportTargetField.email,
                severity: LeadImportPreviewIssueSeverity.error,
                message: 'Invalid email address.',
              ),
            );
          }
        }

        previewRows.add(
          LeadImportPreviewRow(
            sourceRowIndex: i,
            name: name,
            phone: phone,
            email: email,
            status: isRowValid
                ? LeadImportPreviewRowStatus.valid
                : LeadImportPreviewRowStatus.invalid,
            issues: List.unmodifiable(issues),
          ),
        );
      }
    }

    return LeadImportPreview(
      fileName: parsedFile.fileName,
      source: parsedFile.source,
      sheetIndex: analysis.sheetIndex,
      sheetName: sheet.name,
      headerRowIndex: analysis.headerRowIndex,
      mapping: mapping,
      rows: List.unmodifiable(previewRows),
    );
  }
}
