import 'dart:typed_data';

/// Immutable input object for uploading a document associated with an employee.
class UploadDocumentInput {
  final String employeeId;
  final String title;
  final String documentType;
  final String fileName;
  final String fileExtension;
  final int fileSizeBytes;
  final Uint8List fileBytes;
  final DateTime? expiryDate;
  final String? uploadedBy;

  const UploadDocumentInput({
    required this.employeeId,
    required this.title,
    required this.documentType,
    required this.fileName,
    required this.fileExtension,
    required this.fileSizeBytes,
    required this.fileBytes,
    this.expiryDate,
    this.uploadedBy,
  });

  /// Validates the upload input fields.
  String? validate() {
    if (employeeId.trim().isEmpty) {
      return 'Employee ID cannot be empty.';
    }
    if (title.trim().isEmpty) {
      return 'Document title is required.';
    }
    if (documentType.trim().isEmpty) {
      return 'Document type is required.';
    }
    if (fileName.trim().isEmpty) {
      return 'File name is required.';
    }
    if (fileSizeBytes <= 0) {
      return 'Selected file cannot be empty.';
    }
    if (fileSizeBytes > 10 * 1024 * 1024) {
      return 'File size cannot exceed 10 MB.';
    }
    if (fileBytes.isEmpty) {
      return 'File content cannot be empty.';
    }
    return null;
  }
}
