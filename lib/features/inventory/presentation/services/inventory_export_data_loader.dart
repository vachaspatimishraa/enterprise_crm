import '../../domain/entities/inventory_export_artifact.dart';
import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/entities/inventory_query.dart';
import '../../domain/entities/inventory_sort.dart';
import '../../domain/repositories/inventory_repository.dart';

/// Exception thrown when dataset loading for Inventory Export fails.
class InventoryExportDataLoaderException implements Exception {
  const InventoryExportDataLoaderException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Service responsible for loading and deterministically sorting authorized
/// inventory datasets for export across all, filtered, or selected record scopes.
class InventoryExportDataLoader {
  const InventoryExportDataLoader(this._repository);

  final InventoryRepository _repository;

  /// Loads all active inventory item summaries across all repository pages,
  /// validates dataset completeness, and applies global deterministic sorting.
  Future<List<InventoryItemSummary>> loadAllItems({
    int batchSize = 100,
  }) {
    return loadItems(
      scope: InventoryExportScope.all,
      batchSize: batchSize,
    );
  }

  /// Loads inventory items matching [scope] across pages.
  ///
  /// - [InventoryExportScope.all]: paginates all authorized items without filtering.
  /// - [InventoryExportScope.filtered]: paginates all authorized items matching [query].
  /// - [InventoryExportScope.selected]: resolves [selectedItemIds] through repository,
  ///   omitting inaccessible or pending-deleted items, and throws if [selectedItemIds] is empty.
  Future<List<InventoryItemSummary>> loadItems({
    InventoryExportScope scope = InventoryExportScope.all,
    InventoryQuery? query,
    Set<String>? selectedItemIds,
    int batchSize = 100,
  }) async {
    if (batchSize <= 0) {
      throw const InventoryExportDataLoaderException(
        'Batch size must be greater than zero.',
      );
    }

    if (scope == InventoryExportScope.selected) {
      if (selectedItemIds == null || selectedItemIds.isEmpty) {
        throw const InventoryExportDataLoaderException(
          'No items selected for export.',
        );
      }

      try {
        final pending = await _repository.getPendingDeletions();
        final pendingIds = pending.map((p) => p.itemId).toSet();

        final items = <InventoryItemSummary>[];
        for (final id in selectedItemIds) {
          if (pendingIds.contains(id)) continue;
          final summary = await _repository.getItemById(id);
          if (summary != null) {
            items.add(summary);
          }
        }

        _sortDeterministically(items);
        return List.unmodifiable(items);
      } catch (e) {
        if (e is InventoryExportDataLoaderException) rethrow;
        throw InventoryExportDataLoaderException(
          'Failed to load selected inventory items for export: $e',
        );
      }
    }

    final allSummaries = <InventoryItemSummary>[];
    final seenIds = <String>{};
    var currentPage = 1;
    var hasNext = true;
    int? expectedTotalItems;
    const maxPages = 10000;

    final effectiveQuery = query ?? const InventoryQuery();

    try {
      while (hasNext && currentPage <= maxPages) {
        final pageQuery = effectiveQuery.copyWith(
          page: currentPage,
          pageSize: batchSize,
          sort: InventorySort.nameAsc,
        );

        final pageData = await _repository.getItems(pageQuery);

        // Validate page contract metadata
        if (pageData.currentPage != currentPage) {
          throw InventoryExportDataLoaderException(
            'Inconsistent pagination state: Expected page $currentPage but received ${pageData.currentPage}.',
          );
        }

        // Validate totalItems consistency across pages
        if (expectedTotalItems == null) {
          expectedTotalItems = pageData.totalItems;
          if (expectedTotalItems < 0) {
            throw InventoryExportDataLoaderException(
              'Inconsistent pagination state: Negative totalItems ($expectedTotalItems).',
            );
          }
        } else if (pageData.totalItems != expectedTotalItems) {
          throw InventoryExportDataLoaderException(
            'Inconsistent pagination state: totalItems changed from $expectedTotalItems to ${pageData.totalItems} during pagination.',
          );
        }

        // Check for empty page with hasNext == true
        if (pageData.items.isEmpty && pageData.hasNext) {
          throw const InventoryExportDataLoaderException(
            'Inconsistent pagination state: Page returned empty list while claiming next page exists.',
          );
        }

        // Check for pageSize boundary violation (more items than requested)
        if (pageData.items.length > batchSize) {
          throw InventoryExportDataLoaderException(
            'Inconsistent pagination state: Page returned ${pageData.items.length} items exceeding requested batchSize $batchSize.',
          );
        }

        for (final summary in pageData.items) {
          if (seenIds.contains(summary.item.id)) {
            throw InventoryExportDataLoaderException(
              'Duplicate inventory item encountered during export: "${summary.item.name}" (ID: ${summary.item.id}, SKU: ${summary.item.sku}).',
            );
          }
          seenIds.add(summary.item.id);
          allSummaries.add(summary);
        }

        hasNext = pageData.hasNext;
        currentPage++;
      }

      if (currentPage > maxPages && hasNext) {
        throw const InventoryExportDataLoaderException(
          'Pagination safety limit exceeded: Too many pages encountered during export.',
        );
      }

      // Verify completeness against reported totalItems
      if (expectedTotalItems != null && allSummaries.length != expectedTotalItems) {
        throw InventoryExportDataLoaderException(
          'Inconsistent dataset completeness: Retrieved ${allSummaries.length} items but repository reported totalItems = $expectedTotalItems.',
        );
      }
    } on InventoryExportDataLoaderException {
      rethrow;
    } catch (e) {
      throw InventoryExportDataLoaderException(
        'Failed to load inventory export dataset: $e',
      );
    }

    _sortDeterministically(allSummaries);
    return List.unmodifiable(allSummaries);
  }

  void _sortDeterministically(List<InventoryItemSummary> items) {
    items.sort((a, b) {
      final nameCompare = a.item.name.toLowerCase().compareTo(
            b.item.name.toLowerCase(),
          );
      if (nameCompare != 0) return nameCompare;

      final skuCompare = a.item.sku.toLowerCase().compareTo(
            b.item.sku.toLowerCase(),
          );
      if (skuCompare != 0) return skuCompare;

      return a.item.id.compareTo(b.item.id);
    });
  }
}
