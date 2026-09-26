/// Immutable domain entity representing an Employee Document in the Enterprise CRM HR module.
///
/// Documents are strictly associated with a specific employee via [employeeId].
/// Raw file contents are never stored permanently in this entity.
class EmployeeDocument {
  final String id;
  final String employeeId;
  final String title;
  final String fileName;
  final String fileExtension;
  final int fileSizeBytes;
  final String documentType;
  final DateTime? expiryDate;
  final DateTime uploadedAt;
  final String? uploadedBy;
  final String? fileReference;

  const EmployeeDocument({
    required this.id,
    required this.employeeId,
    required this.title,
    required this.fileName,
    required this.fileExtension,
    required this.fileSizeBytes,
    required this.documentType,
    this.expiryDate,
    required this.uploadedAt,
    this.uploadedBy,
    this.fileReference,
  });

  /// Human-readable file size (e.g. '1.5 MB', '450 KB').
  String get formattedFileSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      final kb = fileSizeBytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    } else {
      final mb = fileSizeBytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    }
  }

  /// Whether this document has an expiry date specified.
  bool get hasExpiryDate => expiryDate != null;

  /// Whether this document is expired relative to [now].
  bool isExpired({DateTime? now}) {
    if (expiryDate == null) return false;
    final reference = now ?? DateTime.now();
    return expiryDate!.isBefore(reference);
  }

  /// Creates a copy of this document with updated fields.
  EmployeeDocument copyWith({
    String? id,
    String? employeeId,
    String? title,
    String? fileName,
    String? fileExtension,
    int? fileSizeBytes,
    String? documentType,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    DateTime? uploadedAt,
    String? uploadedBy,
    String? fileReference,
  }) {
    return EmployeeDocument(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      fileExtension: fileExtension ?? this.fileExtension,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      documentType: documentType ?? this.documentType,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      fileReference: fileReference ?? this.fileReference,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmployeeDocument &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          employeeId == other.employeeId &&
          title == other.title &&
          fileName == other.fileName &&
          fileExtension == other.fileExtension &&
          fileSizeBytes == other.fileSizeBytes &&
          documentType == other.documentType &&
          expiryDate == other.expiryDate &&
          uploadedAt == other.uploadedAt &&
          uploadedBy == other.uploadedBy &&
          fileReference == other.fileReference;

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    title,
    fileName,
    fileExtension,
    fileSizeBytes,
    documentType,
    expiryDate,
    uploadedAt,
    uploadedBy,
    fileReference,
  );

  @override
  String toString() =>
      'EmployeeDocument(id: $id, employeeId: $employeeId, title: $title, file: $fileName, type: $documentType)';
}
