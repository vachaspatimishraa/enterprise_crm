import 'package:flutter/foundation.dart';

/// Supported formats for inventory data export.
enum InventoryExportFormat {
  csv,
  xlsx,
  pdf,
}

/// Supported record scopes for inventory export.
enum InventoryExportScope {
  all,
  filtered,
  selected,
}

/// Configuration presets for inventory export columns.
enum InventoryExportPreset {
  allDetails,
  legacyThreeColumn,
  custom,
}

/// Prepared inventory export artifact containing serialized bytes and metadata.
@immutable
class InventoryExportArtifact {
  final Uint8List bytes;
  final InventoryExportFormat format;
  final int itemCount;
  final DateTime generatedAt;
  final List<String> columns;
  final InventoryExportScope scope;
  final InventoryExportPreset preset;

  InventoryExportArtifact({
    required Uint8List bytes,
    required this.format,
    required this.itemCount,
    DateTime? generatedAt,
    List<String>? columns,
    this.scope = InventoryExportScope.all,
    this.preset = InventoryExportPreset.allDetails,
  })  : bytes = Uint8List.fromList(bytes),
        generatedAt = generatedAt ?? DateTime.now(),
        columns = List.unmodifiable(columns ?? const ['Item Name', 'SKU', 'Current Quantity']);

  /// The standard file extension (including dot).
  String get fileExtension => switch (format) {
    InventoryExportFormat.csv => '.csv',
    InventoryExportFormat.xlsx => '.xlsx',
    InventoryExportFormat.pdf => '.pdf',
  };

  /// The standard MIME type for the format.
  String get mimeType => switch (format) {
    InventoryExportFormat.csv => 'text/csv',
    InventoryExportFormat.xlsx =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    InventoryExportFormat.pdf => 'application/pdf',
  };

  /// Suggested filename prefix matching project conventions.
  String defaultFileName({DateTime? timestamp}) {
    final t = timestamp ?? generatedAt;
    final year = t.year.toString().padLeft(4, '0');
    final month = t.month.toString().padLeft(2, '0');
    final day = t.day.toString().padLeft(2, '0');
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    final second = t.second.toString().padLeft(2, '0');
    // ignore: unnecessary_brace_in_string_interps
    return 'inventory_export_$year$month${day}_$hour$minute$second$fileExtension';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryExportArtifact &&
          runtimeType == other.runtimeType &&
          format == other.format &&
          itemCount == other.itemCount &&
          scope == other.scope &&
          preset == other.preset &&
          listEquals(columns, other.columns) &&
          listEquals(bytes, other.bytes);

  @override
  int get hashCode => Object.hash(
        format,
        itemCount,
        scope,
        preset,
        Object.hashAll(columns),
        Object.hashAll(bytes),
      );

  @override
  String toString() =>
      'InventoryExportArtifact(format: $format, itemCount: $itemCount, scope: $scope, preset: $preset, columns: ${columns.length}, bytes: ${bytes.length})';
}
