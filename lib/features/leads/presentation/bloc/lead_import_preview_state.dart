import '../models/lead_import_preview.dart';

/// Base state for the Lead import row preview stage.
sealed class LeadImportPreviewState {
  const LeadImportPreviewState();
}

/// Initial state before preview construction begins.
class LeadImportPreviewInitial extends LeadImportPreviewState {
  const LeadImportPreviewInitial();
}

/// Ready state containing the successfully built [LeadImportPreview].
class LeadImportPreviewReady extends LeadImportPreviewState {
  const LeadImportPreviewReady(this.preview);

  final LeadImportPreview preview;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportPreviewReady &&
          runtimeType == other.runtimeType &&
          preview == other.preview;

  @override
  int get hashCode => preview.hashCode;
}

/// Failure state when import workflow configuration is invalid.
class LeadImportPreviewFailure extends LeadImportPreviewState {
  const LeadImportPreviewFailure(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportPreviewFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}
