import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_export_fields.dart';
import '../../domain/entities/inventory_item_summary.dart';

/// Exception thrown when CSV export serialization fails.
class InventoryCsvSerializerException implements Exception {
  const InventoryCsvSerializerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Service responsible for securely formatting and serializing Inventory item
/// summaries into UTF-8 encoded CSV bytes with user-selected columns and formula protection.
class InventoryCsvSerializer {
  const InventoryCsvSerializer();

  static const String headerName = 'Item Name';
  static const String headerSku = 'SKU';
  static const String headerQuantity = 'Current Quantity';

  /// Converts a list of [InventoryItemSummary] records into a UTF-8 CSV string
  /// using the specified [columns] in exact order.
  ///
  /// If [columns] is null, defaults to the legacy 3-column schema.
  String convertToString(
    List<InventoryItemSummary> items, {
    List<String>? columns,
    List<CustomFieldDefinition>? customFieldDefinitions,
    bool isLegacy = false,
  }) {
    final effectiveColumns = columns != null && columns.isNotEmpty
        ? columns
        : InventoryExportFields.legacyHeaders;

    final effectiveIsLegacy = isLegacy ||
        (columns == null && effectiveColumns == InventoryExportFields.legacyHeaders);

    final headerRow = effectiveColumns
        .map(
          (c) => InventoryExportFields.getHeaderLabel(
            c,
            customFieldDefinitions: customFieldDefinitions,
            isLegacy: effectiveIsLegacy,
          ),
        )
        .toList();

    final rows = <List<dynamic>>[headerRow];

    for (final summary in items) {
      final row = <dynamic>[];

      for (final col in effectiveColumns) {
        final val = InventoryExportFields.extractValue(
          summary,
          col,
          customFieldDefinitions: customFieldDefinitions,
        );

        if (val == null) {
          row.add('');
        } else if (val is num) {
          if (!val.toDouble().isFinite) {
            throw InventoryCsvSerializerException(
              'Invalid non-finite quantity for item SKU "${summary.item.sku}": $val',
            );
          }
          row.add(InventoryExportFields.formatQuantity(val.toDouble()));
        } else if (val is DateTime) {
          row.add(InventoryExportFields.formatDate(val));
        } else if (val is bool) {
          row.add(val ? 'true' : 'false');
        } else {
          // All string fields (including custom fields) are sanitized against formula injection
          row.add(InventoryExportFields.neutralizeFormula(val.toString()));
        }
      }

      rows.add(row);
    }

    const encoder = CsvEncoder(
      fieldDelimiter: ',',
      lineDelimiter: '\r\n',
    );

    return encoder.convert(rows);
  }

  /// Converts a list of [InventoryItemSummary] records into UTF-8 CSV bytes.
  Uint8List convertToBytes(
    List<InventoryItemSummary> items, {
    List<String>? columns,
    List<CustomFieldDefinition>? customFieldDefinitions,
    bool isLegacy = false,
  }) {
    final csvString = convertToString(
      items,
      columns: columns,
      customFieldDefinitions: customFieldDefinitions,
      isLegacy: isLegacy,
    );
    return Uint8List.fromList(utf8.encode(csvString));
  }
}
