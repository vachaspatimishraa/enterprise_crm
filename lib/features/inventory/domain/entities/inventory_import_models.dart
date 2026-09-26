import 'inventory_item_summary.dart';

/// Supported import file formats.
enum InventoryImportFileType { csv, xlsx }

/// Supported target fields for inventory item import.
enum InventoryImportField {
  name('Name', isRequired: true),
  sku('SKU', isRequired: true),
  openingStock('Opening Stock', isRequired: false);

  const InventoryImportField(this.label, {required this.isRequired});
  final String label;
  final bool isRequired;
}

/// Explicit mapping from source spreadsheet column indices to inventory fields.
class InventoryImportColumnMapping {
  const InventoryImportColumnMapping({
    required this.sheetIndex,
    required this.headerRowIndex,
    this.nameColumnIndex,
    this.skuColumnIndex,
    this.openingStockColumnIndex,
  });

  final int sheetIndex;
  final int headerRowIndex;
  final int? nameColumnIndex;
  final int? skuColumnIndex;
  final int? openingStockColumnIndex;

  bool get isValid => nameColumnIndex != null && skuColumnIndex != null;

  Set<int> get mappedColumnIndices => {
    ?nameColumnIndex,
    ?skuColumnIndex,
    ?openingStockColumnIndex,
  };

  int? getColumnFor(InventoryImportField field) => switch (field) {
    InventoryImportField.name => nameColumnIndex,
    InventoryImportField.sku => skuColumnIndex,
    InventoryImportField.openingStock => openingStockColumnIndex,
  };

  InventoryImportColumnMapping copyWith({
    int? sheetIndex,
    int? headerRowIndex,
    int? nameColumnIndex,
    bool clearName = false,
    int? skuColumnIndex,
    bool clearSku = false,
    int? openingStockColumnIndex,
    bool clearOpeningStock = false,
  }) {
    return InventoryImportColumnMapping(
      sheetIndex: sheetIndex ?? this.sheetIndex,
      headerRowIndex: headerRowIndex ?? this.headerRowIndex,
      nameColumnIndex: clearName
          ? null
          : (nameColumnIndex ?? this.nameColumnIndex),
      skuColumnIndex: clearSku ? null : (skuColumnIndex ?? this.skuColumnIndex),
      openingStockColumnIndex: clearOpeningStock
          ? null
          : (openingStockColumnIndex ?? this.openingStockColumnIndex),
    );
  }
}

/// Validation status of a candidate preview row.
enum InventoryImportRowStatus { valid, invalid, duplicate }

/// A single evaluated spreadsheet row in the import preview.
class InventoryImportPreviewRow {
  const InventoryImportPreviewRow({
    required this.sourceRowNumber,
    required this.rawValues,
    required this.name,
    required this.sku,
    this.openingStock,
    required this.status,
    this.errorMessage,
    required this.isSelected,
  });

  final int sourceRowNumber;
  final List<String> rawValues;
  final String name;
  final String sku;
  final double? openingStock;
  final InventoryImportRowStatus status;
  final String? errorMessage;
  final bool isSelected;

  bool get isSelectable => status == InventoryImportRowStatus.valid;

  InventoryImportPreviewRow copyWith({
    bool? isSelected,
    InventoryImportRowStatus? status,
    String? errorMessage,
  }) {
    return InventoryImportPreviewRow(
      sourceRowNumber: sourceRowNumber,
      rawValues: rawValues,
      name: name,
      sku: sku,
      openingStock: openingStock,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Aggregate preview data built from mapped source rows.
class InventoryImportPreview {
  const InventoryImportPreview({required this.rows});

  final List<InventoryImportPreviewRow> rows;

  int get totalRows => rows.length;
  int get validCount =>
      rows.where((r) => r.status == InventoryImportRowStatus.valid).length;
  int get invalidCount =>
      rows.where((r) => r.status == InventoryImportRowStatus.invalid).length;
  int get duplicateCount =>
      rows.where((r) => r.status == InventoryImportRowStatus.duplicate).length;
  int get selectedCount => rows.where((r) => r.isSelected).length;
  List<InventoryImportPreviewRow> get selectedRows =>
      rows.where((r) => r.isSelected).toList(growable: false);
}

/// Input model for a single row to be imported by the repository.
class InventoryImportRowInput {
  const InventoryImportRowInput({
    required this.sourceRowNumber,
    required this.name,
    required this.sku,
    this.openingStock,
  });

  final int sourceRowNumber;
  final String name;
  final String sku;
  final double? openingStock;
}

/// Request payload containing all selected rows to import.
class InventoryImportRequest {
  const InventoryImportRequest({
    required this.performedByUserId,
    required this.rows,
  });

  final String performedByUserId;
  final List<InventoryImportRowInput> rows;
}

/// Details of a row that failed during repository import.
class InventoryImportRowFailure {
  const InventoryImportRowFailure({
    required this.sourceRowNumber,
    required this.sku,
    required this.reason,
  });

  final int sourceRowNumber;
  final String sku;
  final String reason;
}

/// Structured result of an inventory import operation.
class InventoryImportResult {
  const InventoryImportResult({
    required this.requestedCount,
    required this.successCount,
    required this.failureCount,
    required this.importedSummaries,
    required this.failures,
  });

  final int requestedCount;
  final int successCount;
  final int failureCount;
  final List<InventoryItemSummary> importedSummaries;
  final List<InventoryImportRowFailure> failures;
}
