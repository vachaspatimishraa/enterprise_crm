import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/inventory_query.dart';
import '../../domain/entities/inventory_sort.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'inventory_state.dart';

/// Cubit managing inventory list loading, search, sort, and pagination.
class InventoryCubit extends Cubit<InventoryState> {
  final InventoryRepository _repository;

  InventoryCubit(
    this._repository, {
    InventoryQuery initialQuery = const InventoryQuery(),
  }) : super(InventoryInitial(query: initialQuery));

  /// Loads items with the given [query] or the current active query.
  Future<void> loadItems({InventoryQuery? query}) async {
    final effectiveQuery = query ?? state.query;
    emit(InventoryLoading(query: effectiveQuery));

    try {
      final page = await _repository.getItems(effectiveQuery);
      if (page.items.isEmpty) {
        emit(InventoryEmpty(query: effectiveQuery));
      } else {
        emit(
          InventoryLoaded(page: page, items: page.items, query: effectiveQuery),
        );
      }
    } catch (e) {
      emit(
        InventoryFailure(
          message: 'Unable to load inventory.',
          query: effectiveQuery,
        ),
      );
    }
  }

  /// Updates search text and resets to page 1.
  Future<void> search(String text) async {
    final trimmed = text.trim();
    final newQuery = state.query.copyWith(
      searchText: trimmed,
      clearSearch: trimmed.isEmpty,
      page: 1,
    );
    await loadItems(query: newQuery);
  }

  /// Clears active search text and resets to page 1.
  Future<void> clearSearch() async {
    final newQuery = state.query.copyWith(clearSearch: true, page: 1);
    await loadItems(query: newQuery);
  }

  /// Updates sort order and resets to page 1.
  Future<void> setSort(InventorySort sort) async {
    if (state.query.sort == sort) return;
    final newQuery = state.query.copyWith(sort: sort, page: 1);
    await loadItems(query: newQuery);
  }

  /// Navigates to the next page if available.
  Future<void> nextPage() async {
    final currentState = state;
    if (currentState is InventoryLoaded && currentState.page.hasNext) {
      final newQuery = state.query.copyWith(page: state.query.page + 1);
      await loadItems(query: newQuery);
    }
  }

  /// Navigates to the previous page if available.
  Future<void> previousPage() async {
    if (state.query.page > 1) {
      final newQuery = state.query.copyWith(page: state.query.page - 1);
      await loadItems(query: newQuery);
    }
  }

  /// Refreshes the active query results.
  Future<void> refresh() async {
    await loadItems(query: state.query);
  }

  /// Retries the active query after failure.
  Future<void> retry() async {
    await loadItems(query: state.query);
  }
}
