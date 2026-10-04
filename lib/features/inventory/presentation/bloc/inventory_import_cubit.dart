import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../data/repositories/mock_inventory_repository.dart';
import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_catalogs.dart';
import '../../domain/entities/inventory_import_models.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/policies/inventory_import_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../services/inventory_import_file_picker.dart';
import '../services/inventory_import_parser.dart';
import '../services/inventory_import_preview_builder.dart';
import 'inventory_import_state.dart';

/// State management Cubit for coordinating the full CSV/XLSX Inventory Import workflow.
class InventoryImportCubit extends Cubit<InventoryImportState> {
  InventoryImportCubit({
    required this.user,
    required this.repository,
    this.filePicker = const DefaultInventoryImportFilePicker(),
    this.parser = const DefaultInventoryImportParser(),
    this.previewBuilder = const InventoryImportPreviewBuilder(),
  }) : super(const InventoryImportInitial());

  List<String> get allowedExtensions {
    final list = <String>[];
    if (InventoryImportPolicy.canImportCsv(user)) list.add('csv');
    if (InventoryImportPolicy.canImportXlsx(user)) list.add('xlsx');
    return List.unmodifiable(list);
  }

  final CurrentUser user;
  final InventoryRepository repository;
  final InventoryImportFilePicker filePicker;
  final InventoryImportParser parser;
  final InventoryImportPreviewBuilder previewBuilder;

  bool _isImporting = false;

  Future<void> selectFileAndParse() async => pickAndParseFile();

  Future<void> pickAndParseFile() async {
    emit(const InventoryImportLoading('Selecting file...'));

    try {
      final exts = allowedExtensions;
      final selectedFile = await filePicker.pickFile(
        allowedExtensions: exts,
      );

      if (selectedFile == null) {
        emit(const InventoryImportInitial());
        return;
      }

      if (!exts.contains(selectedFile.extension.toLowerCase())) {
        emit(
          const InventoryImportErrorState(
            message: 'You are not authorized to import this file format.',
            fallbackState: InventoryImportInitial(),
          ),
        );
        return;
      }

      emit(const InventoryImportLoading('Parsing file...'));
      final parsed = await parser.parse(selectedFile);

      if (parsed.sheets.length > 1) {
        // Multi-sheet XLSX: require explicit sheet selection
        // Default to 'Inventory_Data' if present as master sheet
        var defaultSheetIdx = 0;
        for (var i = 0; i < parsed.sheets.length; i++) {
          if (parsed.sheets[i].name.trim().toLowerCase() == 'inventory_data') {
            defaultSheetIdx = i;
            break;
          }
        }

        emit(
          InventoryImportSheetSelect(
            file: parsed,
            selectedSheetIndex: defaultSheetIdx,
          ),
        );
      } else {
        // Single sheet (CSV or single-sheet XLSX)
        emit(
          InventoryImportHeaderSelect(
            file: parsed,
            sheetIndex: 0,
            selectedHeaderRowIndex: 0,
          ),
        );
      }
    } on InventoryImportParseException catch (e) {
      emit(
        InventoryImportErrorState(
          message: e.message,
          fallbackState: const InventoryImportInitial(),
        ),
      );
    } catch (e) {
      emit(
        InventoryImportErrorState(
          message: 'An unexpected error occurred while reading the file: $e',
          fallbackState: const InventoryImportInitial(),
        ),
      );
    }
  }

  void selectSheetIndex(int index) => selectSheet(index);

  void selectSheet(int index) {
    if (state is! InventoryImportSheetSelect) return;
    final curr = state as InventoryImportSheetSelect;
    emit(curr.copyWith(selectedSheetIndex: index));
  }

  void confirmSheet() {
    if (state is! InventoryImportSheetSelect) return;
    final curr = state as InventoryImportSheetSelect;
    emit(
      InventoryImportHeaderSelect(
        file: curr.file,
        sheetIndex: curr.selectedSheetIndex,
        selectedHeaderRowIndex: 0,
      ),
    );
  }

  void selectHeaderRowIndex(int index) {
    if (state is! InventoryImportHeaderSelect) return;
    final curr = state as InventoryImportHeaderSelect;
    emit(curr.copyWith(selectedHeaderRowIndex: index));
  }

  void confirmHeaderRow() {
    if (state is! InventoryImportHeaderSelect) return;
    final curr = state as InventoryImportHeaderSelect;
    final sheet = curr.sheet;

    final headerRow = curr.selectedHeaderRowIndex < sheet.rows.length
        ? sheet.rows[curr.selectedHeaderRowIndex]
        : <String>[];

    final availableColumns = List<String>.generate(headerRow.length, (i) {
      final text = headerRow[i].trim();
      return text.isEmpty ? 'Column ${i + 1}' : 'Col ${i + 1}: $text';
    });

    List<CustomFieldDefinition> customDefs = const [];
    InventoryCatalogs catalogs = InventoryCatalogs();
    final repo = repository;
    if (repo is MockInventoryRepository) {
      customDefs = repo.customFieldDefinitions;
      catalogs = repo.catalogs;
    }

    final standardMappings = <int, InventoryImportField>{};
    final customMappings = <int, String>{};
    final mappedStandard = <InventoryImportField>{};

    for (var i = 0; i < headerRow.length; i++) {
      final text = headerRow[i].trim();
      final norm = text.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '_');

      final stdMatch = _autoMatchStandardField(norm);
      if (stdMatch != null && !mappedStandard.contains(stdMatch)) {
        standardMappings[i] = stdMatch;
        mappedStandard.add(stdMatch);
        continue;
      }

      for (final def in customDefs) {
        final defKeyNorm =
            def.key.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '_');
        final defLabelNorm =
            def.label.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '_');
        if (norm == defKeyNorm || norm == defLabelNorm) {
          customMappings[i] = def.key;
          break;
        }
      }
    }

    emit(
      InventoryImportMappingState(
        file: curr.file,
        sheetIndex: curr.sheetIndex,
        headerRowIndex: curr.selectedHeaderRowIndex,
        availableColumns: List.unmodifiable(availableColumns),
        customFieldDefinitions: customDefs,
        catalogs: catalogs,
        mapping: InventoryImportColumnMapping(
          sheetIndex: curr.sheetIndex,
          headerRowIndex: curr.selectedHeaderRowIndex,
          nameColumnIndex: null,
          skuColumnIndex: null,
          openingStockColumnIndex: null,
          standardFieldMappings: Map.unmodifiable(standardMappings),
          customFieldMappings: Map.unmodifiable(customMappings),
        ),
      ),
    );
  }

  InventoryImportField? _autoMatchStandardField(String norm) {
    if (norm == 'sku' ||
        norm == 'item_sku' ||
        norm == 'item_code' ||
        norm == 'product_sku') {
      return InventoryImportField.sku;
    }
    if (norm == 'product_name' ||
        norm == 'item_name' ||
        norm == 'name' ||
        norm == 'product' ||
        norm == 'title') {
      return InventoryImportField.name;
    }
    if (norm == 'category' ||
        norm == 'product_category' ||
        norm == 'item_category') {
      return InventoryImportField.category;
    }
    if (norm == 'brand' || norm == 'make' || norm == 'manufacturer') {
      return InventoryImportField.brand;
    }
    if (norm == 'unit' ||
        norm == 'uom' ||
        norm == 'unit_of_measure' ||
        norm == 'unitofmeasure') {
      return InventoryImportField.unit;
    }
    if (norm == 'barcode' || norm == 'upc' || norm == 'ean' || norm == 'gtin') {
      return InventoryImportField.barcode;
    }
    if (norm == 'warehouse' || norm == 'location' || norm == 'wh') {
      return InventoryImportField.warehouse;
    }
    if (norm == 'bin_location' || norm == 'bin' || norm == 'shelf') {
      return InventoryImportField.binLocation;
    }
    if (norm == 'supplier' || norm == 'vendor') {
      return InventoryImportField.supplier;
    }
    if (norm == 'unit_cost_inr' ||
        norm == 'unit_cost' ||
        norm == 'cost' ||
        norm == 'purchase_cost' ||
        norm == 'cost_price') {
      return InventoryImportField.unitCostInr;
    }
    if (norm == 'selling_price_inr' ||
        norm == 'selling_price' ||
        norm == 'price' ||
        norm == 'sale_price' ||
        norm == 'mrp') {
      return InventoryImportField.sellingPriceInr;
    }
    if (norm == 'stock_quantity' ||
        norm == 'opening_stock' ||
        norm == 'stock_qty' ||
        norm == 'quantity' ||
        norm == 'qty') {
      return InventoryImportField.openingStock;
    }
    if (norm == 'reorder_level' ||
        norm == 'reorder_point' ||
        norm == 'min_stock') {
      return InventoryImportField.reorderLevel;
    }
    if (norm == 'max_stock' ||
        norm == 'max_quantity' ||
        norm == 'maximum_stock') {
      return InventoryImportField.maxStock;
    }
    if (norm == 'gst_percent' ||
        norm == 'gst' ||
        norm == 'tax_percent' ||
        norm == 'tax') {
      return InventoryImportField.gstPercent;
    }
    if (norm == 'batch_number' ||
        norm == 'batch' ||
        norm == 'lot_number' ||
        norm == 'lot') {
      return InventoryImportField.batchNumber;
    }
    if (norm == 'expiry_date' ||
        norm == 'expiration_date' ||
        norm == 'exp_date') {
      return InventoryImportField.expiryDate;
    }
    if (norm == 'last_restocked_date' ||
        norm == 'restocked_date' ||
        norm == 'last_restocked') {
      return InventoryImportField.lastRestockedDate;
    }
    if (norm == 'is_active' || norm == 'active') {
      return InventoryImportField.isActive;
    }
    if (norm == 'expected_stock_status' ||
        norm == 'stock_status' ||
        norm == 'status') {
      return InventoryImportField.expectedStockStatus;
    }
    if (norm == 'notes' ||
        norm == 'comments' ||
        norm == 'remarks' ||
        norm == 'description') {
      return InventoryImportField.notes;
    }
    return null;
  }

  void setColumnStandardField(int columnIndex, InventoryImportField? field) {
    if (state is! InventoryImportMappingState) return;
    final curr = state as InventoryImportMappingState;
    final mapping = curr.mapping;

    final updatedStandard =
        Map<int, InventoryImportField>.from(mapping.standardFieldMappings);
    final updatedCustom = Map<int, String>.from(mapping.customFieldMappings);
    final updatedSkipped = Set<int>.from(mapping.skippedColumnIndices);

    updatedCustom.remove(columnIndex);
    updatedSkipped.remove(columnIndex);

    if (field != null) {
      updatedStandard.removeWhere((col, f) => f == field);
      updatedStandard[columnIndex] = field;
    } else {
      updatedStandard.remove(columnIndex);
    }

    int? newName = mapping.nameColumnIndex;
    int? newSku = mapping.skuColumnIndex;
    int? newOpening = mapping.openingStockColumnIndex;

    if (mapping.nameColumnIndex == columnIndex && field != InventoryImportField.name) {
      newName = null;
    }
    if (mapping.skuColumnIndex == columnIndex && field != InventoryImportField.sku) {
      newSku = null;
    }
    if (mapping.openingStockColumnIndex == columnIndex && field != InventoryImportField.openingStock) {
      newOpening = null;
    }

    if (field == InventoryImportField.name) newName = columnIndex;
    if (field == InventoryImportField.sku) newSku = columnIndex;
    if (field == InventoryImportField.openingStock) newOpening = columnIndex;

    emit(
      curr.copyWith(
        mapping: mapping.copyWith(
          nameColumnIndex: newName,
          clearName: newName == null,
          skuColumnIndex: newSku,
          clearSku: newSku == null,
          openingStockColumnIndex: newOpening,
          clearOpeningStock: newOpening == null,
          standardFieldMappings: updatedStandard,
          customFieldMappings: updatedCustom,
          skippedColumnIndices: updatedSkipped,
        ),
        clearValidationError: true,
      ),
    );
  }

  void setFieldMapping(InventoryImportField field, int? columnIndex) {
    if (state is! InventoryImportMappingState) return;
    final curr = state as InventoryImportMappingState;
    final mapping = curr.mapping;

    final updatedStandard =
        Map<int, InventoryImportField>.from(mapping.standardFieldMappings);
    final updatedCustom = Map<int, String>.from(mapping.customFieldMappings);
    final updatedSkipped = Set<int>.from(mapping.skippedColumnIndices);

    // Remove any previous column mapped to this standard field
    updatedStandard.removeWhere((col, f) => f == field);

    int? newName = (field == InventoryImportField.name)
        ? columnIndex
        : mapping.nameColumnIndex;
    int? newSku = (field == InventoryImportField.sku)
        ? columnIndex
        : mapping.skuColumnIndex;
    int? newOpeningStock = (field == InventoryImportField.openingStock)
        ? columnIndex
        : mapping.openingStockColumnIndex;

    if (columnIndex != null) {
      updatedCustom.remove(columnIndex);
      updatedSkipped.remove(columnIndex);
      updatedStandard[columnIndex] = field;

      if (field == InventoryImportField.name) {
        newName = columnIndex;
      } else if (field == InventoryImportField.sku) {
        newSku = columnIndex;
      } else if (field == InventoryImportField.openingStock) {
        newOpeningStock = columnIndex;
      }
    } else {
      if (field == InventoryImportField.name) newName = null;
      if (field == InventoryImportField.sku) newSku = null;
      if (field == InventoryImportField.openingStock) newOpeningStock = null;
    }

    emit(
      curr.copyWith(
        mapping: mapping.copyWith(
          nameColumnIndex: newName,
          clearName: newName == null,
          skuColumnIndex: newSku,
          clearSku: newSku == null,
          openingStockColumnIndex: newOpeningStock,
          clearOpeningStock: newOpeningStock == null,
          standardFieldMappings: updatedStandard,
          customFieldMappings: updatedCustom,
          skippedColumnIndices: updatedSkipped,
        ),
        clearValidationError: true,
      ),
    );
  }

  void setColumnCustomField(int columnIndex, String? customFieldKey) {
    if (state is! InventoryImportMappingState) return;
    final curr = state as InventoryImportMappingState;
    final mapping = curr.mapping;

    final updatedStandard =
        Map<int, InventoryImportField>.from(mapping.standardFieldMappings);
    final updatedCustom = Map<int, String>.from(mapping.customFieldMappings);
    final updatedSkipped = Set<int>.from(mapping.skippedColumnIndices);

    updatedStandard.remove(columnIndex);
    updatedSkipped.remove(columnIndex);

    int? newName = mapping.nameColumnIndex == columnIndex
        ? null
        : mapping.nameColumnIndex;
    int? newSku =
        mapping.skuColumnIndex == columnIndex ? null : mapping.skuColumnIndex;
    int? newOpening = mapping.openingStockColumnIndex == columnIndex
        ? null
        : mapping.openingStockColumnIndex;

    if (customFieldKey != null && customFieldKey.isNotEmpty) {
      updatedCustom[columnIndex] = customFieldKey;
    } else {
      updatedCustom.remove(columnIndex);
    }

    emit(
      curr.copyWith(
        mapping: mapping.copyWith(
          nameColumnIndex: newName,
          clearName: newName == null,
          skuColumnIndex: newSku,
          clearSku: newSku == null,
          openingStockColumnIndex: newOpening,
          clearOpeningStock: newOpening == null,
          standardFieldMappings: updatedStandard,
          customFieldMappings: updatedCustom,
          skippedColumnIndices: updatedSkipped,
        ),
        clearValidationError: true,
      ),
    );
  }

  void setColumnSkipped(int columnIndex, bool skipped) {
    if (state is! InventoryImportMappingState) return;
    final curr = state as InventoryImportMappingState;
    final mapping = curr.mapping;

    final updatedStandard =
        Map<int, InventoryImportField>.from(mapping.standardFieldMappings);
    final updatedCustom = Map<int, String>.from(mapping.customFieldMappings);
    final updatedSkipped = Set<int>.from(mapping.skippedColumnIndices);

    int? newName = mapping.nameColumnIndex == columnIndex
        ? null
        : mapping.nameColumnIndex;
    int? newSku =
        mapping.skuColumnIndex == columnIndex ? null : mapping.skuColumnIndex;
    int? newOpening = mapping.openingStockColumnIndex == columnIndex
        ? null
        : mapping.openingStockColumnIndex;

    if (skipped) {
      updatedStandard.remove(columnIndex);
      updatedCustom.remove(columnIndex);
      updatedSkipped.add(columnIndex);
    } else {
      updatedSkipped.remove(columnIndex);
    }

    emit(
      curr.copyWith(
        mapping: mapping.copyWith(
          nameColumnIndex: newName,
          clearName: newName == null,
          skuColumnIndex: newSku,
          clearSku: newSku == null,
          openingStockColumnIndex: newOpening,
          clearOpeningStock: newOpening == null,
          standardFieldMappings: updatedStandard,
          customFieldMappings: updatedCustom,
          skippedColumnIndices: updatedSkipped,
        ),
        clearValidationError: true,
      ),
    );
  }

  void addStagedCustomDefinition(
    CustomFieldDefinition def,
    int columnIndex,
  ) {
    if (state is! InventoryImportMappingState) return;
    final curr = state as InventoryImportMappingState;
    final mapping = curr.mapping;

    final updatedStaged =
        List<CustomFieldDefinition>.from(mapping.stagedCustomFieldDefinitions);
    if (!updatedStaged.any((d) => d.key == def.key)) {
      updatedStaged.add(def);
    }

    final updatedCustom = Map<int, String>.from(mapping.customFieldMappings);
    final updatedStandard =
        Map<int, InventoryImportField>.from(mapping.standardFieldMappings);
    final updatedSkipped = Set<int>.from(mapping.skippedColumnIndices);

    updatedStandard.remove(columnIndex);
    updatedSkipped.remove(columnIndex);
    updatedCustom[columnIndex] = def.key;

    final updatedDefs =
        List<CustomFieldDefinition>.from(curr.customFieldDefinitions);
    if (!updatedDefs.any((d) => d.key == def.key)) {
      updatedDefs.add(def);
    }

    emit(
      curr.copyWith(
        customFieldDefinitions: updatedDefs,
        mapping: mapping.copyWith(
          stagedCustomFieldDefinitions: updatedStaged,
          customFieldMappings: updatedCustom,
          standardFieldMappings: updatedStandard,
          skippedColumnIndices: updatedSkipped,
        ),
        clearValidationError: true,
      ),
    );
  }

  void setImportMode(InventoryImportMode mode) {
    if (state is! InventoryImportMappingState) return;
    final curr = state as InventoryImportMappingState;
    emit(curr.copyWith(mapping: curr.mapping.copyWith(importMode: mode)));
  }

  void setBlankValuePolicy(BlankValuePolicy policy) {
    if (state is! InventoryImportMappingState) return;
    final curr = state as InventoryImportMappingState;
    emit(curr.copyWith(mapping: curr.mapping.copyWith(blankValuePolicy: policy)));
  }

  Future<void> confirmMapping() async {
    if (state is! InventoryImportMappingState) return;
    final curr = state as InventoryImportMappingState;

    if (!curr.mapping.isValid) {
      emit(
        curr.copyWith(validationError: 'Please map both Name and SKU columns.'),
      );
      return;
    }

    emit(const InventoryImportLoading('Building preview...'));

    try {
      final existingSkus = await repository.getExistingSkus();

      Map<String, InventoryItem> existingItems = {};
      final repo = repository;
      if (repo is MockInventoryRepository) {
        existingItems = await repo.getExistingItemsBySku();
      }

      final preview = previewBuilder.build(
        sheet: curr.sheet,
        mapping: curr.mapping,
        existingSkus: existingSkus,
        user: user,
        catalogs: curr.catalogs,
        customFieldDefinitions: curr.customFieldDefinitions,
        existingItemsBySku: existingItems,
      );

      emit(
        InventoryImportPreviewState(
          file: curr.file,
          sheetIndex: curr.sheetIndex,
          mapping: curr.mapping,
          preview: preview,
        ),
      );
    } catch (e) {
      emit(
        InventoryImportErrorState(
          message: 'Failed to build preview: $e',
          fallbackState: curr,
        ),
      );
    }
  }

  void toggleRowSelection(int sourceRowNumber) {
    if (state is! InventoryImportPreviewState) return;
    final curr = state as InventoryImportPreviewState;

    final updatedRows = curr.preview.rows
        .map((row) {
          if (row.sourceRowNumber == sourceRowNumber && row.isSelectable) {
            return row.copyWith(isSelected: !row.isSelected);
          }
          return row;
        })
        .toList(growable: false);

    emit(curr.copyWith(preview: InventoryImportPreview(rows: updatedRows)));
  }

  void selectAllValid() {
    if (state is! InventoryImportPreviewState) return;
    final curr = state as InventoryImportPreviewState;

    final updatedRows = curr.preview.rows
        .map((row) {
          if (row.isSelectable) {
            return row.copyWith(isSelected: true);
          }
          return row;
        })
        .toList(growable: false);

    emit(curr.copyWith(preview: InventoryImportPreview(rows: updatedRows)));
  }

  void deselectAll() {
    if (state is! InventoryImportPreviewState) return;
    final curr = state as InventoryImportPreviewState;

    final updatedRows = curr.preview.rows
        .map((row) {
          return row.copyWith(isSelected: false);
        })
        .toList(growable: false);

    emit(curr.copyWith(preview: InventoryImportPreview(rows: updatedRows)));
  }

  void setPreviewFilter(String filter) {
    if (state is! InventoryImportPreviewState) return;
    final curr = state as InventoryImportPreviewState;
    emit(curr.copyWith(filter: filter));
  }

  Future<void> executeImport() async {
    if (_isImporting) return;
    if (state is! InventoryImportPreviewState) return;
    final curr = state as InventoryImportPreviewState;

    if (curr.preview.selectedCount == 0) return;

    // Fail closed if user is no longer authorized
    if (!InventoryImportPolicy.canImport(user)) {
      emit(
        const InventoryImportErrorState(
          message: 'You are not authorized to perform inventory imports.',
        ),
      );
      return;
    }

    final hasCreates = curr.preview.selectedRows
        .any((r) => r.action == InventoryImportAction.create);
    final hasUpdates = curr.preview.selectedRows
        .any((r) => r.action == InventoryImportAction.update);

    if (hasCreates && !InventoryImportPolicy.canCreate(user)) {
      emit(
        const InventoryImportErrorState(
          message: 'You are not authorized to create inventory items.',
        ),
      );
      return;
    }

    if (hasUpdates && !InventoryImportPolicy.canEdit(user)) {
      emit(
        const InventoryImportErrorState(
          message: 'You are not authorized to edit inventory items.',
        ),
      );
      return;
    }

    if (curr.mapping.stagedCustomFieldDefinitions.isNotEmpty &&
        !InventoryImportPolicy.canManageCustomFields(user)) {
      emit(
        const InventoryImportErrorState(
          message: 'You are not authorized to define new custom fields.',
        ),
      );
      return;
    }

    _isImporting = true;
    emit(InventoryImportSubmitting(preview: curr.preview));

    try {
      final clearOptional =
          curr.mapping.blankValuePolicy == BlankValuePolicy.clearOptional;

      final selectedInputs = curr.preview.selectedRows
          .map((r) {
            final mv = r.mappedValues;
            final isUpdate = r.action == InventoryImportAction.update;

            return InventoryImportRowInput(
              sourceRowNumber: r.sourceRowNumber,
              name: r.name,
              sku: r.sku,
              openingStock: r.openingStock,
              category: mv['category'] as String?,
              brand: mv['brand'] as String?,
              unit: mv['unit'] as String?,
              barcode: mv['barcode'] as String?,
              warehouse: mv['warehouse'] as String?,
              binLocation: mv['binLocation'] as String?,
              supplier: mv['supplier'] as String?,
              unitCostInr: mv['unitCostInr'] as double?,
              sellingPriceInr: mv['sellingPriceInr'] as double?,
              reorderLevel: mv['reorderLevel'] as double?,
              maxStock: mv['maxStock'] as double?,
              gstPercent: mv['gstPercent'] as double?,
              batchNumber: mv['batchNumber'] as String?,
              expiryDate: mv['expiryDate'] as DateTime?,
              lastRestockedDate: mv['lastRestockedDate'] as DateTime?,
              isActive: (mv['isActive'] as bool?) ?? true,
              notes: mv['notes'] as String?,
              customFields:
                  (mv['customFields'] as Map<String, dynamic>?) ?? const {},
              isUpdate: isUpdate,
              existingItemId: r.existingItemId,
              clearBarcode: isUpdate && clearOptional && mv['barcode'] == null,
              clearSupplier:
                  isUpdate && clearOptional && mv['supplier'] == null,
              clearUnitCost:
                  isUpdate && clearOptional && mv['unitCostInr'] == null,
              clearNotes: isUpdate && clearOptional && mv['notes'] == null,
              clearBatchNumber:
                  isUpdate && clearOptional && mv['batchNumber'] == null,
              clearExpiryDate:
                  isUpdate && clearOptional && mv['expiryDate'] == null,
              clearLastRestockedDate:
                  isUpdate && clearOptional && mv['lastRestockedDate'] == null,
              clearBinLocation:
                  isUpdate && clearOptional && mv['binLocation'] == null,
              clearReorderLevel:
                  isUpdate && clearOptional && mv['reorderLevel'] == null,
              clearMaxStock:
                  isUpdate && clearOptional && mv['maxStock'] == null,
              clearGstPercent:
                  isUpdate && clearOptional && mv['gstPercent'] == null,
            );
          })
          .toList(growable: false);

      final request = InventoryImportRequest(
        performedByUserId: user.id,
        rows: selectedInputs,
        stagedCustomFieldDefinitions:
            curr.mapping.stagedCustomFieldDefinitions,
        mode: curr.mapping.importMode,
        blankValuePolicy: curr.mapping.blankValuePolicy,
      );

      final result = await repository.importItems(request);
      emit(InventoryImportSuccessState(result: result));
    } catch (e) {
      emit(
        InventoryImportErrorState(
          message: 'Failed to complete import: $e',
          fallbackState: curr,
        ),
      );
    } finally {
      _isImporting = false;
    }
  }

  void backToFileSelection() {
    emit(const InventoryImportInitial());
  }

  void backToSheetSelection() {
    if (state is InventoryImportHeaderSelect) {
      final curr = state as InventoryImportHeaderSelect;
      if (curr.file.sheets.length > 1) {
        emit(
          InventoryImportSheetSelect(
            file: curr.file,
            selectedSheetIndex: curr.sheetIndex,
          ),
        );
        return;
      }
    }
    emit(const InventoryImportInitial());
  }

  void backToHeaderSelection() {
    if (state is InventoryImportMappingState) {
      final curr = state as InventoryImportMappingState;
      emit(
        InventoryImportHeaderSelect(
          file: curr.file,
          sheetIndex: curr.sheetIndex,
          selectedHeaderRowIndex: curr.headerRowIndex,
        ),
      );
    }
  }

  void backToMapping() {
    if (state is InventoryImportPreviewState) {
      final curr = state as InventoryImportPreviewState;
      final sheet = curr.file.sheets[curr.sheetIndex];
      final headerRow = curr.mapping.headerRowIndex < sheet.rows.length
          ? sheet.rows[curr.mapping.headerRowIndex]
          : <String>[];

      final availableColumns = List<String>.generate(headerRow.length, (i) {
        final text = headerRow[i].trim();
        return text.isEmpty ? 'Column ${i + 1}' : 'Col ${i + 1}: $text';
      });

      emit(
        InventoryImportMappingState(
          file: curr.file,
          sheetIndex: curr.sheetIndex,
          headerRowIndex: curr.mapping.headerRowIndex,
          availableColumns: List.unmodifiable(availableColumns),
          mapping: curr.mapping,
        ),
      );
    }
  }
}
