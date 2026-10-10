import 'dart:convert';
import 'dart:typed_data';

import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_document_repository.dart';
import 'package:enterprise_crm/features/hr/domain/inputs/upload_document_input.dart';
import 'package:enterprise_crm/features/hr/domain/repositories/employee_document_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockEmployeeDocumentRepository repository;

  setUp(() {
    repository = MockEmployeeDocumentRepository();
  });

  group('MockEmployeeDocumentRepository Tests', () {
    test(
      'getDocumentsForEmployee returns seeded documents for specific employee',
      () async {
        final emp1Docs = await repository.getDocumentsForEmployee('emp_1');
        expect(emp1Docs.length, 2);
        expect(emp1Docs.every((d) => d.employeeId == 'emp_1'), isTrue);

        final emp2Docs = await repository.getDocumentsForEmployee('emp_2');
        expect(emp2Docs.length, 1);
        expect(emp2Docs.first.title, 'Resume / Curriculum Vitae');
      },
    );

    test(
      'getDocumentsForEmployee returns empty list for employee with no documents',
      () async {
        final docs = await repository.getDocumentsForEmployee('emp_none');
        expect(docs, isEmpty);
      },
    );

    test(
      'getDocumentById returns existing document and null for unknown ID',
      () async {
        final doc = await repository.getDocumentById('doc_1');
        expect(doc, isNotNull);
        expect(doc!.title, 'Employment Agreement');

        final unknown = await repository.getDocumentById('doc_unknown');
        expect(unknown, isNull);
      },
    );

    test(
      'uploadDocument rejects invalid input with EmployeeDocumentException',
      () async {
        final emptyTitleInput = UploadDocumentInput(
          employeeId: 'emp_1',
          title: '',
          documentType: 'Identity',
          fileName: 'id.pdf',
          fileExtension: 'pdf',
          fileSizeBytes: 100,
          fileBytes: Uint8List.fromList([1, 2, 3]),
        );

        expect(
          () => repository.uploadDocument(emptyTitleInput),
          throwsA(isA<EmployeeDocumentException>()),
        );

        final emptyBytesInput = UploadDocumentInput(
          employeeId: 'emp_1',
          title: 'Title',
          documentType: 'Identity',
          fileName: 'id.pdf',
          fileExtension: 'pdf',
          fileSizeBytes: 0,
          fileBytes: Uint8List(0),
        );

        expect(
          () => repository.uploadDocument(emptyBytesInput),
          throwsA(isA<EmployeeDocumentException>()),
        );
      },
    );

    test(
      'uploadDocument creates document and persists bytes for download',
      () async {
        final testBytes = Uint8List.fromList(
          utf8.encode('Hello World Document'),
        );
        final input = UploadDocumentInput(
          employeeId: 'emp_2',
          title: 'Promotion Letter',
          documentType: 'Contract',
          fileName: 'promotion.pdf',
          fileExtension: 'pdf',
          fileSizeBytes: testBytes.length,
          fileBytes: testBytes,
          uploadedBy: 'usr_admin',
        );

        final created = await repository.uploadDocument(input);
        expect(created.id, startsWith('doc_'));
        expect(created.title, 'Promotion Letter');
        expect(created.employeeId, 'emp_2');

        final docs = await repository.getDocumentsForEmployee('emp_2');
        expect(docs.any((d) => d.id == created.id), isTrue);

        final downloadedBytes = await repository.downloadDocumentFile(
          created.id,
        );
        expect(downloadedBytes, equals(testBytes));
      },
    );

    test(
      'downloadDocumentFile throws exception for nonexistent document',
      () async {
        expect(
          () => repository.downloadDocumentFile('nonexistent_doc'),
          throwsA(isA<EmployeeDocumentException>()),
        );
      },
    );

    test('cross-employee data isolation is maintained', () async {
      final emp1Docs = await repository.getDocumentsForEmployee('emp_1');
      final emp3Docs = await repository.getDocumentsForEmployee('emp_3');

      final emp1Ids = emp1Docs.map((d) => d.id).toSet();
      final emp3Ids = emp3Docs.map((d) => d.id).toSet();

      expect(emp1Ids.intersection(emp3Ids), isEmpty);
    });
  });
}
