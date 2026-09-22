import 'package:flutter_bloc/flutter_bloc.dart';

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

  /// Validates inputs and creates an inventory item via [_repository].
  ///
  /// Double-submit guard: returns immediately if submission is already in progress.
  Future<void> submit({required String name, required String sku}) async {
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

    emit(const CreateInventoryItemSubmitting());

    try {
      final created = await _repository.createItem(
        CreateInventoryItemInput(name: trimmedName, sku: trimmedSku),
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
