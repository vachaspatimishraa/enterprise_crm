import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportPreview & Models', () {
    test(
      'LeadImportPreviewRow derives displayRowNumber from sourceRowIndex',
      () {
        const row0 = LeadImportPreviewRow(
          sourceRowIndex: 0,
          status: LeadImportPreviewRowStatus.valid,
        );
        const row5 = LeadImportPreviewRow(
          sourceRowIndex: 5,
          name: 'Alice',
          phone: '123',
          status: LeadImportPreviewRowStatus.valid,
        );

        expect(row0.displayRowNumber, equals(1));
        expect(row5.displayRowNumber, equals(6));
      },
    );

    test(
      'LeadImportPreview derives counts from rows guaranteeing invariant',
      () {
        const mapping = LeadImportColumnMapping(
          sheetIndex: 0,
          headerRowIndex: 0,
          nameColumnIndex: 0,
        );

        final rows = [
          const LeadImportPreviewRow(
            sourceRowIndex: 1,
            name: 'Alice',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 2,
            name: 'Bob',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 3,
            name: 'InvalidEmail',
            status: LeadImportPreviewRowStatus.invalid,
            issues: [
              LeadImportPreviewIssue(
                field: LeadImportTargetField.email,
                severity: LeadImportPreviewIssueSeverity.error,
                message: 'Invalid email address.',
              ),
            ],
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 4,
            name: '',
            status: LeadImportPreviewRowStatus.blank,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 5,
            name: '',
            status: LeadImportPreviewRowStatus.blank,
          ),
        ];

        final preview = LeadImportPreview(
          fileName: 'leads.csv',
          source: LeadSource.csv,
          sheetIndex: 0,
          sheetName: 'CSV',
          headerRowIndex: 0,
          mapping: mapping,
          rows: rows,
        );

        expect(preview.totalRowCount, equals(5));
        expect(preview.validRowCount, equals(2));
        expect(preview.invalidRowCount, equals(1));
        expect(preview.blankRowCount, equals(2));
        expect(
          preview.validRowCount +
              preview.invalidRowCount +
              preview.blankRowCount,
          equals(preview.totalRowCount),
        );
      },
    );

    test('equality and hashCode work as expected', () {
      const mapping = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
      );

      final preview1 = LeadImportPreview(
        fileName: 'leads.csv',
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
        ],
      );

      final preview2 = LeadImportPreview(
        fileName: 'leads.csv',
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
        ],
      );

      expect(preview1, equals(preview2));
      expect(preview1.hashCode, equals(preview2.hashCode));
      expect(preview1.toString(), contains('valid: 1'));
    });
  });
}
