import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/lead_import_column_mapping.dart';
import '../models/lead_import_parsed_file.dart';
import '../models/lead_import_preview.dart';
import '../models/lead_import_review.dart';
import '../models/lead_import_selected_file.dart';
import '../models/lead_import_structure_analysis.dart';
import 'lead_import_workflow_state.dart';

/// Coordinator Cubit managing the high-level progression, navigation,
/// and artifact invalidation across the Lead import stages.
class LeadImportWorkflowCubit extends Cubit<LeadImportWorkflowState> {
  LeadImportWorkflowCubit({LeadImportWorkflowState? initialState})
    : super(initialState ?? const LeadImportWorkflowState());

  /// Called when user confirms a fresh file selection.
  /// ALWAYS clears ALL downstream artifacts unconditionally.
  void selectFileAndParse(LeadImportSelectedFile file) {
    emit(
      state.copyWith(
        step: LeadImportWorkflowStep.parsing,
        selectedFile: file,
        clearParsedFile: true,
        clearStructureAnalysis: true,
        clearColumnMapping: true,
        clearPreview: true,
        clearReviewDecision: true,
        clearParseErrorMessage: true,
      ),
    );
  }

  /// Retries parsing of the SAME selected file.
  /// Preserves [state.selectedFile] without clearing downstream state unnecessarily.
  void retryParsing() {
    if (state.selectedFile == null) return;
    emit(
      state.copyWith(
        step: LeadImportWorkflowStep.parsing,
        clearParseErrorMessage: true,
      ),
    );
  }

  /// Called on successful file parse.
  /// Sets [parsedFile] and advances to Structure stage.
  /// Discards any stale structure/mapping/preview/review artifacts.
  void onParseSuccess(LeadImportParsedFile parsedFile) {
    emit(
      state.copyWith(
        step: LeadImportWorkflowStep.structure,
        parsedFile: parsedFile,
        clearStructureAnalysis: true,
        clearColumnMapping: true,
        clearPreview: true,
        clearReviewDecision: true,
        clearParseErrorMessage: true,
      ),
    );
  }

  /// Called when parsing fails.
  /// Keeps step at parsing and displays the error message.
  void onParseFailure(String message) {
    emit(
      state.copyWith(
        step: LeadImportWorkflowStep.parsing,
        parseErrorMessage: message,
      ),
    );
  }

  /// Called when the user confirms structure (sheet & header row).
  /// Invariants: parsedFile must not be null.
  /// If structure changed, clears downstream: columnMapping, preview, reviewDecision.
  void onStructureConfirmed(LeadImportStructureAnalysis analysis) {
    if (state.parsedFile == null) return;
    final changed = state.structureAnalysis != analysis;
    emit(
      state.copyWith(
        step: LeadImportWorkflowStep.mapping,
        structureAnalysis: analysis,
        clearColumnMapping: changed,
        clearPreview: changed,
        clearReviewDecision: changed,
      ),
    );
  }

  /// Called when the user confirms column mapping.
  /// Invariants: structureAnalysis must not be null.
  /// If mapping changed, clears downstream: preview, reviewDecision.
  void onMappingConfirmed(LeadImportColumnMapping mapping) {
    if (state.structureAnalysis == null) return;
    final changed = state.columnMapping != mapping;
    emit(
      state.copyWith(
        step: LeadImportWorkflowStep.preview,
        columnMapping: mapping,
        clearPreview: changed,
        clearReviewDecision: changed,
      ),
    );
  }

  /// Called when preview is generated and confirmed.
  /// Invariants: columnMapping must not be null.
  /// If preview changed, clears downstream: reviewDecision.
  void onPreviewConfirmed(LeadImportPreview preview) {
    if (state.columnMapping == null) return;
    final changed = state.preview != preview;
    emit(
      state.copyWith(
        step: LeadImportWorkflowStep.review,
        preview: preview,
        clearReviewDecision: changed,
      ),
    );
  }

  /// Called when review decision is confirmed.
  /// Invariants: preview must not be null.
  /// Advances to execution.
  void onReviewConfirmed(LeadImportReviewDecision decision) {
    if (state.preview == null) return;
    emit(
      state.copyWith(
        step: LeadImportWorkflowStep.execution,
        reviewDecision: decision,
      ),
    );
  }

  // --- Back navigation methods ---

  /// Returns to file selection from parsing or structure.
  void backToFileSelection() {
    emit(
      state.copyWith(
        step: LeadImportWorkflowStep.selectFile,
        clearParseErrorMessage: true,
      ),
    );
  }

  /// Returns to structure from mapping.
  void backToStructure() {
    if (state.parsedFile == null) {
      backToFileSelection();
      return;
    }
    emit(state.copyWith(step: LeadImportWorkflowStep.structure));
  }

  /// Returns to mapping from preview.
  void backToMapping() {
    if (state.structureAnalysis == null) {
      backToStructure();
      return;
    }
    emit(state.copyWith(step: LeadImportWorkflowStep.mapping));
  }

  /// Returns to preview from review.
  void backToPreview() {
    if (state.columnMapping == null) {
      backToMapping();
      return;
    }
    emit(state.copyWith(step: LeadImportWorkflowStep.preview));
  }

  /// Returns to review from execution failure.
  void backToReview() {
    if (state.preview == null) {
      backToPreview();
      return;
    }
    emit(state.copyWith(step: LeadImportWorkflowStep.review));
  }

  /// Resets the workflow state to initial.
  void reset() {
    emit(const LeadImportWorkflowState());
  }
}
