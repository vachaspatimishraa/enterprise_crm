import 'package:flutter/foundation.dart';

/// Supported formats for inventory data export.
enum InventoryExportFormat {
  csv,
  xlsx,
}

/// Prepared inventory export artifact containing serialized bytes and metadata.
@immutable
class InventoryExportArtifact {
  final Uint8List bytes;
  final InventoryExportFormat format;
  final int itemCount;
  final DateTime generatedAt;

  InventoryExportArtifact({
    required Uint8List bytes,
    required this.format,
    required this.itemCount,
    DateTime? generatedAt,
  })  : bytes = Uint8List.fromList(bytes),
        generatedAt = generatedAt ?? DateTime.now();

  /// The standard file extension (including dot).
  String get fileExtension => format == InventoryExportFormat.csv ? '.csv' : '.xlsx';

  /// The standard MIME type for the format.
  String get mimeType => format == InventoryExportFormat.csv
      ? 'text/csv'
      : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Suggested filename prefix matching project conventions.
  String defaultFileName({DateTime? timestamp}) {
    final t = timestamp ?? generatedAt;
    final year = t.year.toString().padLeft(4, '0');
    final month = t.month.toString().padLeft(2, '0');
    final day = t.day.toString().padLeft(2, '0');
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    final second = t.second.toString().padLeft(2, '0');
    return 'inventory_export_$year$month${day}_$hour$minute$second$fileExtension';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryExportArtifact &&
          runtimeType == other.runtimeType &&
          format == other.format &&
          itemCount == other.itemCount &&
          listEquals(bytes, other.bytes);

  @override
  int get hashCode => Object.hash(format, itemCount, Object.hashAll(bytes));

  @override
  String toString() =>
      'InventoryExportArtifact(format: $format, itemCount: $itemCount, bytes: ${bytes.length})';
}
