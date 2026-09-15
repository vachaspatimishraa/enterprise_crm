import 'package:flutter/foundation.dart';

/// Represents a group of two or more candidate rows in the uploaded file whose
/// mapped candidate values are exactly identical.
@immutable
class LeadImportExactDuplicateGroup {
  LeadImportExactDuplicateGroup(List<int> sourceRowIndices)
    : assert(
        sourceRowIndices.length >= 2,
        'A duplicate group must contain at least 2 source row indices.',
      ),
      sourceRowIndices = List.unmodifiable([...sourceRowIndices]..sort());

  /// Zero-based row indices in the source worksheet belonging to this exact duplicate group,
  /// sorted in ascending source row order.
  final List<int> sourceRowIndices;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportExactDuplicateGroup &&
          runtimeType == other.runtimeType &&
          listEquals(sourceRowIndices, other.sourceRowIndices);

  @override
  int get hashCode => Object.hashAll(sourceRowIndices);

  @override
  String toString() => 'LeadImportExactDuplicateGroup(rows: $sourceRowIndices)';
}

/// Final user review decision specifying which valid preview rows to include
/// in the upcoming import execution (L4.7).
@immutable
class LeadImportReviewDecision {
  LeadImportReviewDecision(Set<int> includedSourceRowIndices)
    : includedSourceRowIndices = Set.unmodifiable(includedSourceRowIndices);

  /// Zero-based row indices of valid candidate rows selected for import.
  /// Guaranteed to contain only indices of valid preview rows.
  final Set<int> includedSourceRowIndices;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportReviewDecision &&
          runtimeType == other.runtimeType &&
          setEquals(includedSourceRowIndices, other.includedSourceRowIndices);

  @override
  int get hashCode => Object.hashAllUnordered(includedSourceRowIndices);

  @override
  String toString() =>
      'LeadImportReviewDecision(includedCount: ${includedSourceRowIndices.length})';
}
