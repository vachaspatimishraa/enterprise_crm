import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_preview.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_review.dart';
import 'package:enterprise_crm/features/leads/presentation/services/lead_import_execution_request_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = DefaultLeadImportExecutionRequestBuilder();

  LeadImportPreview createSamplePreview({
    LeadSource source = LeadSource.csv,
    String fileName = 'test_leads.csv',
    List<LeadImportPreviewRow>? rows,
  }) {
    return LeadImportPreview(
      fileName: fileName,
      source: source,
      sheetIndex: 0,
      sheetName: 'Sheet1',
      headerRowIndex: 0,
      mapping: const LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
        phoneColumnIndex: 1,
        emailColumnIndex: 2,
      ),
      rows:
          rows ??
          [
            const LeadImportPreviewRow(
              sourceRowIndex: 1,
              name: 'Aarav Sharma',
              phone: '+91 9876543210',
              email: 'aarav@example.com',
              status: LeadImportPreviewRowStatus.valid,
            ),
            const LeadImportPreviewRow(
              sourceRowIndex: 2,
              name: 'Pooja Verma',
              phone: '+91 9811122233',
              email: 'pooja@example.com',
              status: LeadImportPreviewRowStatus.valid,
            ),
            const LeadImportPreviewRow(
              sourceRowIndex: 3,
              name: 'Rohan Mehta',
              phone: null,
              email: 'rohan@example.com',
              status: LeadImportPreviewRowStatus.valid,
            ),
          ],
    );
  }

  group('DefaultLeadImportExecutionRequestBuilder', () {
    test(
      'CSV preview maps to CSV fileType and Excel preview maps to Excel fileType',
      () {
        final csvPreview = createSamplePreview(
          source: LeadSource.csv,
          fileName: 'data.csv',
        );
        final excelPreview = createSamplePreview(
          source: LeadSource.excel,
          fileName: 'data.xlsx',
        );
        final decision = LeadImportReviewDecision({1});

        final csvRequest = builder.build(
          preview: csvPreview,
          decision: decision,
        );
        final excelRequest = builder.build(
          preview: excelPreview,
          decision: decision,
        );

        expect(csvRequest.fileType, equals(LeadImportFileType.csv));
        expect(excelRequest.fileType, equals(LeadImportFileType.excel));
      },
    );

    test('preserves fileName metadata and sets fileReference to null', () {
      final preview = createSamplePreview(fileName: 'custom_leads.csv');
      final decision = LeadImportReviewDecision({1});

      final request = builder.build(preview: preview, decision: decision);

      expect(request.fileName, equals('custom_leads.csv'));
      expect(request.fileReference, isNull);
    });

    test(
      'converts only selected valid rows and preserves source row order',
      () {
        final preview = LeadImportPreview(
          fileName: 'leads.csv',
          source: LeadSource.csv,
          sheetIndex: 0,
          sheetName: 'Sheet1',
          headerRowIndex: 0,
          mapping: const LeadImportColumnMapping(
            sheetIndex: 0,
            headerRowIndex: 0,
            nameColumnIndex: 0,
          ),
          rows: const [
            LeadImportPreviewRow(
              sourceRowIndex: 2,
              name: 'Row 2',
              status: LeadImportPreviewRowStatus.valid,
            ),
            LeadImportPreviewRow(
              sourceRowIndex: 3,
              name: 'Row 3',
              status: LeadImportPreviewRowStatus.valid,
            ),
            LeadImportPreviewRow(
              sourceRowIndex: 4,
              name: 'Row 4',
              status: LeadImportPreviewRowStatus.valid,
            ),
            LeadImportPreviewRow(
              sourceRowIndex: 5,
              name: 'Row 5',
              status: LeadImportPreviewRowStatus.valid,
            ),
          ],
        );

        // Decision set has order {4, 2}
        final decision = LeadImportReviewDecision({4, 2});

        final request = builder.build(preview: preview, decision: decision);

        expect(request.drafts.length, equals(2));
        // Preserves preview source order: row 2 then row 4
        expect(request.drafts[0].name, equals('Row 2'));
        expect(request.drafts[1].name, equals('Row 4'));
      },
    );

    test(
      'normalizes empty strings and nulls to null, preserving non-empty values',
      () {
        final preview = LeadImportPreview(
          fileName: 'leads.csv',
          source: LeadSource.csv,
          sheetIndex: 0,
          sheetName: 'Sheet1',
          headerRowIndex: 0,
          mapping: const LeadImportColumnMapping(
            sheetIndex: 0,
            headerRowIndex: 0,
            nameColumnIndex: 0,
            phoneColumnIndex: 1,
            emailColumnIndex: 2,
          ),
          rows: const [
            LeadImportPreviewRow(
              sourceRowIndex: 1,
              name: 'Valid Name',
              phone: '', // mapped but empty
              email: null, // unmapped
              status: LeadImportPreviewRowStatus.valid,
            ),
          ],
        );

        final decision = LeadImportReviewDecision({1});
        final request = builder.build(preview: preview, decision: decision);

        expect(request.drafts.length, equals(1));
        final draft = request.drafts.first;
        expect(draft.name, equals('Valid Name'));
        expect(draft.phone, isNull);
        expect(draft.email, isNull);
        expect(draft.status, isNull);
        expect(draft.source, equals(LeadSource.csv));
      },
    );

    test('status is null on all generated drafts', () {
      final preview = createSamplePreview();
      final decision = LeadImportReviewDecision({1, 2, 3});

      final request = builder.build(preview: preview, decision: decision);

      for (final draft in request.drafts) {
        expect(draft.status, isNull);
      }
    });

    test(
      'draft source matches preview source (csv / excel) and never defaults to manual',
      () {
        final csvPreview = createSamplePreview(source: LeadSource.csv);
        final excelPreview = createSamplePreview(source: LeadSource.excel);
        final decision = LeadImportReviewDecision({1});

        final csvRequest = builder.build(
          preview: csvPreview,
          decision: decision,
        );
        final excelRequest = builder.build(
          preview: excelPreview,
          decision: decision,
        );

        expect(csvRequest.drafts.first.source, equals(LeadSource.csv));
        expect(excelRequest.drafts.first.source, equals(LeadSource.excel));
      },
    );

    test(
      'selected exact duplicate rows both remain converted without collapsing',
      () {
        final preview = LeadImportPreview(
          fileName: 'duplicates.csv',
          source: LeadSource.csv,
          sheetIndex: 0,
          sheetName: 'Sheet1',
          headerRowIndex: 0,
          mapping: const LeadImportColumnMapping(
            sheetIndex: 0,
            headerRowIndex: 0,
            nameColumnIndex: 0,
          ),
          rows: const [
            LeadImportPreviewRow(
              sourceRowIndex: 1,
              name: 'Duplicate Name',
              status: LeadImportPreviewRowStatus.valid,
            ),
            LeadImportPreviewRow(
              sourceRowIndex: 2,
              name: 'Duplicate Name',
              status: LeadImportPreviewRowStatus.valid,
            ),
          ],
        );

        final decision = LeadImportReviewDecision({1, 2});
        final request = builder.build(preview: preview, decision: decision);

        expect(request.drafts.length, equals(2));
        expect(request.drafts[0].name, equals('Duplicate Name'));
        expect(request.drafts[1].name, equals('Duplicate Name'));
      },
    );

    test(
      'throws LeadImportExecutionPreparationException when decision includes invalid row',
      () {
        final preview = LeadImportPreview(
          fileName: 'invalid.csv',
          source: LeadSource.csv,
          sheetIndex: 0,
          sheetName: 'Sheet1',
          headerRowIndex: 0,
          mapping: const LeadImportColumnMapping(
            sheetIndex: 0,
            headerRowIndex: 0,
            nameColumnIndex: 0,
          ),
          rows: const [
            LeadImportPreviewRow(
              sourceRowIndex: 1,
              name: 'Valid',
              status: LeadImportPreviewRowStatus.valid,
            ),
            LeadImportPreviewRow(
              sourceRowIndex: 2,
              name: 'Invalid',
              status: LeadImportPreviewRowStatus.invalid,
            ),
          ],
        );

        final decision = LeadImportReviewDecision({1, 2});

        expect(
          () => builder.build(preview: preview, decision: decision),
          throwsA(isA<LeadImportExecutionPreparationException>()),
        );
      },
    );

    test(
      'throws LeadImportExecutionPreparationException when decision includes blank row',
      () {
        final preview = LeadImportPreview(
          fileName: 'blank.csv',
          source: LeadSource.csv,
          sheetIndex: 0,
          sheetName: 'Sheet1',
          headerRowIndex: 0,
          mapping: const LeadImportColumnMapping(
            sheetIndex: 0,
            headerRowIndex: 0,
            nameColumnIndex: 0,
          ),
          rows: const [
            LeadImportPreviewRow(
              sourceRowIndex: 1,
              name: 'Valid',
              status: LeadImportPreviewRowStatus.valid,
            ),
            LeadImportPreviewRow(
              sourceRowIndex: 2,
              status: LeadImportPreviewRowStatus.blank,
            ),
          ],
        );

        final decision = LeadImportReviewDecision({1, 2});

        expect(
          () => builder.build(preview: preview, decision: decision),
          throwsA(isA<LeadImportExecutionPreparationException>()),
        );
      },
    );

    test(
      'throws LeadImportExecutionPreparationException when decision includes unknown index',
      () {
        final preview = createSamplePreview();
        final decision = LeadImportReviewDecision({99});

        expect(
          () => builder.build(preview: preview, decision: decision),
          throwsA(isA<LeadImportExecutionPreparationException>()),
        );
      },
    );

    test(
      'throws LeadImportExecutionPreparationException when decision is empty',
      () {
        final preview = createSamplePreview();
        final decision = LeadImportReviewDecision({});

        expect(
          () => builder.build(preview: preview, decision: decision),
          throwsA(isA<LeadImportExecutionPreparationException>()),
        );
      },
    );

    test(
      'throws LeadImportExecutionPreparationException when preview source is manual',
      () {
        final malformedPreview = createSamplePreview(source: LeadSource.manual);
        final decision = LeadImportReviewDecision({1});

        expect(
          () => builder.build(preview: malformedPreview, decision: decision),
          throwsA(isA<LeadImportExecutionPreparationException>()),
        );
      },
    );
  });
}
