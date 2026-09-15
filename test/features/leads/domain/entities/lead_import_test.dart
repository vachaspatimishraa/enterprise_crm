import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportRequest', () {
    test('legacy file mode has non-null fileReference and empty drafts', () {
      const fileRef = 'opaque-ref-123';
      const request = LeadImportRequest(
        fileReference: fileRef,
        fileName: 'leads.csv',
        fileType: LeadImportFileType.csv,
      );

      expect(request.fileReference, equals(fileRef));
      expect(request.fileName, equals('leads.csv'));
      expect(request.fileType, equals(LeadImportFileType.csv));
      expect(request.drafts, isEmpty);
      expect(request.hasDraftPayload, isFalse);
    });

    test(
      'structured draft mode has null fileReference and non-empty drafts',
      () {
        final drafts = [
          const LeadDraft(
            name: 'Alice',
            email: 'alice@example.com',
            source: LeadSource.csv,
          ),
        ];

        final request = LeadImportRequest.fromDrafts(
          fileName: 'leads.csv',
          fileType: LeadImportFileType.csv,
          drafts: drafts,
        );

        expect(request.fileReference, isNull);
        expect(request.fileName, equals('leads.csv'));
        expect(request.fileType, equals(LeadImportFileType.csv));
        expect(request.drafts.length, equals(1));
        expect(request.drafts.first.name, equals('Alice'));
        expect(request.hasDraftPayload, isTrue);
      },
    );

    test(
      'drafts list is immutable and external mutation does not affect payload',
      () {
        final mutableList = <LeadDraft>[
          const LeadDraft(name: 'Alice', source: LeadSource.excel),
        ];

        final request = LeadImportRequest.fromDrafts(
          fileName: 'leads.xlsx',
          fileType: LeadImportFileType.excel,
          drafts: mutableList,
        );

        // Mutate the original list
        mutableList.add(const LeadDraft(name: 'Bob', source: LeadSource.excel));

        expect(request.drafts.length, equals(1));
        expect(request.drafts.first.name, equals('Alice'));

        // Mutating request.drafts directly throws UnsupportedError
        expect(
          () => request.drafts.add(const LeadDraft(name: 'Charlie')),
          throwsUnsupportedError,
        );
      },
    );
  });

  group('LeadImportResult', () {
    test('instantiates with exact counts', () {
      const result = LeadImportResult(
        totalRows: 10,
        importedRows: 8,
        skippedRows: 1,
        failedRows: 0,
        duplicateRows: 1,
      );

      expect(result.totalRows, equals(10));
      expect(result.importedRows, equals(8));
      expect(result.skippedRows, equals(1));
      expect(result.failedRows, equals(0));
      expect(result.duplicateRows, equals(1));
    });
  });
}
