import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/exceptions/inventory_exception.dart';
import '../../domain/inputs/update_inventory_item_input.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'edit_inventory_item_state.dart';

/// Cubit managing identity editing for an existing inventory item.
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
        emit(EditInventoryItemLoaded(summary));
      }
    } catch (_) {
      emit(const EditInventoryItemFailure('Unable to load inventory item.'));
    }
  }

  /// Validates inputs and updates the inventory item's identity.
  ///
  /// Double-submit guard: returns immediately if submission is already in progress.
  Future<void> submit({required String name, required String sku}) async {
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
