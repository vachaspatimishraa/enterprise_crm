import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_preview.dart';
import 'package:enterprise_crm/features/leads/presentation/services/lead_import_duplicate_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultLeadImportDuplicateDetector', () {
    const detector = DefaultLeadImportDuplicateDetector();

    const testMapping = LeadImportColumnMapping(
      sheetIndex: 0,
      headerRowIndex: 0,
      nameColumnIndex: 0,
      phoneColumnIndex: 1,
      emailColumnIndex: 2,
    );

    LeadImportPreview createPreview(List<LeadImportPreviewRow> rows) {
      return LeadImportPreview(
        fileName: 'leads.csv',
        source: LeadSource.csv,
        sheetIndex: 0,
        sheetName: 'CSV',
        headerRowIndex: 0,
        mapping: testMapping,
        rows: rows,
      );
    }

    test('Section 46: returns 0 groups when all valid rows are distinct', () {
      final preview = createPreview([
        const LeadImportPreviewRow(
          sourceRowIndex: 1,
          name: 'Alice',
          phone: '123',
          email: 'alice@example.com',
          status: LeadImportPreviewRowStatus.valid,
        ),
        const LeadImportPreviewRow(
          sourceRowIndex: 2,
          name: 'Bob',
          phone: '456',
          email: 'bob@example.com',
          status: LeadImportPreviewRowStatus.valid,
        ),
      ]);

      final groups = detector.detect(preview);

      expect(groups, isEmpty);
    });

    test(
      'Section 47: detects exact duplicate pair into 1 group with 2 row indices',
      () {
        final preview = createPreview([
          const LeadImportPreviewRow(
            sourceRowIndex: 1,
            name: 'Alice',
            phone: '123',
            email: 'alice@example.com',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 2,
            name: 'Bob',
            phone: '456',
            email: 'bob@example.com',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 5,
            name: 'Alice',
            phone: '123',
            email: 'alice@example.com',
            status: LeadImportPreviewRowStatus.valid,
          ),
        ]);

        final groups = detector.detect(preview);

        expect(groups.length, equals(1));
        expect(groups.first.sourceRowIndices, equals([1, 5]));
      },
    );

    test(
      'Section 48: groups three exact copies into a single group (not pairwise)',
      () {
        final preview = createPreview([
          const LeadImportPreviewRow(
            sourceRowIndex: 2,
            name: 'Alice',
            phone: '123',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 5,
            name: 'Alice',
            phone: '123',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 9,
            name: 'Alice',
            phone: '123',
            status: LeadImportPreviewRowStatus.valid,
          ),
        ]);

        final groups = detector.detect(preview);

        expect(groups.length, equals(1));
        expect(groups.first.sourceRowIndices, equals([2, 5, 9]));
      },
    );

    test(
      'Section 49: preserves multiple duplicate groups ordered by first source row occurrence',
      () {
        final preview = createPreview([
          const LeadImportPreviewRow(
            sourceRowIndex: 1,
            name: 'Alice',
            phone: '123',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 2,
            name: 'Bob',
            phone: '456',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 3,
            name: 'Bob',
            phone: '456',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 4,
            name: 'Alice',
            phone: '123',
            status: LeadImportPreviewRowStatus.valid,
          ),
        ]);

        final groups = detector.detect(preview);

        expect(groups.length, equals(2));
        // Alice occurred first at index 1 -> group 0
        expect(groups[0].sourceRowIndices, equals([1, 4]));
        // Bob occurred first at index 2 -> group 1
        expect(groups[1].sourceRowIndices, equals([2, 3]));
      },
    );

    test(
      'Section 50: same phone with different name does NOT constitute a duplicate',
      () {
        final preview = createPreview([
          const LeadImportPreviewRow(
            sourceRowIndex: 1,
            name: 'Alice',
            phone: '123',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 2,
            name: 'Bob',
            phone: '123',
            status: LeadImportPreviewRowStatus.valid,
          ),
        ]);

        final groups = detector.detect(preview);

        expect(groups, isEmpty);
      },
    );

    test(
      'Section 51: same email with different name does NOT constitute a duplicate',
      () {
        final preview = createPreview([
          const LeadImportPreviewRow(
            sourceRowIndex: 1,
            name: 'Alice',
            email: 'person@example.com',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 2,
            name: 'Bob',
            email: 'person@example.com',
            status: LeadImportPreviewRowStatus.valid,
          ),
        ]);

        final groups = detector.detect(preview);

        expect(groups, isEmpty);
      },
    );

    test(
      'Section 52: case difference prevents duplicate match (case-sensitive exact)',
      () {
        final preview = createPreview([
          const LeadImportPreviewRow(
            sourceRowIndex: 1,
            name: 'Alice',
            email: 'alice@example.com',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 2,
            name: 'alice',
            email: 'alice@example.com',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 3,
            name: 'Alice',
            email: 'ALICE@EXAMPLE.COM',
            status: LeadImportPreviewRowStatus.valid,
          ),
        ]);

        final groups = detector.detect(preview);

        expect(groups, isEmpty);
      },
    );

    test(
      'Section 53: invalid rows are strictly ignored and do not form duplicate groups',
      () {
        final preview = createPreview([
          const LeadImportPreviewRow(
            sourceRowIndex: 1,
            name: 'Bad',
            email: 'not-an-email',
            status: LeadImportPreviewRowStatus.invalid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 2,
            name: 'Bad',
            email: 'not-an-email',
            status: LeadImportPreviewRowStatus.invalid,
          ),
        ]);

        final groups = detector.detect(preview);

        expect(groups, isEmpty);
      },
    );

    test(
      'Section 54: blank rows are strictly ignored and do not form duplicate groups',
      () {
        final preview = createPreview([
          const LeadImportPreviewRow(
            sourceRowIndex: 1,
            name: '',
            phone: '',
            email: '',
            status: LeadImportPreviewRowStatus.blank,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 2,
            name: '',
            phone: '',
            email: '',
            status: LeadImportPreviewRowStatus.blank,
          ),
        ]);

        final groups = detector.detect(preview);

        expect(groups, isEmpty);
      },
    );

    test(
      'Section 55: unmapped fields participate as null and group correctly',
      () {
        // Email is unmapped (null)
        final preview = createPreview([
          const LeadImportPreviewRow(
            sourceRowIndex: 1,
            name: 'Alice',
            phone: '123',
            email: null,
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 2,
            name: 'Alice',
            phone: '123',
            email: null,
            status: LeadImportPreviewRowStatus.valid,
          ),
        ]);

        final groups = detector.detect(preview);

        expect(groups.length, equals(1));
        expect(groups.first.sourceRowIndices, equals([1, 2]));
      },
    );

    test(
      'Section 56: group sourceRowIndices are always strictly ordered ascending',
      () {
        // Intentionally supply out-of-order preview rows to confirm sorting guarantee
        final preview = createPreview([
          const LeadImportPreviewRow(
            sourceRowIndex: 8,
            name: 'Alice',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 2,
            name: 'Alice',
            status: LeadImportPreviewRowStatus.valid,
          ),
          const LeadImportPreviewRow(
            sourceRowIndex: 5,
            name: 'Alice',
            status: LeadImportPreviewRowStatus.valid,
          ),
        ]);

        final groups = detector.detect(preview);

        expect(groups.length, equals(1));
        expect(groups.first.sourceRowIndices, equals([2, 5, 8]));
      },
    );
  });
}
