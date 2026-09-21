import 'package:flutter/foundation.dart';
import 'inventory_item_summary.dart';

/// Paginated page of inventory item summaries.
@immutable
class InventoryPage {
  final List<InventoryItemSummary> items;
  final int currentPage;
  final int pageSize;
  final int totalItems;
  final bool hasNext;

  const InventoryPage({
    required this.items,
    required this.currentPage,
    required this.pageSize,
    required this.totalItems,
    required this.hasNext,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryPage &&
          runtimeType == other.runtimeType &&
          listEquals(items, other.items) &&
          currentPage == other.currentPage &&
          pageSize == other.pageSize &&
          totalItems == other.totalItems &&
          hasNext == other.hasNext;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    currentPage,
    pageSize,
    totalItems,
    hasNext,
  );

  @override
  String toString() =>
      'InventoryPage(items: ${items.length}, page: $currentPage, pageSize: $pageSize, total: $totalItems, hasNext: $hasNext)';
}
