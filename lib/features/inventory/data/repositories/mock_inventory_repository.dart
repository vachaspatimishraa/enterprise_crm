import 'dart:math';

import '../../domain/entities/inventory_import_models.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/entities/inventory_page.dart';
import '../../domain/entities/inventory_query.dart';
import '../../domain/entities/inventory_sort.dart';
import '../../domain/entities/inventory_stock_mutation_result.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/entities/stock_movement_type.dart';
import '../../domain/exceptions/inventory_exception.dart';
import '../../domain/inputs/adjust_inventory_stock_input.dart';
import '../../domain/inputs/create_inventory_item_input.dart';
import '../../domain/inputs/record_opening_stock_input.dart';
import '../../domain/inputs/update_inventory_item_input.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../mock/mock_inventory_seed_data.dart';

/// In-memory mock implementation of [InventoryRepository].
///
/// Current stock quantity is dynamically derived from [StockMovement] deltas.
/// Enforces case-insensitive trimmed SKU uniqueness, atomic non-negative stock validation,
/// and append-only stock movement ledger persistence.
class MockInventoryRepository implements InventoryRepository {
  final List<InventoryItem> _items;
  final List<StockMovement> _movements;
  final DateTime Function() _nowProvider;
  final bool Function(String sku)? _simulateMovementFailure;

  MockInventoryRepository({
    List<InventoryItem>? items,
    List<StockMovement>? movements,
    DateTime Function()? nowProvider,
    bool Function(String sku)? simulateMovementFailure,
  }) : _items = List.of(items ?? MockInventorySeedData.createDefaultItems()),
       _movements = List.of(
         movements ?? MockInventorySeedData.createDefaultMovements(),
       ),
       _nowProvider = nowProvider ?? DateTime.now,
       _simulateMovementFailure = simulateMovementFailure {
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

  String _generateNextDeterministicMovementId() {
    final regex = RegExp(r'^mov_(\d+)$');
    int maxNumber = 0;
    for (final movement in _movements) {
      final match = regex.firstMatch(movement.id);
      if (match != null) {
        final num = int.tryParse(match.group(1) ?? '') ?? 0;
        if (num > maxNumber) {
          maxNumber = num;
        }
      }
    }

    int candidateNumber = maxNumber + 1;
    while (true) {
      final candidateId = 'mov_${candidateNumber.toString().padLeft(3, '0')}';
      if (!_movements.any((m) => m.id == candidateId)) {
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

  @override
  Future<bool> hasStockMovements(String itemId) async {
    final itemExists = _items.any((item) => item.id == itemId);
    if (!itemExists) {
      throw InventoryItemNotFoundException(
        'Inventory item with ID "$itemId" not found.',
      );
    }
    return _movements.any((m) => m.inventoryItemId == itemId);
  }

  @override
  Future<InventoryStockMutationResult> recordOpeningStock(
    RecordOpeningStockInput input,
  ) async {
    final matchingItem = _items.where((i) => i.id == input.itemId).firstOrNull;
    if (matchingItem == null) {
      throw InventoryItemNotFoundException(
        'Inventory item with ID "${input.itemId}" not found.',
      );
    }

    final trimmedActor = input.performedByUserId.trim();
    if (trimmedActor.isEmpty) {
      throw const InventoryValidationException('User ID cannot be blank.');
    }

    if (!input.quantity.isFinite || input.quantity <= 0) {
      throw const InventoryValidationException(
        'Opening quantity must be a finite number greater than zero.',
      );
    }

    final hasExistingMovements = _movements.any(
      (m) => m.inventoryItemId == input.itemId,
    );
    if (hasExistingMovements) {
      throw const InventoryOpeningStockAlreadyRecordedException(
        'Opening stock has already been recorded for this item.',
      );
    }

    final id = _generateNextDeterministicMovementId();
    final movement = StockMovement(
      id: id,
      inventoryItemId: input.itemId,
      type: StockMovementType.openingStock,
      quantityDelta: input.quantity,
      createdAt: _nowProvider(),
      performedByUserId: trimmedActor,
      reason: null,
    );

    _movements.add(movement);

    return InventoryStockMutationResult(
      movement: movement,
      item: InventoryItemSummary(
        item: matchingItem,
        quantityOnHand: _deriveQuantityOnHand(input.itemId),
      ),
    );
  }

  @override
  Future<InventoryStockMutationResult> adjustStock(
    AdjustInventoryStockInput input,
  ) async {
    final matchingItem = _items.where((i) => i.id == input.itemId).firstOrNull;
    if (matchingItem == null) {
      throw InventoryItemNotFoundException(
        'Inventory item with ID "${input.itemId}" not found.',
      );
    }

    final trimmedActor = input.performedByUserId.trim();
    if (trimmedActor.isEmpty) {
      throw const InventoryValidationException('User ID cannot be blank.');
    }

    if (!input.quantityDelta.isFinite || input.quantityDelta == 0) {
      throw const InventoryValidationException(
        'Adjustment quantity must be a non-zero finite number.',
      );
    }

    final trimmedReason = input.reason.trim();
    if (trimmedReason.isEmpty) {
      throw const InventoryValidationException(
        'Adjustment reason cannot be blank.',
      );
    }

    final hasExistingMovements = _movements.any(
      (m) => m.inventoryItemId == input.itemId,
    );
    if (!hasExistingMovements) {
      throw const InventoryUninitializedStockException(
        'Stock must be initialized before manual adjustments can be applied.',
      );
    }

    // Atomic stock check: calculate from current movements at write time
    final currentQty = _deriveQuantityOnHand(input.itemId);
    final candidateQty = currentQty + input.quantityDelta;
    if (candidateQty < 0) {
      throw InventoryNegativeStockException(
        'Adjustment of ${input.quantityDelta} would result in negative stock ($currentQty -> $candidateQty).',
      );
    }

    final id = _generateNextDeterministicMovementId();
    final movement = StockMovement(
      id: id,
      inventoryItemId: input.itemId,
      type: StockMovementType.adjustment,
      quantityDelta: input.quantityDelta,
      createdAt: _nowProvider(),
      performedByUserId: trimmedActor,
      reason: trimmedReason,
    );

    _movements.add(movement);

    return InventoryStockMutationResult(
      movement: movement,
      item: InventoryItemSummary(
        item: matchingItem,
        quantityOnHand: _deriveQuantityOnHand(input.itemId),
      ),
    );
  }

  @override
  Future<Set<String>> getExistingSkus() async {
    return _items.map((item) => item.sku.trim().toLowerCase()).toSet();
  }

  @override
  Future<InventoryImportResult> importItems(
    InventoryImportRequest request,
  ) async {
    final trimmedActor = request.performedByUserId.trim();
    if (trimmedActor.isEmpty) {
      throw const InventoryValidationException('User ID cannot be blank.');
    }

    if (request.rows.isEmpty) {
      return const InventoryImportResult(
        requestedCount: 0,
        successCount: 0,
        failureCount: 0,
        importedSummaries: [],
        failures: [],
      );
    }

    // Intra-request duplicate detection: all occurrences of duplicated SKUs within request fail.
    final seenRequestSkus = <String>{};
    final duplicateRequestSkus = <String>{};
    for (final row in request.rows) {
      final norm = row.sku.trim().toLowerCase();
      if (norm.isNotEmpty) {
        if (!seenRequestSkus.add(norm)) {
          duplicateRequestSkus.add(norm);
        }
      }
    }

    final importedSummaries = <InventoryItemSummary>[];
    final failures = <InventoryImportRowFailure>[];

    for (final row in request.rows) {
      final trimmedName = row.name.trim();
      final trimmedSku = row.sku.trim();
      final normSku = trimmedSku.toLowerCase();

      // 1. Validation
      if (trimmedName.isEmpty) {
        failures.add(
          InventoryImportRowFailure(
            sourceRowNumber: row.sourceRowNumber,
            sku: row.sku,
            reason: 'Name is required.',
          ),
        );
        continue;
      }

      if (trimmedSku.isEmpty) {
        failures.add(
          InventoryImportRowFailure(
            sourceRowNumber: row.sourceRowNumber,
            sku: row.sku,
            reason: 'SKU is required.',
          ),
        );
        continue;
      }

      if (duplicateRequestSkus.contains(normSku)) {
        failures.add(
          InventoryImportRowFailure(
            sourceRowNumber: row.sourceRowNumber,
            sku: row.sku,
            reason: 'Duplicate SKU in import file.',
          ),
        );
        continue;
      }

      // Revalidate freshness against existing repository state
      final alreadyExists = _items.any(
        (item) => item.sku.trim().toLowerCase() == normSku,
      );
      if (alreadyExists) {
        failures.add(
          InventoryImportRowFailure(
            sourceRowNumber: row.sourceRowNumber,
            sku: row.sku,
            reason: 'An inventory item with this SKU already exists.',
          ),
        );
        continue;
      }

      // Opening stock validation
      if (row.openingStock != null) {
        if (!row.openingStock!.isFinite || row.openingStock! <= 0) {
          failures.add(
            InventoryImportRowFailure(
              sourceRowNumber: row.sourceRowNumber,
              sku: row.sku,
              reason: 'Opening stock must be greater than zero.',
            ),
          );
          continue;
        }
      }

      // 2. Atomic row staging & execution
      try {
        final itemId = _generateNextDeterministicId();
        final newItem = InventoryItem(
          id: itemId,
          name: trimmedName,
          sku: trimmedSku,
        );

        StockMovement? candidateMovement;
        if (row.openingStock != null) {
          if (_simulateMovementFailure != null &&
              _simulateMovementFailure(trimmedSku)) {
            throw const InventoryValidationException(
              'Simulated movement persistence failure.',
            );
          }

          final movId = _generateNextDeterministicMovementId();
          candidateMovement = StockMovement(
            id: movId,
            inventoryItemId: itemId,
            type: StockMovementType.openingStock,
            quantityDelta: row.openingStock!,
            createdAt: _nowProvider(),
            performedByUserId: trimmedActor,
            reason: null,
          );
        }

        // Commit atomically: both succeed or neither is added to state
        _items.add(newItem);
        if (candidateMovement != null) {
          _movements.add(candidateMovement);
        }

        importedSummaries.add(
          InventoryItemSummary(
            item: newItem,
            quantityOnHand: _deriveQuantityOnHand(itemId),
          ),
        );
      } catch (e) {
        failures.add(
          InventoryImportRowFailure(
            sourceRowNumber: row.sourceRowNumber,
            sku: row.sku,
            reason: 'Failed to import row: $e',
          ),
        );
      }
    }

    return InventoryImportResult(
      requestedCount: request.rows.length,
      successCount: importedSummaries.length,
      failureCount: failures.length,
      importedSummaries: List.unmodifiable(importedSummaries),
      failures: List.unmodifiable(failures),
    );
  }
}
