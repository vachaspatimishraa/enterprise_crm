import 'dart:convert';
import 'dart:typed_data';

import '../../domain/entities/employee_document.dart';
import '../../domain/inputs/upload_document_input.dart';
import '../../domain/repositories/employee_document_repository.dart';

/// In-memory thread-safe mock store for employee documents.
///
/// Provides deterministic initial seed data and full copy isolation
/// so modifications in tests or app runtime do not leak across tests.
class MockEmployeeDocumentStore {
  final Map<String, EmployeeDocument> _documents = {};
  final Map<String, Uint8List> _fileContents = {};
  int _idCounter = 100;

  MockEmployeeDocumentStore({bool seedInitialData = true}) {
    if (seedInitialData) {
      _seed();
    }
  }

  void _seed() {
    final seeds = [
      EmployeeDocument(
        id: 'doc_1',
        employeeId: 'emp_1',
        title: 'Employment Agreement',
        fileName: 'employment_agreement.pdf',
        fileExtension: 'pdf',
        fileSizeBytes: 1024 * 1024, // 1 MB
        documentType: 'Contract',
        expiryDate: null,
        uploadedAt: DateTime.utc(2023, 1, 15, 9, 30),
        uploadedBy: 'usr_admin',
        fileReference: 'file_ref_mock_001',
      ),
      EmployeeDocument(
        id: 'doc_2',
        employeeId: 'emp_1',
        title: 'National Identity Proof',
        fileName: 'national_id_card.pdf',
        fileExtension: 'pdf',
        fileSizeBytes: 512 * 1024, // 512 KB
        documentType: 'Identity',
        expiryDate: DateTime.utc(2028, 1, 15),
        uploadedAt: DateTime.utc(2023, 1, 15, 9, 45),
        uploadedBy: 'usr_admin',
        fileReference: 'file_ref_mock_002',
      ),
      EmployeeDocument(
        id: 'doc_3',
        employeeId: 'emp_2',
        title: 'Resume / Curriculum Vitae',
        fileName: 'bob_miller_resume.pdf',
        fileExtension: 'pdf',
        fileSizeBytes: 350 * 1024, // 350 KB
        documentType: 'Resume',
        expiryDate: null,
        uploadedAt: DateTime.utc(2023, 3, 1, 10, 15),
        uploadedBy: 'usr_admin',
        fileReference: 'file_ref_mock_003',
      ),
      EmployeeDocument(
        id: 'doc_4',
        employeeId: 'emp_3',
        title: 'Bachelor Degree Certificate',
        fileName: 'degree_certificate.pdf',
        fileExtension: 'pdf',
        fileSizeBytes: 780 * 1024, // 780 KB
        documentType: 'Certificate',
        expiryDate: null,
        uploadedAt: DateTime.utc(2023, 6, 10, 14, 0),
        uploadedBy: 'usr_admin',
        fileReference: 'file_ref_mock_004',
      ),
    ];

    for (final doc in seeds) {
      _documents[doc.id] = doc;
      _fileContents[doc.id] = Uint8List.fromList(
        utf8.encode(
          'Mock binary file content for ${doc.title} (${doc.fileName})',
        ),
      );
    }
  }

  /// Retrieves a cloned list of documents for the given [employeeId].
  List<EmployeeDocument> getDocumentsForEmployee(String employeeId) {
    return _documents.values
        .where((d) => d.employeeId == employeeId)
        .map(_cloneDocument)
        .toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  /// Retrieves a cloned document by [documentId].
  EmployeeDocument? getDocumentById(String documentId) {
    final doc = _documents[documentId];
    return doc != null ? _cloneDocument(doc) : null;
  }

  /// Stores a new document and its file bytes.
  EmployeeDocument uploadDocument(UploadDocumentInput input) {
    final validationError = input.validate();
    if (validationError != null) {
      throw EmployeeDocumentException(
        validationError,
        code: 'VALIDATION_ERROR',
      );
    }

    _idCounter++;
    final newId = 'doc_$_idCounter';
    final now = DateTime.now().toUtc();

    final newDoc = EmployeeDocument(
      id: newId,
      employeeId: input.employeeId,
      title: input.title.trim(),
      fileName: input.fileName.trim(),
      fileExtension: input.fileExtension.trim().toLowerCase(),
      fileSizeBytes: input.fileSizeBytes,
      documentType: input.documentType.trim(),
      expiryDate: input.expiryDate,
      uploadedAt: now,
      uploadedBy: input.uploadedBy,
      fileReference: 'file_ref_mock_$newId',
    );

    _documents[newId] = newDoc;
    _fileContents[newId] = Uint8List.fromList(input.fileBytes);

    return _cloneDocument(newDoc);
  }

  /// Retrieves the binary file content for a given [documentId].
  Uint8List downloadDocumentFile(String documentId) {
    final bytes = _fileContents[documentId];
    if (bytes == null) {
      throw const EmployeeDocumentException(
        'Document file content not found.',
        code: 'FILE_NOT_FOUND',
      );
    }
    return Uint8List.fromList(bytes);
  }

  /// Clones a document to guarantee state isolation.
  EmployeeDocument _cloneDocument(EmployeeDocument doc) {
    return doc.copyWith();
  }
}
