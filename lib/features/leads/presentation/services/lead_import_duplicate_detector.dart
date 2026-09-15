import '../models/lead_import_preview.dart';
import '../models/lead_import_review.dart';

/// Service interface for detecting exact duplicate valid candidate rows within
/// an uploaded file preview.
abstract interface class LeadImportDuplicateDetector {
  List<LeadImportExactDuplicateGroup> detect(LeadImportPreview preview);
}

/// Default in-memory implementation of [LeadImportDuplicateDetector].
///
/// Compares only rows with status [LeadImportPreviewRowStatus.valid].
/// An exact duplicate occurs when the candidate tuple `(name, phone, email)`
/// matches exactly across two or more rows in the current file.
/// Case, internal phone characters, and spaces are preserved as-is from L4.5 preview.
class DefaultLeadImportDuplicateDetector
    implements LeadImportDuplicateDetector {
  const DefaultLeadImportDuplicateDetector();

  @override
  List<LeadImportExactDuplicateGroup> detect(LeadImportPreview preview) {
    // Map literal maintains insertion order (first-occurrence order of duplicate groups)
    final groupedIndices = <_CandidateKey, List<int>>{};

    for (final row in preview.rows) {
      if (row.status != LeadImportPreviewRowStatus.valid) {
        continue;
      }

      final key = _CandidateKey(
        name: row.name,
        phone: row.phone,
        email: row.email,
      );

      groupedIndices.putIfAbsent(key, () => <int>[]).add(row.sourceRowIndex);
    }

    final duplicateGroups = <LeadImportExactDuplicateGroup>[];

    for (final indices in groupedIndices.values) {
      if (indices.length >= 2) {
        duplicateGroups.add(LeadImportExactDuplicateGroup(indices));
      }
    }

    return List.unmodifiable(duplicateGroups);
  }
}

class _CandidateKey {
  const _CandidateKey({
    required this.name,
    required this.phone,
    required this.email,
  });

  final String? name;
  final String? phone;
  final String? email;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CandidateKey &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          phone == other.phone &&
          email == other.email;

  @override
  int get hashCode => Object.hash(name, phone, email);
}
