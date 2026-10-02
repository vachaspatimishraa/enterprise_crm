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

/// Service responsible for loading and deterministically sorting the complete
/// authorized active inventory dataset for export.
class InventoryExportDataLoader {
  const InventoryExportDataLoader(this._repository);

  final InventoryRepository _repository;

  /// Loads all active inventory item summaries across all repository pages,
  /// validates dataset completeness, and applies global deterministic sorting.
  Future<List<InventoryItemSummary>> loadAllItems({
    int batchSize = 100,
  }) async {
    if (batchSize <= 0) {
      throw const InventoryExportDataLoaderException(
        'Batch size must be greater than zero.',
      );
    }

    final allSummaries = <InventoryItemSummary>[];
    final seenIds = <String>{};
    var currentPage = 1;
    var hasNext = true;
    int? expectedTotalItems;
    const maxPages = 10000;

    try {
      while (hasNext && currentPage <= maxPages) {
        final query = InventoryQuery(
          page: currentPage,
          pageSize: batchSize,
          sort: InventorySort.nameAsc,
        );

        final pageData = await _repository.getItems(query);

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

    allSummaries.sort((a, b) {
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

    return List.unmodifiable(allSummaries);
  }
}
