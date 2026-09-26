import 'dart:typed_data';

import '../../domain/entities/employee_document.dart';
import '../../domain/inputs/upload_document_input.dart';
import '../../domain/repositories/employee_document_repository.dart';
import '../mock/mock_employee_document_store.dart';

/// Concrete mock implementation of [EmployeeDocumentRepository].
class MockEmployeeDocumentRepository implements EmployeeDocumentRepository {
  final MockEmployeeDocumentStore _store;

  MockEmployeeDocumentRepository({MockEmployeeDocumentStore? store})
    : _store = store ?? MockEmployeeDocumentStore();

  @override
  Future<List<EmployeeDocument>> getDocumentsForEmployee(
    String employeeId,
  ) async {
    return _store.getDocumentsForEmployee(employeeId);
  }

  @override
  Future<EmployeeDocument?> getDocumentById(String documentId) async {
    return _store.getDocumentById(documentId);
  }

  @override
  Future<EmployeeDocument> uploadDocument(UploadDocumentInput input) async {
    return _store.uploadDocument(input);
  }

  @override
  Future<Uint8List> downloadDocumentFile(String documentId) async {
    return _store.downloadDocumentFile(documentId);
  }
}
