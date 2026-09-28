import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../domain/exceptions/inventory_exception.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'stock_movement_history_state.dart';

/// Cubit managing the retrieval, authorization, and lifecycle states of stock movement history.
class StockMovementHistoryCubit extends Cubit<StockMovementHistoryState> {
  final InventoryRepository _repository;
  final CurrentUser Function() _currentUserProvider;

  String? _lastItemId;
  int _currentRequestId = 0;

  StockMovementHistoryCubit({
    required InventoryRepository repository,
    required CurrentUser currentUser,
    CurrentUser Function()? currentUserProvider,
  }) : _repository = repository,
       _currentUserProvider = currentUserProvider ?? (() => currentUser),
       super(const StockMovementHistoryInitial());

  /// Returns the last requested item ID, if any.
  String? get lastItemId => _lastItemId;

  /// Loads the stock movement history for [itemId].
  ///
  /// Evaluates inventory viewing authorization, emits loading, and maps
  /// repository outcomes to immutable presentation states.
  Future<void> loadHistory(String itemId) async {
    final requestId = ++_currentRequestId;
    _lastItemId = itemId;

    final trimmedId = itemId.trim();
    if (trimmedId.isEmpty) {
      emit(
        StockMovementHistoryFailure(
          itemId: itemId,
          message: 'Item ID cannot be blank.',
        ),
      );
      return;
    }

    final user = _currentUserProvider();
    if (!_isAuthorized(user)) {
      emit(StockMovementHistoryRestricted(itemId));
      return;
    }

    emit(StockMovementHistoryLoading(itemId));

    try {
      final records = await _repository.getStockMovements(itemId);

      // Protect against out-of-order execution or closed cubit
      if (isClosed || requestId != _currentRequestId) {
        return;
      }

      // Re-verify authorization in case user context changed while waiting
      final latestUser = _currentUserProvider();
      if (!_isAuthorized(latestUser)) {
        emit(StockMovementHistoryRestricted(itemId));
        return;
      }

      if (records.isEmpty) {
        emit(StockMovementHistoryEmpty(itemId));
      } else {
        emit(StockMovementHistoryLoaded(itemId: itemId, records: records));
      }
    } on InventoryItemNotFoundException {
      if (isClosed || requestId != _currentRequestId) return;
      emit(StockMovementHistoryNotFound(itemId));
    } catch (_) {
      if (isClosed || requestId != _currentRequestId) return;
      emit(
        StockMovementHistoryFailure(
          itemId: itemId,
          message: 'Unable to load stock movement history.',
        ),
      );
    }
  }

  /// Retries loading history for the last requested item ID.
  Future<void> retry() async {
    if (_lastItemId != null) {
      await loadHistory(_lastItemId!);
    }
  }

  /// Evaluates whether [user] possesses Inventory viewing privileges.
  bool _isAuthorized(CurrentUser user) {
    if (user.isAdmin) {
      return true;
    }
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView);
  }
}
