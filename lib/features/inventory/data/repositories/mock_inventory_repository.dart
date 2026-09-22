import 'dart:math';

import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/entities/inventory_page.dart';
import '../../domain/entities/inventory_query.dart';
import '../../domain/entities/inventory_sort.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/exceptions/inventory_exception.dart';
import '../../domain/inputs/create_inventory_item_input.dart';
import '../../domain/inputs/update_inventory_item_input.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../mock/mock_inventory_seed_data.dart';

/// In-memory mock implementation of [InventoryRepository].
///
/// Current stock quantity is dynamically derived from [StockMovement] deltas.
/// Enforces case-insensitive trimmed SKU uniqueness at the repository boundary.
class MockInventoryRepository implements InventoryRepository {
  final List<InventoryItem> _items;
  final List<StockMovement> _movements;

  MockInventoryRepository({
    List<InventoryItem>? items,
    List<StockMovement>? movements,
  }) : _items = List.of(items ?? MockInventorySeedData.createDefaultItems()),
       _movements = List.of(
         movements ?? MockInventorySeedData.createDefaultMovements(),
       ) {
    _validateInvariants();
  }

  void _validateInvariants() {
    final seenSkus = <String>{};
    for (final item in _items) {
      if (item.name.trim().isEmpty) {
        throw ArgumentError('Inventory item name cannot be blank.');
      }
      if (item.sku.trim().isEmpty) {
        throw ArgumentError('Inventory item SKU cannot be blank.');
      }
      final normalizedSku = item.sku.trim().toLowerCase();
      if (!seenSkus.add(normalizedSku)) {
        throw ArgumentError(
          'Duplicate SKU detected: "${item.sku}". SKUs must be unique (case-insensitive).',
        );
      }
    }
  }

  double _deriveQuantityOnHand(String itemId) {
    return _movements
        .where((m) => m.inventoryItemId == itemId)
        .fold(0.0, (sum, m) => sum + m.quantityDelta);
  }

  String _generateNextDeterministicId() {
    final regex = RegExp(r'^item_(\d+)$');
    int maxNumber = 0;
    for (final item in _items) {
      final match = regex.firstMatch(item.id);
      if (match != null) {
        final num = int.tryParse(match.group(1) ?? '') ?? 0;
        if (num > maxNumber) {
          maxNumber = num;
        }
      }
    }

    int candidateNumber = maxNumber + 1;
    while (true) {
      final candidateId = 'item_${candidateNumber.toString().padLeft(3, '0')}';
      if (!_items.any((item) => item.id == candidateId)) {
        return candidateId;
      }
      candidateNumber++;
    }
  }

  @override
  Future<InventoryPage> getItems(InventoryQuery query) async {
    // 1. Search (name + SKU, trimmed, case-insensitive substring)
    Iterable<InventoryItem> filtered = _items;
    if (query.searchText != null && query.searchText!.trim().isNotEmpty) {
      final term = query.searchText!.trim().toLowerCase();
      filtered = filtered.where((item) {
        final nameMatch = item.name.toLowerCase().contains(term);
        final skuMatch = item.sku.toLowerCase().contains(term);
        return nameMatch || skuMatch;
      });
    }

    // 2. Project with derived quantity
    final summaries = filtered
        .map(
          (item) => InventoryItemSummary(
            item: item,
            quantityOnHand: _deriveQuantityOnHand(item.id),
          ),
        )
        .toList();

    // 3. Sort (with deterministic item.id tie-break)
    summaries.sort((a, b) {
      int comparison;
      switch (query.sort) {
        case InventorySort.nameAsc:
          comparison = a.item.name.toLowerCase().compareTo(
            b.item.name.toLowerCase(),
          );
          break;
        case InventorySort.nameDesc:
          comparison = b.item.name.toLowerCase().compareTo(
            a.item.name.toLowerCase(),
          );
          break;
        case InventorySort.skuAsc:
          comparison = a.item.sku.toLowerCase().compareTo(
            b.item.sku.toLowerCase(),
          );
          break;
        case InventorySort.skuDesc:
          comparison = b.item.sku.toLowerCase().compareTo(
            a.item.sku.toLowerCase(),
          );
          break;
      }
      if (comparison != 0) {
        return comparison;
      }
      return a.item.id.compareTo(b.item.id);
    });

    // 4. Pagination
    final totalItems = summaries.length;
    final startIndex = (query.page - 1) * query.pageSize;
    if (startIndex >= totalItems) {
      return InventoryPage(
        items: const <InventoryItemSummary>[],
        currentPage: query.page,
        pageSize: query.pageSize,
        totalItems: totalItems,
        hasNext: false,
      );
    }

    final endIndex = min(startIndex + query.pageSize, totalItems);
    final pageItems = summaries.sublist(startIndex, endIndex);
    final hasNext = endIndex < totalItems;

    return InventoryPage(
      items: List.unmodifiable(pageItems),
      currentPage: query.page,
      pageSize: query.pageSize,
      totalItems: totalItems,
      hasNext: hasNext,
    );
  }

  @override
  Future<InventoryItemSummary?> getItemById(String id) async {
    final matching = _items.where((item) => item.id == id);
    if (matching.isEmpty) {
      return null;
    }
    final item = matching.first;
    return InventoryItemSummary(
      item: item,
      quantityOnHand: _deriveQuantityOnHand(item.id),
    );
  }

  @override
  Future<InventoryItemSummary> createItem(
    CreateInventoryItemInput input,
  ) async {
    final trimmedName = input.name.trim();
    final trimmedSku = input.sku.trim();

    if (trimmedName.isEmpty) {
      throw const InventoryValidationException('Item name cannot be blank.');
    }
    if (trimmedSku.isEmpty) {
      throw const InventoryValidationException('Item SKU cannot be blank.');
    }

    final normalizedCandidateSku = trimmedSku.toLowerCase();
    if (_items.any(
      (item) => item.sku.trim().toLowerCase() == normalizedCandidateSku,
    )) {
      throw InventoryDuplicateSkuException(
        'An item with SKU "$trimmedSku" already exists.',
      );
    }

    final id = _generateNextDeterministicId();
    final newItem = InventoryItem(id: id, name: trimmedName, sku: trimmedSku);

    _items.add(newItem);

    // Invariant: Do NOT create any StockMovement; quantityOnHand is derived as 0.0.
    return InventoryItemSummary(
      item: newItem,
      quantityOnHand: _deriveQuantityOnHand(id),
    );
  }

  @override
  Future<InventoryItemSummary> updateItem(
    UpdateInventoryItemInput input,
  ) async {
    final trimmedName = input.name.trim();
    final trimmedSku = input.sku.trim();

    if (trimmedName.isEmpty) {
      throw const InventoryValidationException('Item name cannot be blank.');
    }
    if (trimmedSku.isEmpty) {
      throw const InventoryValidationException('Item SKU cannot be blank.');
    }

    final existingIndex = _items.indexWhere((item) => item.id == input.id);
    if (existingIndex == -1) {
      throw InventoryItemNotFoundException(
        'Inventory item with ID "${input.id}" not found.',
      );
    }

    final normalizedCandidateSku = trimmedSku.toLowerCase();
    final hasDuplicateOtherSku = _items.any(
      (item) =>
          item.id != input.id &&
          item.sku.trim().toLowerCase() == normalizedCandidateSku,
    );

    if (hasDuplicateOtherSku) {
      throw InventoryDuplicateSkuException(
        'An item with SKU "$trimmedSku" already exists.',
      );
    }

    final updatedItem = InventoryItem(
      id: input.id,
      name: trimmedName,
      sku: trimmedSku,
    );

    _items[existingIndex] = updatedItem;

    // Invariant: _movements is untouched; quantityOnHand is strictly preserved.
    return InventoryItemSummary(
      item: updatedItem,
      quantityOnHand: _deriveQuantityOnHand(input.id),
    );
  }
}
