import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/lead_import_preview.dart';
import '../models/lead_import_review.dart';
import '../services/lead_import_duplicate_detector.dart';
import 'lead_import_review_state.dart';

class LeadImportReviewCubit extends Cubit<LeadImportReviewState> {
  LeadImportReviewCubit({
    required LeadImportPreview preview,
    LeadImportDuplicateDetector? duplicateDetector,
  }) : _validRowIndices = Set.unmodifiable({
         for (final row in preview.rows)
           if (row.status == LeadImportPreviewRowStatus.valid)
             row.sourceRowIndex,
       }),
       super(
         _createInitialState(
           preview: preview,
           detector:
               duplicateDetector ?? const DefaultLeadImportDuplicateDetector(),
         ),
       );

  final Set<int> _validRowIndices;

  static LeadImportReviewState _createInitialState({
    required LeadImportPreview preview,
    required LeadImportDuplicateDetector detector,
  }) {
    final duplicateGroups = detector.detect(preview);
    final initialIncluded = {
      for (final row in preview.rows)
        if (row.status == LeadImportPreviewRowStatus.valid) row.sourceRowIndex,
    };

    return LeadImportReviewState(
      preview: preview,
      duplicateGroups: duplicateGroups,
      includedSourceRowIndices: initialIncluded,
    );
  }

  /// Sets the inclusion status of candidate row identified by [sourceRowIndex].
  ///
  /// Requests targeting invalid, blank, or unknown rows are safely ignored.
  void setIncluded({required int sourceRowIndex, required bool included}) {
    if (!_validRowIndices.contains(sourceRowIndex)) {
      return;
    }

    final current = state.includedSourceRowIndices;
    if (included && current.contains(sourceRowIndex)) return;
    if (!included && !current.contains(sourceRowIndex)) return;

    final updated = Set<int>.from(current);
    if (included) {
      updated.add(sourceRowIndex);
    } else {
      updated.remove(sourceRowIndex);
    }

    emit(state.copyWith(includedSourceRowIndices: updated));
  }

  /// Toggles the inclusion status of valid candidate row identified by [sourceRowIndex].
  ///
  /// Requests targeting invalid, blank, or unknown rows are safely ignored.
  void toggleRow(int sourceRowIndex) {
    if (!_validRowIndices.contains(sourceRowIndex)) {
      return;
    }
    setIncluded(
      sourceRowIndex: sourceRowIndex,
      included: !state.includedSourceRowIndices.contains(sourceRowIndex),
    );
  }

  /// Selects all valid preview rows for import.
  void includeAllValid() {
    emit(state.copyWith(includedSourceRowIndices: _validRowIndices));
  }

  /// Excludes all valid preview rows from import, setting selection to empty.
  void excludeAllValid() {
    emit(state.copyWith(includedSourceRowIndices: const <int>{}));
  }

  /// Creates an immutable [LeadImportReviewDecision] from current selections.
  LeadImportReviewDecision createDecision() {
    return LeadImportReviewDecision(state.includedSourceRowIndices);
  }
}
