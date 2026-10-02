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
    const maxPages = 10000;

    try {
      while (hasNext && currentPage <= maxPages) {
        final query = InventoryQuery(
          page: currentPage,
          pageSize: batchSize,
          sort: InventorySort.nameAsc,
        );

        final pageData = await _repository.getItems(query);

        if (pageData.items.isEmpty && pageData.hasNext) {
          throw const InventoryExportDataLoaderException(
            'Inconsistent pagination state: Page returned empty list while claiming next page exists.',
          );
        }

        for (final summary in pageData.items) {
          if (!seenIds.contains(summary.item.id)) {
            seenIds.add(summary.item.id);
            allSummaries.add(summary);
          }
        }

        hasNext = pageData.hasNext;
        currentPage++;
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
