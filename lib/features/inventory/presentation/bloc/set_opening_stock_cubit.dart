import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/exceptions/inventory_exception.dart';
import '../../domain/inputs/record_opening_stock_input.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'set_opening_stock_state.dart';

/// Cubit managing the one-time opening stock initialization workflow.
class SetOpeningStockCubit extends Cubit<SetOpeningStockState> {
  final InventoryRepository _repository;
  InventoryItemSummary? _loadedItem;

  SetOpeningStockCubit(this._repository)
    : super(const SetOpeningStockInitial());

  /// Loads item and checks movement eligibility fresh from the repository.
  Future<void> load(String itemId) async {
    emit(const SetOpeningStockLoading());

    try {
      final summary = await _repository.getItemById(itemId);
      if (summary == null) {
        emit(SetOpeningStockNotFound(itemId));
        return;
      }

      _loadedItem = summary;
      final hasMovements = await _repository.hasStockMovements(itemId);
      if (hasMovements) {
        emit(
          const SetOpeningStockUnavailable(
            'Opening stock has already been initialized for this item.',
          ),
        );
        return;
      }

      emit(SetOpeningStockReady(summary));
    } catch (_) {
      emit(
        SetOpeningStockFailure(
          message: 'Unable to load inventory item.',
          item: _loadedItem,
        ),
      );
    }
  }

  /// Submits the opening stock mutation with actor derived from authenticated user.
  Future<void> submit({
    required String itemId,
    required double quantity,
    required String performedByUserId,
  }) async {
    // Double-submit prevention
    if (state is SetOpeningStockSubmitting) {
      return;
    }

    final currentItem = _loadedItem;

    if (!quantity.isFinite || quantity <= 0) {
      emit(
        SetOpeningStockFailure(
          message: 'Opening quantity must be greater than zero.',
          item: currentItem,
        ),
      );
      return;
    }

    if (performedByUserId.trim().isEmpty) {
      emit(
        SetOpeningStockFailure(
          message: 'User ID cannot be blank.',
          item: currentItem,
        ),
      );
      return;
    }

    if (currentItem != null) {
      emit(SetOpeningStockSubmitting(currentItem));
    }

    try {
      final result = await _repository.recordOpeningStock(
        RecordOpeningStockInput(
          itemId: itemId,
          quantity: quantity,
          performedByUserId: performedByUserId,
        ),
      );
      emit(SetOpeningStockSuccess(result));
    } on InventoryOpeningStockAlreadyRecordedException {
      emit(
        SetOpeningStockFailure(
          message: 'Opening stock has already been initialized for this item.',
          item: currentItem,
        ),
      );
    } on InventoryValidationException catch (e) {
      emit(SetOpeningStockFailure(message: e.message, item: currentItem));
    } on InventoryItemNotFoundException {
      emit(SetOpeningStockNotFound(itemId));
    } catch (_) {
      emit(
        SetOpeningStockFailure(
          message: 'Unable to set opening stock.',
          item: currentItem,
        ),
      );
    }
  }
}
