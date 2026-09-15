import '../models/lead_import_parsed_file.dart';
import '../models/lead_import_structure_analysis.dart';

/// Service interface for analyzing spreadsheet structure and discovering columns.
abstract interface class LeadImportStructureAnalyzer {
  LeadImportStructureAnalysis analyze({
    required LeadImportParsedFile parsedFile,
    required int sheetIndex,
    required int headerRowIndex,
  });
}

/// Default in-memory implementation of [LeadImportStructureAnalyzer].
class DefaultLeadImportStructureAnalyzer
    implements LeadImportStructureAnalyzer {
  const DefaultLeadImportStructureAnalyzer();

  @override
  LeadImportStructureAnalysis analyze({
    required LeadImportParsedFile parsedFile,
    required int sheetIndex,
    required int headerRowIndex,
  }) {
    final issues = <LeadImportStructureIssue>[];

    // 1. Validate workbook has sheets
    if (parsedFile.sheets.isEmpty) {
      issues.add(
        const LeadImportStructureIssue(
          severity: LeadImportStructureIssueSeverity.error,
          message: 'No worksheets were found in this file.',
        ),
      );
      return LeadImportStructureAnalysis(
        fileName: parsedFile.fileName,
        source: parsedFile.source,
        sheetIndex: sheetIndex,
        sheetName: '',
        headerRowIndex: headerRowIndex,
        columns: const [],
        dataRowCount: 0,
        issues: List.unmodifiable(issues),
      );
    }

    // 2. Validate sheet index
    if (sheetIndex < 0 || sheetIndex >= parsedFile.sheets.length) {
      issues.add(
        const LeadImportStructureIssue(
          severity: LeadImportStructureIssueSeverity.error,
          message: 'The selected worksheet is not available.',
        ),
      );
      return LeadImportStructureAnalysis(
        fileName: parsedFile.fileName,
        source: parsedFile.source,
        sheetIndex: sheetIndex,
        sheetName: '',
        headerRowIndex: headerRowIndex,
        columns: const [],
        dataRowCount: 0,
        issues: List.unmodifiable(issues),
      );
    }

    final sheet = parsedFile.sheets[sheetIndex];

    // 3. Validate sheet is not empty
    if (sheet.rows.isEmpty) {
      issues.add(
        const LeadImportStructureIssue(
          severity: LeadImportStructureIssueSeverity.error,
          message: 'The selected sheet is empty.',
        ),
      );
      return LeadImportStructureAnalysis(
        fileName: parsedFile.fileName,
        source: parsedFile.source,
        sheetIndex: sheetIndex,
        sheetName: sheet.name,
        headerRowIndex: headerRowIndex,
        columns: const [],
        dataRowCount: 0,
        issues: List.unmodifiable(issues),
      );
    }

    // 4. Validate header row index
    if (headerRowIndex < 0 || headerRowIndex >= sheet.rows.length) {
      issues.add(
        const LeadImportStructureIssue(
          severity: LeadImportStructureIssueSeverity.error,
          message: 'The selected header row is not available.',
        ),
      );
      return LeadImportStructureAnalysis(
        fileName: parsedFile.fileName,
        source: parsedFile.source,
        sheetIndex: sheetIndex,
        sheetName: sheet.name,
        headerRowIndex: headerRowIndex,
        columns: const [],
        dataRowCount: 0,
        issues: List.unmodifiable(issues),
      );
    }

    final headerRow = sheet.rows[headerRowIndex];

    // 5. Validate header row has meaningful cells
    if (headerRow.isEmpty || headerRow.every((cell) => cell.trim().isEmpty)) {
      issues.add(
        const LeadImportStructureIssue(
          severity: LeadImportStructureIssueSeverity.error,
          message: 'The selected header row is empty.',
        ),
      );
      return LeadImportStructureAnalysis(
        fileName: parsedFile.fileName,
        source: parsedFile.source,
        sheetIndex: sheetIndex,
        sheetName: sheet.name,
        headerRowIndex: headerRowIndex,
        columns: const [],
        dataRowCount: 0,
        issues: List.unmodifiable(issues),
      );
    }

    // 6. Discover columns by index
    final columns = <LeadImportDiscoveredColumn>[];
    for (var i = 0; i < headerRow.length; i++) {
      final rawHeader = headerRow[i];
      final trimmed = rawHeader.trim();
      final displayHeader = trimmed.isNotEmpty ? trimmed : 'Column ${i + 1}';

      columns.add(
        LeadImportDiscoveredColumn(
          index: i,
          rawHeader: rawHeader,
          displayHeader: displayHeader,
        ),
      );
    }

    // 7. Check for blank header warnings
    for (final col in columns) {
      if (col.isBlankHeader) {
        issues.add(
          LeadImportStructureIssue(
            severity: LeadImportStructureIssueSeverity.warning,
            message: 'Blank header at column ${col.index + 1}.',
          ),
        );
      }
    }

    // 8. Check for duplicate header warnings (case-insensitive, trimmed)
    final seenHeaders = <String, String>{}; // normalized -> display
    final duplicateHeaders = <String>{};

    for (final col in columns) {
      if (col.isBlankHeader) continue;
      final normalized = col.rawHeader.trim().toLowerCase();
      if (seenHeaders.containsKey(normalized)) {
        duplicateHeaders.add(seenHeaders[normalized]!);
      } else {
        seenHeaders[normalized] = col.displayHeader;
      }
    }

    for (final dup in duplicateHeaders) {
      issues.add(
        LeadImportStructureIssue(
          severity: LeadImportStructureIssueSeverity.warning,
          message: 'Duplicate column name: "$dup".',
        ),
      );
    }

    // 9. Compute data rows count
    final dataRowCount = sheet.rows.length - 1 - headerRowIndex;
    if (dataRowCount <= 0) {
      issues.add(
        const LeadImportStructureIssue(
          severity: LeadImportStructureIssueSeverity.error,
          message: 'No data rows were found below the selected header.',
        ),
      );
    }

    return LeadImportStructureAnalysis(
      fileName: parsedFile.fileName,
      source: parsedFile.source,
      sheetIndex: sheetIndex,
      sheetName: sheet.name,
      headerRowIndex: headerRowIndex,
      columns: List.unmodifiable(columns),
      dataRowCount: dataRowCount < 0 ? 0 : dataRowCount,
      issues: List.unmodifiable(issues),
    );
  }
}
