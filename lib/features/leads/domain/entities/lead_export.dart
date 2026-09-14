import 'lead_query.dart';

enum LeadExportFormat { excel, csv }

class LeadExportRequest {
  const LeadExportRequest({
    required this.query,
    this.format = LeadExportFormat.excel,
  });

  final LeadQuery query;
  final LeadExportFormat format;
}

class LeadExportResult {
  const LeadExportResult({required this.fileReference, required this.fileName});

  /// An opaque file reference supplied by the repository implementation.
  final Object fileReference;
  final String fileName;
}
