import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../domain/entities/lead_source.dart';
import '../models/lead_import_selected_file.dart';

/// Exception thrown when file selection or basic validation fails.
class LeadImportFileException implements Exception {
  const LeadImportFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Adapts [PlatformFile] from package:file_picker into [LeadImportFileContent].
class PlatformFileImportContent implements LeadImportFileContent {
  const PlatformFileImportContent(this._platformFile);

  final PlatformFile _platformFile;

  @override
  Future<Uint8List> readAsBytes() => _platformFile.readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() => _platformFile.readAsByteStream();
}

/// Abstract interface for file selection, keeping operating-system file pickers
/// decoupled from presentation logic and testable.
abstract interface class LeadImportFilePicker {
  Future<LeadImportSelectedFile?> pickFile();
}

/// Default implementation of [LeadImportFilePicker] using `package:file_picker`.
class DefaultLeadImportFilePicker implements LeadImportFilePicker {
  const DefaultLeadImportFilePicker();

  @override
  Future<LeadImportSelectedFile?> pickFile() async {
    final platformFile = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
    );

    if (platformFile == null) return null;

    final rawExt = platformFile.extension ?? '';
    final normalizedExt = rawExt.trim().toLowerCase();

    LeadSource source;
    if (normalizedExt == 'csv') {
      source = LeadSource.csv;
    } else if (normalizedExt == 'xlsx') {
      source = LeadSource.excel;
    } else {
      throw const LeadImportFileException(
        'Unsupported file type. Please select a .csv or .xlsx file.',
      );
    }

    final size = platformFile.lengthSync() ?? await platformFile.length();
    if (size == null) {
      throw const LeadImportFileException(
        'Unable to determine the selected file size.',
      );
    }
    if (size == 0) {
      throw const LeadImportFileException('The selected file is empty.');
    }

    return LeadImportSelectedFile(
      name: platformFile.name,
      extension: normalizedExt,
      sizeBytes: size,
      source: source,
      content: PlatformFileImportContent(platformFile),
    );
  }
}
