import 'package:flutter/foundation.dart';

import '../models/lead_import_preview.dart';
import '../models/lead_import_review.dart';

/// State of the final review stage before Lead import execution.
class LeadImportReviewState {
  LeadImportReviewState({
    required this.preview,
    required List<LeadImportExactDuplicateGroup> duplicateGroups,
    required Set<int> includedSourceRowIndices,
  }) : duplicateGroups = List.unmodifiable(duplicateGroups),
       includedSourceRowIndices = Set.unmodifiable(includedSourceRowIndices);

  final LeadImportPreview preview;

  /// Detected exact duplicate groups in the uploaded file, ordered by first source row occurrence.
  final List<LeadImportExactDuplicateGroup> duplicateGroups;

  /// Set of source row indices of valid candidate rows selected for import.
  final Set<int> includedSourceRowIndices;

  /// Lookup map from sourceRowIndex to its duplicate group if any.
  late final Map<int, LeadImportExactDuplicateGroup>
  _duplicateGroupBySourceIndex = {
    for (final group in duplicateGroups)
      for (final idx in group.sourceRowIndices) idx: group,
  };

  /// Returns the duplicate group for a given [sourceRowIndex], or `null` if the row is unique.
  LeadImportExactDuplicateGroup? duplicateGroupFor(int sourceRowIndex) =>
      _duplicateGroupBySourceIndex[sourceRowIndex];

  /// Total count of valid preview rows currently selected for import.
  int get includedValidRowCount => includedSourceRowIndices.length;

  /// Count of valid preview rows currently excluded from import.
  int get excludedValidRowCount =>
      preview.validRowCount - includedValidRowCount;

  /// Number of distinct exact duplicate groups identified in the file.
  int get duplicateGroupCount => duplicateGroups.length;

  /// Total count of candidate rows belonging to any exact duplicate group.
  int get rowsInDuplicateGroups =>
      duplicateGroups.fold<int>(0, (sum, g) => sum + g.sourceRowIndices.length);

  /// Whether the user can proceed to import execution (at least one valid row is selected).
  bool get canContinue => includedSourceRowIndices.isNotEmpty;

  LeadImportReviewState copyWith({
    LeadImportPreview? preview,
    List<LeadImportExactDuplicateGroup>? duplicateGroups,
    Set<int>? includedSourceRowIndices,
  }) {
    return LeadImportReviewState(
      preview: preview ?? this.preview,
      duplicateGroups: duplicateGroups ?? this.duplicateGroups,
      includedSourceRowIndices:
          includedSourceRowIndices ?? this.includedSourceRowIndices,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportReviewState &&
          runtimeType == other.runtimeType &&
          preview == other.preview &&
          listEquals(duplicateGroups, other.duplicateGroups) &&
          setEquals(includedSourceRowIndices, other.includedSourceRowIndices);

  @override
  int get hashCode => Object.hash(
    preview,
    Object.hashAll(duplicateGroups),
    Object.hashAllUnordered(includedSourceRowIndices),
  );

  @override
  String toString() =>
      'LeadImportReviewState(total: ${preview.totalRowCount}, valid: ${preview.validRowCount}, included: $includedValidRowCount, duplicateGroups: $duplicateGroupCount)';
}
