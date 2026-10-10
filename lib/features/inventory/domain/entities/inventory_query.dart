import 'package:flutter/foundation.dart';
import 'inventory_sort.dart';

/// Query specification for filtering, sorting, and paginating inventory items.
@immutable
class InventoryQuery {
  final String? searchText;
  final InventorySort sort;
  final int page;
  final int pageSize;

  const InventoryQuery({
    this.searchText,
    this.sort = InventorySort.nameAsc,
    this.page = 1,
    this.pageSize = 20,
  });

  static const InventoryQuery empty = InventoryQuery();

  bool get isEmpty =>
      (searchText == null || searchText!.trim().isEmpty) &&
      sort == InventorySort.nameAsc &&
      page == 1;

  InventoryQuery copyWith({
    String? searchText,
    InventorySort? sort,
    int? page,
    int? pageSize,
    bool clearSearch = false,
  }) {
    return InventoryQuery(
      searchText: clearSearch ? null : (searchText ?? this.searchText),
      sort: sort ?? this.sort,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryQuery &&
          runtimeType == other.runtimeType &&
          searchText == other.searchText &&
          sort == other.sort &&
          page == other.page &&
          pageSize == other.pageSize;

  @override
  int get hashCode => Object.hash(searchText, sort, page, pageSize);

  @override
  String toString() =>
      'InventoryQuery(search: $searchText, sort: $sort, page: $page, pageSize: $pageSize)';
}
