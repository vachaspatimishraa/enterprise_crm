import 'custom_field_definition.dart';
import 'inventory_item_summary.dart';

/// Supported import file formats.
enum InventoryImportFileType { csv, xlsx }

/// Supported import modes.
enum InventoryImportMode {
  createAndUpdate('Create and Update (Upsert)'),
  createOnly('Create New Only'),
  updateOnly('Update Existing Only');

  const InventoryImportMode(this.label);
  final String label;
}

/// Blank value handling policy for existing item updates.
enum BlankValuePolicy {
  preserveExisting('Preserve existing value when source cell is blank'),
  clearOptional('Clear mapped optional value when source cell is blank');

  const BlankValuePolicy(this.label);
  final String label;
}

/// Planned action for a candidate import row.
enum InventoryImportAction {
  create('Create'),
  update('Update'),
  skip('Skip');

  const InventoryImportAction(this.label);
  final String label;
}

/// Supported target fields for inventory item import (all 21 standard fields).
enum InventoryImportField {
  name('Name', isRequired: true),
  sku('SKU', isRequired: true),
  category('Category', isRequired: false),
  brand('Brand', isRequired: false),
  unit('Unit', isRequired: false),
  barcode('Barcode', isRequired: false),
  warehouse('Warehouse', isRequired: false),
  binLocation('Bin Location', isRequired: false),
  supplier('Supplier', isRequired: false),
  unitCostInr('Unit Cost (INR)', isRequired: false),
  sellingPriceInr('Selling Price (INR)', isRequired: false),
  openingStock('Opening Stock', isRequired: false),
  reorderLevel('Reorder Level', isRequired: false),
  maxStock('Max Stock', isRequired: false),
  gstPercent('GST %', isRequired: false),
  batchNumber('Batch Number', isRequired: false),
  expiryDate('Expiry Date', isRequired: false),
  lastRestockedDate('Last Restocked Date', isRequired: false),
  isActive('Is Active', isRequired: false),
  expectedStockStatus('Expected Stock Status (Reference)', isRequired: false),
  notes('Notes', isRequired: false);

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
    this.standardFieldMappings = const {},
    this.customFieldMappings = const {},
    this.skippedColumnIndices = const {},
    this.stagedCustomFieldDefinitions = const [],
    this.importMode = InventoryImportMode.createOnly,
    this.blankValuePolicy = BlankValuePolicy.preserveExisting,
  });

  final int sheetIndex;
  final int headerRowIndex;
  final int? nameColumnIndex;
  final int? skuColumnIndex;
  final int? openingStockColumnIndex;
  final Map<int, InventoryImportField> standardFieldMappings;
  final Map<int, String> customFieldMappings;
  final Set<int> skippedColumnIndices;
  final List<CustomFieldDefinition> stagedCustomFieldDefinitions;
  final InventoryImportMode importMode;
  final BlankValuePolicy blankValuePolicy;

  bool get isValid => nameColumnIndex != null && skuColumnIndex != null;

  Set<int> get mappedColumnIndices => {
    ?nameColumnIndex,
    ?skuColumnIndex,
    ?openingStockColumnIndex,
    ...standardFieldMappings.keys,
    ...customFieldMappings.keys,
  };

  int? getColumnFor(InventoryImportField field) {
    if (field == InventoryImportField.name && nameColumnIndex != null) {
      return nameColumnIndex;
    }
    if (field == InventoryImportField.sku && skuColumnIndex != null) {
      return skuColumnIndex;
    }
    if (field == InventoryImportField.openingStock &&
        openingStockColumnIndex != null) {
      return openingStockColumnIndex;
    }
    for (final entry in standardFieldMappings.entries) {
      if (entry.value == field) return entry.key;
    }
    return null;
  }

  InventoryImportColumnMapping copyWith({
    int? sheetIndex,
    int? headerRowIndex,
    int? nameColumnIndex,
    bool clearName = false,
    int? skuColumnIndex,
    bool clearSku = false,
    int? openingStockColumnIndex,
    bool clearOpeningStock = false,
    Map<int, InventoryImportField>? standardFieldMappings,
    Map<int, String>? customFieldMappings,
    Set<int>? skippedColumnIndices,
    List<CustomFieldDefinition>? stagedCustomFieldDefinitions,
    InventoryImportMode? importMode,
    BlankValuePolicy? blankValuePolicy,
  }) {
    final effectiveName = clearName
        ? null
        : (nameColumnIndex ?? this.nameColumnIndex);
    final effectiveSku = clearSku
        ? null
        : (skuColumnIndex ?? this.skuColumnIndex);
    final effectiveOpeningStock = clearOpeningStock
        ? null
        : (openingStockColumnIndex ?? this.openingStockColumnIndex);

    final updatedStandard = Map<int, InventoryImportField>.from(
      standardFieldMappings ?? this.standardFieldMappings,
    );
    if (clearName && this.nameColumnIndex != null) {
      updatedStandard.remove(this.nameColumnIndex);
    } else if (effectiveName != null) {
      updatedStandard[effectiveName] = InventoryImportField.name;
    }

    if (clearSku && this.skuColumnIndex != null) {
      updatedStandard.remove(this.skuColumnIndex);
    } else if (effectiveSku != null) {
      updatedStandard[effectiveSku] = InventoryImportField.sku;
    }

    if (clearOpeningStock && this.openingStockColumnIndex != null) {
      updatedStandard.remove(this.openingStockColumnIndex);
    } else if (effectiveOpeningStock != null) {
      updatedStandard[effectiveOpeningStock] =
          InventoryImportField.openingStock;
    }

    return InventoryImportColumnMapping(
      sheetIndex: sheetIndex ?? this.sheetIndex,
      headerRowIndex: headerRowIndex ?? this.headerRowIndex,
      nameColumnIndex: effectiveName,
      skuColumnIndex: effectiveSku,
      openingStockColumnIndex: effectiveOpeningStock,
      standardFieldMappings: Map.unmodifiable(updatedStandard),
      customFieldMappings: customFieldMappings != null
          ? Map.unmodifiable(customFieldMappings)
          : this.customFieldMappings,
      skippedColumnIndices: skippedColumnIndices != null
          ? Set.unmodifiable(skippedColumnIndices)
          : this.skippedColumnIndices,
      stagedCustomFieldDefinitions: stagedCustomFieldDefinitions != null
          ? List.unmodifiable(stagedCustomFieldDefinitions)
          : this.stagedCustomFieldDefinitions,
      importMode: importMode ?? this.importMode,
      blankValuePolicy: blankValuePolicy ?? this.blankValuePolicy,
    );
  }
}

/// Validation status of a candidate preview row.
enum InventoryImportRowStatus { valid, invalid, duplicate, warning }

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
    this.warningMessage,
    required this.isSelected,
    this.action = InventoryImportAction.create,
    this.mappedValues = const {},
    this.existingItemId,
  });

  final int sourceRowNumber;
  final List<String> rawValues;
  final String name;
  final String sku;
  final double? openingStock;
  final InventoryImportRowStatus status;
  final String? errorMessage;
  final String? warningMessage;
  final bool isSelected;
  final InventoryImportAction action;
  final Map<String, dynamic> mappedValues;
  final String? existingItemId;

  bool get isSelectable =>
      status == InventoryImportRowStatus.valid ||
      status == InventoryImportRowStatus.warning;

  InventoryImportPreviewRow copyWith({
    bool? isSelected,
    InventoryImportRowStatus? status,
    String? errorMessage,
    String? warningMessage,
    InventoryImportAction? action,
    Map<String, dynamic>? mappedValues,
    String? existingItemId,
  }) {
    return InventoryImportPreviewRow(
      sourceRowNumber: sourceRowNumber,
      rawValues: rawValues,
      name: name,
      sku: sku,
      openingStock: openingStock,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      warningMessage: warningMessage ?? this.warningMessage,
      isSelected: isSelected ?? this.isSelected,
      action: action ?? this.action,
      mappedValues: mappedValues ?? this.mappedValues,
      existingItemId: existingItemId ?? this.existingItemId,
    );
  }
}

/// Aggregate preview data built from mapped source rows.
class InventoryImportPreview {
  const InventoryImportPreview({required this.rows});

  final List<InventoryImportPreviewRow> rows;

  int get totalRows => rows.length;
  int get validCount => rows
      .where(
        (r) =>
            r.status == InventoryImportRowStatus.valid ||
            r.status == InventoryImportRowStatus.warning,
      )
      .length;
  int get invalidCount =>
      rows.where((r) => r.status == InventoryImportRowStatus.invalid).length;
  int get duplicateCount =>
      rows.where((r) => r.status == InventoryImportRowStatus.duplicate).length;
  int get warningCount =>
      rows.where((r) => r.status == InventoryImportRowStatus.warning).length;
  int get createCount => rows
      .where((r) => r.action == InventoryImportAction.create && r.isSelectable)
      .length;
  int get updateCount => rows
      .where((r) => r.action == InventoryImportAction.update && r.isSelectable)
      .length;
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
    this.category,
    this.brand,
    this.unit,
    this.barcode,
    this.warehouse,
    this.binLocation,
    this.supplier,
    this.unitCostInr,
    this.sellingPriceInr,
    this.reorderLevel,
    this.maxStock,
    this.gstPercent,
    this.batchNumber,
    this.expiryDate,
    this.lastRestockedDate,
    this.isActive = true,
    this.notes,
    this.customFields = const {},
    this.isUpdate = false,
    this.existingItemId,
    this.clearBarcode = false,
    this.clearSupplier = false,
    this.clearUnitCost = false,
    this.clearNotes = false,
    this.clearBatchNumber = false,
    this.clearExpiryDate = false,
    this.clearLastRestockedDate = false,
    this.clearBinLocation = false,
    this.clearReorderLevel = false,
    this.clearMaxStock = false,
    this.clearGstPercent = false,
  });

  final int sourceRowNumber;
  final String name;
  final String sku;
  final double? openingStock;
  final String? category;
  final String? brand;
  final String? unit;
  final String? barcode;
  final String? warehouse;
  final String? binLocation;
  final String? supplier;
  final double? unitCostInr;
  final double? sellingPriceInr;
  final double? reorderLevel;
  final double? maxStock;
  final double? gstPercent;
  final String? batchNumber;
  final DateTime? expiryDate;
  final DateTime? lastRestockedDate;
  final bool isActive;
  final String? notes;
  final Map<String, dynamic> customFields;
  final bool isUpdate;
  final String? existingItemId;

  final bool clearBarcode;
  final bool clearSupplier;
  final bool clearUnitCost;
  final bool clearNotes;
  final bool clearBatchNumber;
  final bool clearExpiryDate;
  final bool clearLastRestockedDate;
  final bool clearBinLocation;
  final bool clearReorderLevel;
  final bool clearMaxStock;
  final bool clearGstPercent;
}

/// Request payload containing all selected rows to import.
class InventoryImportRequest {
  const InventoryImportRequest({
    required this.performedByUserId,
    required this.rows,
    this.stagedCustomFieldDefinitions = const [],
    this.mode = InventoryImportMode.createAndUpdate,
    this.blankValuePolicy = BlankValuePolicy.preserveExisting,
  });

  final String performedByUserId;
  final List<InventoryImportRowInput> rows;
  final List<CustomFieldDefinition> stagedCustomFieldDefinitions;
  final InventoryImportMode mode;
  final BlankValuePolicy blankValuePolicy;
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
    this.createdCount,
    this.updatedCount,
    this.skippedCount = 0,
    this.warningCount = 0,
  });

  final int requestedCount;
  final int successCount;
  final int failureCount;
  final List<InventoryItemSummary> importedSummaries;
  final List<InventoryImportRowFailure> failures;
  final int? createdCount;
  final int? updatedCount;
  final int skippedCount;
  final int warningCount;

  int get effectiveCreatedCount => createdCount ?? importedSummaries.length;
  int get effectiveUpdatedCount => updatedCount ?? 0;
}
