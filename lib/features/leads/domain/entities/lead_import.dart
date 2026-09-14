enum LeadImportFileType { excel, csv }

class LeadImportRequest {
  const LeadImportRequest({
    required this.fileReference,
    required this.fileName,
    required this.fileType,
  });

  /// An opaque file reference. File-picker and transport details stay outside
  /// the domain contract.
  final Object fileReference;
  final String fileName;
  final LeadImportFileType fileType;
}

class LeadImportResult {
  const LeadImportResult({
    required this.totalRows,
    required this.importedRows,
    required this.skippedRows,
    required this.failedRows,
    required this.duplicateRows,
  });

  final int totalRows;
  final int importedRows;
  final int skippedRows;
  final int failedRows;
  final int duplicateRows;
}
