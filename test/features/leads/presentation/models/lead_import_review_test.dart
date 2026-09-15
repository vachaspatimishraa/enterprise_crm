import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_review_state.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_preview.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportExactDuplicateGroup', () {
    test('sorts sourceRowIndices ascending and makes list unmodifiable', () {
      final group = LeadImportExactDuplicateGroup([8, 2, 5]);

      expect(group.sourceRowIndices, equals([2, 5, 8]));
      expect(
        () => (group.sourceRowIndices as dynamic).add(9),
        throwsUnsupportedError,
      );
    });

    test('asserts if fewer than 2 source row indices provided', () {
      expect(() => LeadImportExactDuplicateGroup([1]), throwsAssertionError);
      expect(() => LeadImportExactDuplicateGroup([]), throwsAssertionError);
    });

    test('equality and hashCode work as expected', () {
      final group1 = LeadImportExactDuplicateGroup([2, 5]);
      final group2 = LeadImportExactDuplicateGroup([5, 2]);
      final group3 = LeadImportExactDuplicateGroup([2, 6]);

      expect(group1, equals(group2));
      expect(group1.hashCode, equals(group2.hashCode));
      expect(group1, isNot(equals(group3)));
      expect(group1.toString(), contains('[2, 5]'));
    });
  });

  group('LeadImportReviewDecision', () {
    test('stores unmodifiable set of included indices', () {
      final decision = LeadImportReviewDecision({1, 3, 5});

      expect(decision.includedSourceRowIndices, equals({1, 3, 5}));
      expect(
        () => (decision.includedSourceRowIndices as dynamic).add(7),
        throwsUnsupportedError,
      );
    });

    test('equality and hashCode work as expected', () {
      final d1 = LeadImportReviewDecision({1, 2});
      final d2 = LeadImportReviewDecision({2, 1});
      final d3 = LeadImportReviewDecision({1});

      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2.hashCode));
      expect(d1, isNot(equals(d3)));
      expect(d1.toString(), contains('includedCount: 2'));
    });
  });

  group('LeadImportReviewState', () {
    const mapping = LeadImportColumnMapping(
      sheetIndex: 0,
      headerRowIndex: 0,
      nameColumnIndex: 0,
    );

    final preview = LeadImportPreview(
      fileName: 'test.csv',
      source: LeadSource.csv,
      sheetIndex: 0,
      sheetName: 'CSV',
      headerRowIndex: 0,
      mapping: mapping,
      rows: const [
        LeadImportPreviewRow(
          sourceRowIndex: 1,
          name: 'Alice',
          status: LeadImportPreviewRowStatus.valid,
        ),
        LeadImportPreviewRow(
          sourceRowIndex: 2,
          name: 'Alice',
          status: LeadImportPreviewRowStatus.valid,
        ),
        LeadImportPreviewRow(
          sourceRowIndex: 3,
          name: 'Bob',
          status: LeadImportPreviewRowStatus.valid,
        ),
        LeadImportPreviewRow(
          sourceRowIndex: 4,
          name: 'InvalidEmail',
          status: LeadImportPreviewRowStatus.invalid,
        ),
        LeadImportPreviewRow(
          sourceRowIndex: 5,
          name: '',
          status: LeadImportPreviewRowStatus.blank,
        ),
      ],
    );

    test('calculates derived metrics accurately', () {
      final duplicateGroup = LeadImportExactDuplicateGroup([1, 2]);
      final state = LeadImportReviewState(
        preview: preview,
        duplicateGroups: [duplicateGroup],
        includedSourceRowIndices: {1, 2},
      );

      expect(state.includedValidRowCount, equals(2));
      expect(
        state.excludedValidRowCount,
        equals(1),
      ); // 3 valid total - 2 included = 1 excluded
      expect(state.duplicateGroupCount, equals(1));
      expect(state.rowsInDuplicateGroups, equals(2));
      expect(state.canContinue, isTrue);

      expect(state.duplicateGroupFor(1), equals(duplicateGroup));
      expect(state.duplicateGroupFor(2), equals(duplicateGroup));
      expect(state.duplicateGroupFor(3), isNull);
    });

    test('canContinue is false when includedSourceRowIndices is empty', () {
      final state = LeadImportReviewState(
        preview: preview,
        duplicateGroups: [],
        includedSourceRowIndices: {},
      );

      expect(state.canContinue, isFalse);
      expect(state.includedValidRowCount, equals(0));
      expect(state.excludedValidRowCount, equals(3));
    });

    test('copyWith updates specified fields correctly', () {
      final state = LeadImportReviewState(
        preview: preview,
        duplicateGroups: [],
        includedSourceRowIndices: {1, 2, 3},
      );

      final updated = state.copyWith(includedSourceRowIndices: {1});

      expect(updated.includedSourceRowIndices, equals({1}));
      expect(updated.preview, equals(preview));
    });
  });
}
