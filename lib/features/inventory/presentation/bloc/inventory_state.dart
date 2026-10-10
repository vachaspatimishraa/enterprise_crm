import 'package:flutter/foundation.dart';
import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/entities/inventory_page.dart';
import '../../domain/entities/inventory_query.dart';

/// States emitted by [InventoryCubit].
@immutable
sealed class InventoryState {
  final InventoryQuery query;

  const InventoryState({this.query = const InventoryQuery()});
}

/// Initial state before inventory has been requested.
final class InventoryInitial extends InventoryState {
  const InventoryInitial({super.query});
}

/// State emitted while inventory items are being loaded from the repository.
final class InventoryLoading extends InventoryState {
  const InventoryLoading({super.query});
}

/// State emitted when inventory items have been loaded successfully with at least 1 item.
final class InventoryLoaded extends InventoryState {
  final InventoryPage page;
  final List<InventoryItemSummary> items;

  const InventoryLoaded({
    required this.page,
    required this.items,
    required super.query,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryLoaded &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          listEquals(items, other.items) &&
          query == other.query;

  @override
  int get hashCode => Object.hash(page, Object.hashAll(items), query);
}

/// State emitted when a query returns zero items.
///
/// Distinguishes between repository-wide empty inventory and search producing no matches
/// via [isSearchResult].
final class InventoryEmpty extends InventoryState {
  const InventoryEmpty({required super.query});

  bool get isSearchResult =>
      query.searchText != null && query.searchText!.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryEmpty &&
          runtimeType == other.runtimeType &&
          query == other.query;

  @override
  int get hashCode => query.hashCode;
}

/// State emitted when loading inventory items fails.
final class InventoryFailure extends InventoryState {
  final String message;

  const InventoryFailure({required this.message, required super.query});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          query == other.query;

  @override
  int get hashCode => Object.hash(message, query);
}
