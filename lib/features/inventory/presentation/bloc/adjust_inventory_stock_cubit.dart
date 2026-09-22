import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/exceptions/inventory_exception.dart';
import '../../domain/inputs/adjust_inventory_stock_input.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'adjust_inventory_stock_state.dart';

/// Cubit managing the manual stock adjustment workflow.
class AdjustInventoryStockCubit extends Cubit<AdjustInventoryStockState> {
  final InventoryRepository _repository;
  InventoryItemSummary? _loadedItem;

  AdjustInventoryStockCubit(this._repository)
    : super(const AdjustInventoryStockInitial());

  /// Loads item and checks movement initialization status fresh from the repository.
  Future<void> load(String itemId) async {
    emit(const AdjustInventoryStockLoading());

    try {
      final summary = await _repository.getItemById(itemId);
      if (summary == null) {
        emit(AdjustInventoryStockNotFound(itemId));
        return;
      }

      _loadedItem = summary;
      final hasMovements = await _repository.hasStockMovements(itemId);
      if (!hasMovements) {
        emit(
          const AdjustInventoryStockUnavailable(
            'Stock must be initialized before it can be adjusted.',
          ),
        );
        return;
      }

      emit(AdjustInventoryStockReady(summary));
    } catch (_) {
      emit(
        AdjustInventoryStockFailure(
          message: 'Unable to load inventory item.',
          item: _loadedItem,
        ),
      );
    }
  }

  /// Submits the manual adjustment mutation.
  Future<void> submit({
    required String itemId,
    required StockAdjustmentDirection direction,
    required double magnitude,
    required String reason,
    required String performedByUserId,
  }) async {
    // Double-submit prevention
    if (state is AdjustInventoryStockSubmitting) {
      return;
    }

    final currentItem = _loadedItem;

    if (!magnitude.isFinite || magnitude <= 0) {
      emit(
        AdjustInventoryStockFailure(
          message: 'Quantity must be greater than zero.',
          item: currentItem,
        ),
      );
      return;
    }

    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      emit(
        AdjustInventoryStockFailure(
          message: 'Reason is required.',
          item: currentItem,
        ),
      );
      return;
    }

    if (performedByUserId.trim().isEmpty) {
      emit(
        AdjustInventoryStockFailure(
          message: 'User ID cannot be blank.',
          item: currentItem,
        ),
      );
      return;
    }

    final signedDelta = direction == StockAdjustmentDirection.increase
        ? magnitude
        : -magnitude;

    if (currentItem != null) {
      emit(AdjustInventoryStockSubmitting(currentItem));
    }

    try {
      final result = await _repository.adjustStock(
        AdjustInventoryStockInput(
          itemId: itemId,
          quantityDelta: signedDelta,
          reason: trimmedReason,
          performedByUserId: performedByUserId,
        ),
      );
      emit(AdjustInventoryStockSuccess(result));
    } on InventoryNegativeStockException {
      emit(
        AdjustInventoryStockFailure(
          message: 'This adjustment would make stock negative.',
          item: currentItem,
        ),
      );
    } on InventoryUninitializedStockException {
      emit(
        AdjustInventoryStockFailure(
          message: 'Stock must be initialized before it can be adjusted.',
          item: currentItem,
        ),
      );
    } on InventoryValidationException catch (e) {
      emit(AdjustInventoryStockFailure(message: e.message, item: currentItem));
    } on InventoryItemNotFoundException {
      emit(AdjustInventoryStockNotFound(itemId));
    } catch (_) {
      emit(
        AdjustInventoryStockFailure(
          message: 'Unable to adjust stock.',
          item: currentItem,
        ),
      );
    }
  }
}
