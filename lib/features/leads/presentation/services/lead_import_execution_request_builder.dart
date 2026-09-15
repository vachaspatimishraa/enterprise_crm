import '../../domain/entities/lead_draft.dart';
import '../../domain/entities/lead_import.dart';
import '../../domain/entities/lead_source.dart';
import '../models/lead_import_preview.dart';
import '../models/lead_import_review.dart';

/// Exception thrown when preparing an execution request from preview and review
/// decisions fails due to invalid or inconsistent inputs.
class LeadImportExecutionPreparationException implements Exception {
  const LeadImportExecutionPreparationException([
    this.message = 'The selected import rows are no longer valid.',
  ]);

  final String message;

  @override
  String toString() => 'LeadImportExecutionPreparationException: $message';
}

/// Prepares a domain [LeadImportRequest] with structured [LeadDraft] items
/// from a validated [LeadImportPreview] and user [LeadImportReviewDecision].
abstract interface class LeadImportExecutionRequestBuilder {
  LeadImportRequest build({
    required LeadImportPreview preview,
    required LeadImportReviewDecision decision,
  });
}

class DefaultLeadImportExecutionRequestBuilder
    implements LeadImportExecutionRequestBuilder {
  const DefaultLeadImportExecutionRequestBuilder();

  @override
  LeadImportRequest build({
    required LeadImportPreview preview,
    required LeadImportReviewDecision decision,
  }) {
    if (decision.includedSourceRowIndices.isEmpty) {
      throw const LeadImportExecutionPreparationException(
        'The selected import rows are no longer valid.',
      );
    }

    final LeadImportFileType fileType;
    switch (preview.source) {
      case LeadSource.csv:
        fileType = LeadImportFileType.csv;
        break;
      case LeadSource.excel:
        fileType = LeadImportFileType.excel;
        break;
      case LeadSource.manual:
        throw const LeadImportExecutionPreparationException(
          'The selected import rows are no longer valid.',
        );
    }

    final uniqueSourceIndices = <int>{};
    final rowMap = <int, LeadImportPreviewRow>{};
    for (final row in preview.rows) {
      if (!uniqueSourceIndices.add(row.sourceRowIndex)) {
        throw const LeadImportExecutionPreparationException(
          'The selected import rows are no longer valid.',
        );
      }
      rowMap[row.sourceRowIndex] = row;
    }

    for (final index in decision.includedSourceRowIndices) {
      final row = rowMap[index];
      if (row == null || row.status != LeadImportPreviewRowStatus.valid) {
        throw const LeadImportExecutionPreparationException(
          'The selected import rows are no longer valid.',
        );
      }
    }

    final drafts = <LeadDraft>[];
    for (final row in preview.rows) {
      if (decision.includedSourceRowIndices.contains(row.sourceRowIndex)) {
        drafts.add(
          LeadDraft(
            name: _normalizeOptional(row.name),
            phone: _normalizeOptional(row.phone),
            email: _normalizeOptional(row.email),
            status: null,
            source: preview.source,
          ),
        );
      }
    }

    return LeadImportRequest.fromDrafts(
      fileName: preview.fileName,
      fileType: fileType,
      drafts: drafts,
    );
  }

  String? _normalizeOptional(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
