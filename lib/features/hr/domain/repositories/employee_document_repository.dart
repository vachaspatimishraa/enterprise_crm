import 'dart:typed_data';

import '../entities/employee_document.dart';
import '../inputs/upload_document_input.dart';

/// Exception thrown by [EmployeeDocumentRepository] operations.
class EmployeeDocumentException implements Exception {
  final String message;
  final String? code;

  const EmployeeDocumentException(this.message, {this.code});

  @override
  String toString() => 'EmployeeDocumentException: $message';
}

/// Abstract contract for Employee Document management.
///
/// Designed to be implemented by a mock store initially and later backed
/// by the instructor's backend API without altering domain or UI layers.
abstract interface class EmployeeDocumentRepository {
  /// Retrieves all active documents associated with the given [employeeId].
  Future<List<EmployeeDocument>> getDocumentsForEmployee(String employeeId);

  /// Retrieves a specific document by its unique [documentId].
  Future<EmployeeDocument?> getDocumentById(String documentId);

  /// Uploads and stores a new document for an employee.
  Future<EmployeeDocument> uploadDocument(UploadDocumentInput input);

  /// Retrieves the binary file content for the given [documentId] for authorized download.
  Future<Uint8List> downloadDocumentFile(String documentId);
}
