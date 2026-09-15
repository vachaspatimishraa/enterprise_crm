import '../models/lead_import_column_mapping.dart';
import '../models/lead_import_parsed_file.dart';
import '../models/lead_import_preview.dart';
import '../models/lead_import_review.dart';
import '../models/lead_import_selected_file.dart';
import '../models/lead_import_structure_analysis.dart';

/// Steps in the Lead import workflow.
enum LeadImportWorkflowStep {
  selectFile,
  parsing,
  structure,
  mapping,
  preview,
  review,
  execution,
}

/// State for the Lead Import workflow coordinator.
class LeadImportWorkflowState {
  const LeadImportWorkflowState({
    this.step = LeadImportWorkflowStep.selectFile,
    this.selectedFile,
    this.parsedFile,
    this.structureAnalysis,
    this.columnMapping,
    this.preview,
    this.reviewDecision,
    this.parseErrorMessage,
  });

  final LeadImportWorkflowStep step;
  final LeadImportSelectedFile? selectedFile;
  final LeadImportParsedFile? parsedFile;
  final LeadImportStructureAnalysis? structureAnalysis;
  final LeadImportColumnMapping? columnMapping;
  final LeadImportPreview? preview;
  final LeadImportReviewDecision? reviewDecision;
  final String? parseErrorMessage;

  LeadImportWorkflowState copyWith({
    LeadImportWorkflowStep? step,
    LeadImportSelectedFile? selectedFile,
    LeadImportParsedFile? parsedFile,
    LeadImportStructureAnalysis? structureAnalysis,
    LeadImportColumnMapping? columnMapping,
    LeadImportPreview? preview,
    LeadImportReviewDecision? reviewDecision,
    String? parseErrorMessage,
    bool clearSelectedFile = false,
    bool clearParsedFile = false,
    bool clearStructureAnalysis = false,
    bool clearColumnMapping = false,
    bool clearPreview = false,
    bool clearReviewDecision = false,
    bool clearParseErrorMessage = false,
  }) {
    return LeadImportWorkflowState(
      step: step ?? this.step,
      selectedFile: clearSelectedFile
          ? null
          : (selectedFile ?? this.selectedFile),
      parsedFile: clearParsedFile ? null : (parsedFile ?? this.parsedFile),
      structureAnalysis: clearStructureAnalysis
          ? null
          : (structureAnalysis ?? this.structureAnalysis),
      columnMapping: clearColumnMapping
          ? null
          : (columnMapping ?? this.columnMapping),
      preview: clearPreview ? null : (preview ?? this.preview),
      reviewDecision: clearReviewDecision
          ? null
          : (reviewDecision ?? this.reviewDecision),
      parseErrorMessage: clearParseErrorMessage
          ? null
          : (parseErrorMessage ?? this.parseErrorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportWorkflowState &&
          runtimeType == other.runtimeType &&
          step == other.step &&
          selectedFile == other.selectedFile &&
          parsedFile == other.parsedFile &&
          structureAnalysis == other.structureAnalysis &&
          columnMapping == other.columnMapping &&
          preview == other.preview &&
          reviewDecision == other.reviewDecision &&
          parseErrorMessage == other.parseErrorMessage;

  @override
  int get hashCode => Object.hash(
    step,
    selectedFile,
    parsedFile,
    structureAnalysis,
    columnMapping,
    preview,
    reviewDecision,
    parseErrorMessage,
  );

  @override
  String toString() =>
      'LeadImportWorkflowState(step: $step, file: ${selectedFile?.name}, parsed: ${parsedFile != null}, structure: ${structureAnalysis != null}, mapping: ${columnMapping != null}, preview: ${preview != null}, decision: ${reviewDecision != null}, parseError: $parseErrorMessage)';
}
