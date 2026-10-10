import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/mock_inventory_repository.dart';
import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_catalogs.dart';
import '../../domain/exceptions/inventory_exception.dart';
import '../../domain/inputs/update_inventory_item_input.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'edit_inventory_item_state.dart';

/// Cubit managing editing for an existing inventory item.
///
/// Ensures fresh item loading by [itemId], trimmed input validation,
/// maps domain exceptions to user-friendly messages, and guarantees double-submit protection.
class EditInventoryItemCubit extends Cubit<EditInventoryItemState> {
  final InventoryRepository _repository;
  String? _loadedItemId;

  EditInventoryItemCubit(this._repository)
    : super(const EditInventoryItemInitial());

  /// Loads fresh item details from [_repository] for [itemId].
  Future<void> load(String itemId) async {
    _loadedItemId = itemId;
    emit(const EditInventoryItemLoading());

    try {
      final summary = await _repository.getItemById(itemId);
      if (summary == null) {
        emit(const EditInventoryItemNotFound());
      } else {
        List<CustomFieldDefinition> defs = const [];
        InventoryCatalogs catalogs = InventoryCatalogs();

        final repo = _repository;
        if (repo is MockInventoryRepository) {
          defs = await repo.getCustomFieldDefinitions();
          catalogs = repo.catalogs;
        }

        emit(EditInventoryItemLoaded(
          summary,
          customFieldDefinitions: defs,
          catalogs: catalogs,
        ));
      }
    } catch (_) {
      emit(const EditInventoryItemFailure('Unable to load inventory item.'));
    }
  }

  /// Validates inputs and updates the inventory item.
  ///
  /// Double-submit guard: returns immediately if submission is already in progress.
  Future<void> submit({
    required String name,
    required String sku,
    String? category,
    String? brand,
    String? unit,
    String? barcode,
    String? warehouse,
    String? binLocation,
    String? supplier,
    double? unitCostInr,
    double? sellingPriceInr,
    double? reorderLevel,
    double? maxStock,
    double? gstPercent,
    String? batchNumber,
    DateTime? expiryDate,
    DateTime? lastRestockedDate,
    bool? isActive,
    String? notes,
    Map<String, dynamic>? customFields,
    bool clearBrand = false,
    bool clearBarcode = false,
    bool clearBinLocation = false,
    bool clearSupplier = false,
    bool clearUnitCostInr = false,
    bool clearSellingPriceInr = false,
    bool clearReorderLevel = false,
    bool clearMaxStock = false,
    bool clearGstPercent = false,
    bool clearBatchNumber = false,
    bool clearExpiryDate = false,
    bool clearLastRestockedDate = false,
    bool clearNotes = false,
  }) async {
    if (state is EditInventoryItemSubmitting) {
      return;
    }

    final currentSummary = switch (state) {
      EditInventoryItemLoaded(:final item) => item,
      EditInventoryItemSubmitting(:final item) => item,
      EditInventoryItemFailure(:final item) when item != null => item,
      _ => null,
    };

    if (currentSummary == null && _loadedItemId == null) {
      return;
    }

    final targetId = currentSummary?.item.id ?? _loadedItemId!;
    final trimmedName = name.trim();
    final trimmedSku = sku.trim();

    if (trimmedName.isEmpty) {
      emit(
        EditInventoryItemFailure(
          'Item name is required.',
          item: currentSummary,
        ),
      );
      return;
    }

    if (trimmedSku.isEmpty) {
      emit(EditInventoryItemFailure('SKU is required.', item: currentSummary));
      return;
    }

    if (currentSummary != null) {
      emit(EditInventoryItemSubmitting(currentSummary));
    }

    try {
      final updated = await _repository.updateItem(
        UpdateInventoryItemInput(
          id: targetId,
          name: trimmedName,
          sku: trimmedSku,
          category: category,
          brand: brand,
          unit: unit,
          barcode: barcode,
          warehouse: warehouse,
          binLocation: binLocation,
          supplier: supplier,
          unitCostInr: unitCostInr,
          sellingPriceInr: sellingPriceInr,
          reorderLevel: reorderLevel,
          maxStock: maxStock,
          gstPercent: gstPercent,
          batchNumber: batchNumber,
          expiryDate: expiryDate,
          lastRestockedDate: lastRestockedDate,
          isActive: isActive,
          notes: notes,
          customFields: customFields,
          clearBrand: clearBrand,
          clearBarcode: clearBarcode,
          clearBinLocation: clearBinLocation,
          clearSupplier: clearSupplier,
          clearUnitCostInr: clearUnitCostInr,
          clearSellingPriceInr: clearSellingPriceInr,
          clearReorderLevel: clearReorderLevel,
          clearMaxStock: clearMaxStock,
          clearGstPercent: clearGstPercent,
          clearBatchNumber: clearBatchNumber,
          clearExpiryDate: clearExpiryDate,
          clearLastRestockedDate: clearLastRestockedDate,
          clearNotes: clearNotes,
        ),
      );
      emit(EditInventoryItemSuccess(updated));
    } on InventoryItemNotFoundException {
      emit(const EditInventoryItemNotFound());
    } on InventoryValidationException catch (e) {
      emit(EditInventoryItemFailure(e.message, item: currentSummary));
    } on InventoryDuplicateSkuException {
      emit(
        EditInventoryItemFailure(
          'An item with this SKU already exists.',
          item: currentSummary,
        ),
      );
    } catch (_) {
      emit(
        EditInventoryItemFailure(
          'Unable to update inventory item.',
          item: currentSummary,
        ),
      );
    }
  }
}
