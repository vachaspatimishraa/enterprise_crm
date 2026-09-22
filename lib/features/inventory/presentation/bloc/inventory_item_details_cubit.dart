import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/inventory_repository.dart';
import 'inventory_item_details_state.dart';

/// Cubit managing loading of a single inventory item details view.
class InventoryItemDetailsCubit extends Cubit<InventoryItemDetailsState> {
  final InventoryRepository _repository;
  String? _lastId;

  InventoryItemDetailsCubit(this._repository)
    : super(const InventoryItemDetailsInitial());

  /// Loads item details and stock movement initialization status by [id].
  Future<void> load(String id) async {
    _lastId = id;
    emit(const InventoryItemDetailsLoading());

    try {
      final summary = await _repository.getItemById(id);
      if (summary == null) {
        emit(InventoryItemDetailsNotFound(id));
      } else {
        final hasMovements = await _repository.hasStockMovements(id);
        emit(
          InventoryItemDetailsLoaded(summary, hasStockMovements: hasMovements),
        );
      }
    } catch (_) {
      emit(
        InventoryItemDetailsFailure(
          message: 'Unable to load inventory item.',
          id: id,
        ),
      );
    }
  }

  /// Retries loading the last requested item.
  Future<void> retry() async {
    if (_lastId != null) {
      await load(_lastId!);
    }
  }
}
