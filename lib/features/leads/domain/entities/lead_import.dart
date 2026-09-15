import 'lead_draft.dart';

enum LeadImportFileType { excel, csv }

class LeadImportRequest {
  const LeadImportRequest({
    required Object this.fileReference,
    required this.fileName,
    required this.fileType,
  }) : drafts = const [];

  const LeadImportRequest._({
    required this.fileReference,
    required this.fileName,
    required this.fileType,
    required this.drafts,
  });

  factory LeadImportRequest.fromDrafts({
    required String fileName,
    required LeadImportFileType fileType,
    required List<LeadDraft> drafts,
  }) {
    if (drafts.isEmpty) {
      throw ArgumentError.value(
        drafts,
        'drafts',
        'Structured import requires at least one Lead draft.',
      );
    }

    return LeadImportRequest._(
      fileReference: null,
      fileName: fileName,
      fileType: fileType,
      drafts: List<LeadDraft>.unmodifiable(drafts),
    );
  }

  /// An opaque file reference. Null when using structured reviewed drafts.
  final Object? fileReference;
  final String fileName;
  final LeadImportFileType fileType;
  final List<LeadDraft> drafts;

  bool get hasDraftPayload => drafts.isNotEmpty;
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
