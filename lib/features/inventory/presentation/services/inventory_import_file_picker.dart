import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// User-safe exception thrown when file picking or preliminary validation fails.
class InventoryImportFileException implements Exception {
  const InventoryImportFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Represents a validated file selected by the user with its raw bytes loaded.
class InventoryImportSelectedFile {
  const InventoryImportSelectedFile({
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.bytes,
  });

  final String name;
  final String extension;
  final int sizeBytes;
  final Uint8List bytes;
}

/// Abstract interface for file selection.
abstract interface class InventoryImportFilePicker {
  Future<InventoryImportSelectedFile?> pickFile();
}

/// Default implementation of [InventoryImportFilePicker] using `package:file_picker`.
class DefaultInventoryImportFilePicker implements InventoryImportFilePicker {
  const DefaultInventoryImportFilePicker();

  @override
  Future<InventoryImportSelectedFile?> pickFile() async {
    final platformFile = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
    );

    if (platformFile == null) return null;

    final rawExt = platformFile.extension ?? '';
    final ext = rawExt.trim().toLowerCase();

    if (ext != 'csv' && ext != 'xlsx') {
      throw const InventoryImportFileException(
        'Please select a CSV or XLSX file.',
      );
    }

    final bytes = await platformFile.readAsBytes();
    if (bytes.isEmpty) {
      throw const InventoryImportFileException('The selected file is empty.');
    }

    return InventoryImportSelectedFile(
      name: platformFile.name,
      extension: ext,
      sizeBytes: bytes.length,
      bytes: bytes,
    );
  }
}
