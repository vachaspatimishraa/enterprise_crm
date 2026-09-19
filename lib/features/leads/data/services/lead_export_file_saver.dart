import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../domain/entities/lead_export.dart';
import 'lead_export_serializer.dart';

/// Status indicating whether an export file was successfully saved or cancelled by the user.
enum LeadExportSaveStatus { saved, cancelled }

/// Result of an export file save operation.
class LeadExportSaveResult {
  const LeadExportSaveResult._({required this.status, this.uri});

  const LeadExportSaveResult.saved({Uri? uri})
    : this._(status: LeadExportSaveStatus.saved, uri: uri);

  const LeadExportSaveResult.cancelled()
    : this._(status: LeadExportSaveStatus.cancelled);

  final LeadExportSaveStatus status;
  final Uri? uri;

  bool get isSaved => status == LeadExportSaveStatus.saved;
  bool get isCancelled => status == LeadExportSaveStatus.cancelled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadExportSaveResult &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          uri == other.uri;

  @override
  int get hashCode => Object.hash(status, uri);

  @override
  String toString() => 'LeadExportSaveResult(status: $status, uri: $uri)';
}

/// Adapter interface wrapping the platform file picker save mechanism for testability.
abstract interface class ExportSavePicker {
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
    String? dialogTitle,
  });
}

/// Production implementation of [ExportSavePicker] using `package:file_picker`.
class FilePickerExportSavePicker implements ExportSavePicker {
  const FilePickerExportSavePicker();

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
    String? dialogTitle = 'Save Lead Export',
  }) {
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: [extension],
    );
  }
}

/// Interface for saving or downloading lead export artifacts across platforms.
abstract interface class LeadExportFileSaver {
  Future<LeadExportSaveResult> save(LeadExportResult result);
}

/// Default implementation of [LeadExportFileSaver] validating in-memory
/// [LeadExportContent] and delegating file saving to [ExportSavePicker].
class DefaultLeadExportFileSaver implements LeadExportFileSaver {
  const DefaultLeadExportFileSaver({
    ExportSavePicker? picker,
    this.dialogTitle = 'Save Lead Export',
  }) : _picker = picker ?? const FilePickerExportSavePicker();

  final ExportSavePicker _picker;
  final String dialogTitle;

  @override
  Future<LeadExportSaveResult> save(LeadExportResult result) async {
    final fileRef = result.fileReference;
    if (fileRef is! LeadExportContent) {
      throw UnsupportedError(
        'Unsupported lead export artifact type: ${fileRef.runtimeType}. '
        'Expected LeadExportContent.',
      );
    }

    final uri = await _picker.saveFile(
      fileName: result.fileName,
      bytes: fileRef.bytes,
      mimeType: fileRef.mimeType,
      extension: fileRef.extension,
      dialogTitle: dialogTitle,
    );

    if (uri == null) {
      return const LeadExportSaveResult.cancelled();
    }

    return LeadExportSaveResult.saved(uri: uri);
  }
}
