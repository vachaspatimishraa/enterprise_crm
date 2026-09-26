import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Represents a file picked by the user for document upload.
class EmployeeDocumentPickedFile {
  final String name;
  final String extension;
  final int sizeBytes;
  final Uint8List bytes;

  const EmployeeDocumentPickedFile({
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.bytes,
  });
}

/// Abstract interface for picking employee document files.
///
/// Decouples UI and Cubits from platform-specific file picker implementations
/// and enables deterministic testing.
abstract interface class EmployeeDocumentFilePicker {
  Future<EmployeeDocumentPickedFile?> pickDocumentFile();
}

/// Default implementation of [EmployeeDocumentFilePicker] using `package:file_picker`.
class DefaultEmployeeDocumentFilePicker implements EmployeeDocumentFilePicker {
  const DefaultEmployeeDocumentFilePicker();

  @override
  Future<EmployeeDocumentPickedFile?> pickDocumentFile() async {
    final platformFile = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
    );

    if (platformFile == null) {
      return null;
    }

    final bytes = await platformFile.readAsBytes();
    final size =
        platformFile.lengthSync() ??
        (await platformFile.length()) ??
        bytes.length;
    final rawExt = platformFile.extension ?? '';

    return EmployeeDocumentPickedFile(
      name: platformFile.name,
      extension: rawExt.trim().toLowerCase(),
      sizeBytes: size,
      bytes: bytes,
    );
  }
}

/// Mock implementation for deterministic testing.
class MockEmployeeDocumentFilePicker implements EmployeeDocumentFilePicker {
  final EmployeeDocumentPickedFile? cannedFile;

  const MockEmployeeDocumentFilePicker({this.cannedFile});

  @override
  Future<EmployeeDocumentPickedFile?> pickDocumentFile() async {
    return cannedFile;
  }
}
