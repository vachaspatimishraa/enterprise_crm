import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_review_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportReviewCubit', () {
    const testMapping = LeadImportColumnMapping(
      sheetIndex: 0,
      headerRowIndex: 0,
      nameColumnIndex: 0,
      phoneColumnIndex: 1,
    );

    final previewWithMixedRows = LeadImportPreview(
      fileName: 'leads.csv',
      source: LeadSource.csv,
      sheetIndex: 0,
      sheetName: 'CSV',
      headerRowIndex: 0,
      mapping: testMapping,
      rows: const [
        LeadImportPreviewRow(
          sourceRowIndex: 1,
          name: 'Alice',
          phone: '123',
          status: LeadImportPreviewRowStatus.valid,
        ),
        LeadImportPreviewRow(
          sourceRowIndex: 2,
          name: 'Bob',
          phone: '456',
          status: LeadImportPreviewRowStatus.valid,
        ),
        LeadImportPreviewRow(
          sourceRowIndex: 3,
          name: 'Charlie',
          phone: '789',
          status: LeadImportPreviewRowStatus.valid,
        ),
        LeadImportPreviewRow(
          sourceRowIndex: 4,
          name: 'Bad',
          email: 'not-valid',
          status: LeadImportPreviewRowStatus.invalid,
        ),
        LeadImportPreviewRow(
          sourceRowIndex: 5,
          name: '',
          phone: '',
          status: LeadImportPreviewRowStatus.blank,
        ),
      ],
    );

    final previewWithDuplicates = LeadImportPreview(
      fileName: 'leads.csv',
      source: LeadSource.csv,
      sheetIndex: 0,
      sheetName: 'CSV',
      headerRowIndex: 0,
      mapping: testMapping,
      rows: const [
        LeadImportPreviewRow(
          sourceRowIndex: 1,
          name: 'Alice',
          phone: '123',
          status: LeadImportPreviewRowStatus.valid,
        ),
        LeadImportPreviewRow(
          sourceRowIndex: 2,
          name: 'Alice',
          phone: '123',
          status: LeadImportPreviewRowStatus.valid,
        ),
        LeadImportPreviewRow(
          sourceRowIndex: 3,
          name: 'Bob',
          phone: '456',
          status: LeadImportPreviewRowStatus.valid,
        ),
      ],
    );

    test(
      'Section 58: initial state includes all valid rows and excludes invalid/blank rows',
      () {
        final cubit = LeadImportReviewCubit(preview: previewWithMixedRows);

        expect(cubit.state.includedSourceRowIndices, equals({1, 2, 3}));
        expect(cubit.state.includedValidRowCount, equals(3));
        expect(cubit.state.excludedValidRowCount, equals(0));
        expect(cubit.state.canContinue, isTrue);
      },
    );

    test(
      'Section 59: duplicate valid rows remain selected by default without auto-exclusion',
      () {
        final cubit = LeadImportReviewCubit(preview: previewWithDuplicates);

        // Both duplicate rows (1 and 2) must remain selected
        expect(cubit.state.includedSourceRowIndices, equals({1, 2, 3}));
        expect(cubit.state.duplicateGroupCount, equals(1));
        expect(cubit.state.rowsInDuplicateGroups, equals(2));
        expect(cubit.state.includedValidRowCount, equals(3));
      },
    );

    test(
      'Section 60: toggling valid row excludes and includes it accurately',
      () {
        final cubit = LeadImportReviewCubit(preview: previewWithMixedRows);

        // Exclude row 1
        cubit.toggleRow(1);
        expect(cubit.state.includedSourceRowIndices, equals({2, 3}));
        expect(cubit.state.includedValidRowCount, equals(2));
        expect(cubit.state.excludedValidRowCount, equals(1));

        // Include row 1 again
        cubit.toggleRow(1);
        expect(cubit.state.includedSourceRowIndices, equals({1, 2, 3}));
        expect(cubit.state.includedValidRowCount, equals(3));
        expect(cubit.state.excludedValidRowCount, equals(0));
      },
    );

    test(
      'Section 61: attempting to include an invalid row is safely ignored',
      () {
        final cubit = LeadImportReviewCubit(preview: previewWithMixedRows);

        // Row 4 is invalid
        cubit.setIncluded(sourceRowIndex: 4, included: true);

        expect(cubit.state.includedSourceRowIndices, equals({1, 2, 3}));
        expect(cubit.state.includedSourceRowIndices.contains(4), isFalse);
      },
    );

    test('Section 62: attempting to include a blank row is safely ignored', () {
      final cubit = LeadImportReviewCubit(preview: previewWithMixedRows);

      // Row 5 is blank
      cubit.setIncluded(sourceRowIndex: 5, included: true);

      expect(cubit.state.includedSourceRowIndices, equals({1, 2, 3}));
      expect(cubit.state.includedSourceRowIndices.contains(5), isFalse);
    });

    test(
      'Section 63: attempting to toggle or include an unknown row index is safely ignored',
      () {
        final cubit = LeadImportReviewCubit(preview: previewWithMixedRows);

        cubit.setIncluded(sourceRowIndex: 999999, included: true);
        cubit.toggleRow(999999);

        expect(cubit.state.includedSourceRowIndices, equals({1, 2, 3}));
        expect(cubit.state.includedSourceRowIndices.contains(999999), isFalse);
      },
    );

    test(
      'Section 64: includeAllValid restores all valid rows after exclusions',
      () {
        final cubit = LeadImportReviewCubit(preview: previewWithMixedRows);

        cubit.toggleRow(1);
        cubit.toggleRow(2);
        expect(cubit.state.includedSourceRowIndices, equals({3}));

        cubit.includeAllValid();
        expect(cubit.state.includedSourceRowIndices, equals({1, 2, 3}));
        expect(cubit.state.canContinue, isTrue);
      },
    );

    test(
      'Section 65: excludeAllValid clears selection and disables canContinue',
      () {
        final cubit = LeadImportReviewCubit(preview: previewWithMixedRows);

        cubit.excludeAllValid();

        expect(cubit.state.includedSourceRowIndices, isEmpty);
        expect(cubit.state.includedValidRowCount, equals(0));
        expect(cubit.state.excludedValidRowCount, equals(3));
        expect(cubit.state.canContinue, isFalse);
      },
    );

    test('createDecision creates immutable LeadImportReviewDecision', () {
      final cubit = LeadImportReviewCubit(preview: previewWithMixedRows);
      cubit.toggleRow(1);

      final decision = cubit.createDecision();
      expect(decision.includedSourceRowIndices, equals({2, 3}));
    });
  });
}
