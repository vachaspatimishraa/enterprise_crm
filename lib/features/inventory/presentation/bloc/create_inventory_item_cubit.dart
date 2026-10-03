import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/mock_inventory_repository.dart';
import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_catalogs.dart';
import '../../domain/exceptions/inventory_exception.dart';
import '../../domain/inputs/create_inventory_item_input.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'create_inventory_item_state.dart';

/// Cubit managing creation of a new inventory item.
///
/// Enforces trimmed input validation, maps domain exceptions to safe user messages,
/// and guarantees double-submit protection.
class CreateInventoryItemCubit extends Cubit<CreateInventoryItemState> {
  final InventoryRepository _repository;

  CreateInventoryItemCubit(this._repository)
    : super(const CreateInventoryItemInitial());

  /// Loads custom field definitions and configurable catalogs.
  Future<void> loadDefinitions() async {
    List<CustomFieldDefinition> defs = const [];
    InventoryCatalogs catalogs = InventoryCatalogs();

    final repo = _repository;
    if (repo is MockInventoryRepository) {
      defs = await repo.getCustomFieldDefinitions();
      catalogs = repo.catalogs;
    }

    emit(CreateInventoryItemInitial(
      customFieldDefinitions: defs,
      catalogs: catalogs,
    ));
  }

  /// Validates inputs and creates an inventory item via [_repository].
  ///
  /// Double-submit guard: returns immediately if submission is already in progress.
  Future<void> submit({
    required String name,
    required String sku,
    String? openingStockText,
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
    bool isActive = true,
    String? notes,
    Map<String, dynamic>? customFields,
    String? performedByUserId,
  }) async {
    if (state is CreateInventoryItemSubmitting) {
      return;
    }

    final trimmedName = name.trim();
    final trimmedSku = sku.trim();

    if (trimmedName.isEmpty) {
      emit(const CreateInventoryItemFailure('Item name is required.'));
      return;
    }

    if (trimmedSku.isEmpty) {
      emit(const CreateInventoryItemFailure('SKU is required.'));
      return;
    }

    double? parsedOpeningStock;
    if (openingStockText != null && openingStockText.trim().isNotEmpty) {
      final parsed = double.tryParse(openingStockText.trim());
      if (parsed == null || !parsed.isFinite || parsed <= 0) {
        emit(
          const CreateInventoryItemFailure(
            'Opening stock must be greater than zero.',
          ),
        );
        return;
      }
      parsedOpeningStock = parsed;
    }

    emit(const CreateInventoryItemSubmitting());

    try {
      final created = await _repository.createItem(
        CreateInventoryItemInput(
          name: trimmedName,
          sku: trimmedSku,
          openingStock: parsedOpeningStock,
          category: category ?? 'General',
          brand: brand,
          unit: unit ?? 'piece',
          barcode: barcode,
          warehouse: warehouse ?? 'Default',
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
          customFields: customFields ?? const {},
          performedByUserId: performedByUserId,
        ),
      );
      emit(CreateInventoryItemSuccess(created));
    } on InventoryValidationException catch (e) {
      emit(CreateInventoryItemFailure(e.message));
    } on InventoryDuplicateSkuException {
      emit(
        const CreateInventoryItemFailure(
          'An item with this SKU already exists.',
        ),
      );
    } catch (_) {
      emit(
        const CreateInventoryItemFailure('Unable to create inventory item.'),
      );
    }
  }
}
