import 'dart:typed_data';

import '../../domain/entities/lead_source.dart';

/// Cross-platform abstraction for accessing selected file content without
/// exposing platform-specific file picker objects or requiring a filesystem path.
abstract interface class LeadImportFileContent {
  Future<Uint8List> readAsBytes();
  Stream<Uint8List> readAsByteStream();
}

/// In-memory implementation of [LeadImportFileContent], useful for testing and Web.
class InMemoryLeadImportFileContent implements LeadImportFileContent {
  const InMemoryLeadImportFileContent(this._bytes);

  final Uint8List _bytes;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_bytes);
}

/// Presentation model representing a file selected for Lead import.
///
/// Keeps file-picker and platform-specific representations isolated
/// from both domain and UI layers.
class LeadImportSelectedFile {
  const LeadImportSelectedFile({
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.source,
    required this.content,
  });

  final String name;

  /// Normalized lowercase extension without leading dot (e.g. 'csv', 'xlsx').
  final String extension;

  final int sizeBytes;

  final LeadSource source;

  final LeadImportFileContent content;

  /// Human-readable file size for display (e.g. '512 B', '12.4 KB', '2.5 MB').
  String get formattedSize {
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    } else if (sizeBytes < 1024 * 1024) {
      final kb = sizeBytes / 1024;
      return '${kb >= 10 ? kb.toStringAsFixed(0) : kb.toStringAsFixed(1)} KB';
    } else {
      final mb = sizeBytes / (1024 * 1024);
      return '${mb >= 10 ? mb.toStringAsFixed(0) : mb.toStringAsFixed(1)} MB';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportSelectedFile &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          extension == other.extension &&
          sizeBytes == other.sizeBytes &&
          source == other.source;

  @override
  int get hashCode => Object.hash(name, extension, sizeBytes, source);

  @override
  String toString() =>
      'LeadImportSelectedFile(name: $name, extension: $extension, sizeBytes: $sizeBytes, source: $source)';
}
