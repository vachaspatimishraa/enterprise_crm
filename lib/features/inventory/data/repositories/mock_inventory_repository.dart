import 'dart:math';

import '../../domain/entities/inventory_import_models.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/inventory_item_summary.dart';
import '../../domain/entities/inventory_page.dart';
import '../../domain/entities/inventory_query.dart';
import '../../domain/entities/inventory_sort.dart';
import '../../domain/entities/inventory_stock_mutation_result.dart';
import '../../domain/entities/pending_inventory_deletion.dart';
import '../../domain/entities/stock_movement_record.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/entities/stock_movement_type.dart';
import '../../domain/exceptions/inventory_exception.dart';
import '../../domain/inputs/adjust_inventory_stock_input.dart';
import '../../domain/inputs/adjust_inventory_stock_to_target_input.dart';
import '../../domain/inputs/create_inventory_item_input.dart';
import '../../domain/inputs/record_opening_stock_input.dart';
import '../../domain/inputs/update_inventory_item_input.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../mock/mock_inventory_seed_data.dart';

/// In-memory mock implementation of [InventoryRepository].
///
/// Current stock quantity is dynamically derived from [StockMovement] deltas.
/// Enforces case-insensitive trimmed SKU uniqueness, atomic non-negative stock validation,
/// append-only stock movement ledger persistence, and 60-second safe permanent deletion.
class MockInventoryRepository implements InventoryRepository {
  final List<InventoryItem> _items;
  final List<StockMovement> _movements;
  final DateTime Function() _nowProvider;
  final bool Function(String sku)? _simulateMovementFailure;
  final bool Function(String itemId)? _hasExternalReference;
  final bool Function(String userId)? _canManageStock;
  final Map<String, PendingInventoryDeletion> _pendingDeletions = {};
  final Set<String> _retiredItemIds = {};

  MockInventoryRepository({
    List<InventoryItem>? items,
    List<StockMovement>? movements,
    DateTime Function()? nowProvider,
    bool Function(String sku)? simulateMovementFailure,
    bool Function(String itemId)? hasExternalReference,
    bool Function(String userId)? canManageStock,
  }) : _items = List.of(items ?? MockInventorySeedData.createDefaultItems()),
       _movements = List.of(
         movements ?? MockInventorySeedData.createDefaultMovements(),
       ),
       _nowProvider = nowProvider ?? DateTime.now,
       _simulateMovementFailure = simulateMovementFailure,
       _hasExternalReference = hasExternalReference,
       _canManageStock = canManageStock {
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
      if (!_items.any((item) => item.id == candidateId) &&
          !_retiredItemIds.contains(candidateId)) {
        return candidateId;
      }
      candidateNumber++;
    }
  }

  bool _isPendingDeletion(String itemId) {
    final pending = _pendingDeletions[itemId];
    return pending != null && pending.isPendingAt(_nowProvider());
  }

  void _purgeExpiredDeletionsInternal() {
    final now = _nowProvider();
    final expiredIds = <String>[];
    for (final entry in _pendingDeletions.entries) {
      if (entry.value.isExpiredAt(now)) {
        expiredIds.add(entry.key);
      }
    }
    for (final id in expiredIds) {
      _finalizeSingleItem(id);
    }
  }

  void _finalizeSingleItem(String itemId) {
    if (_hasExternalReference != null && _hasExternalReference(itemId)) {
      return;
    }
    _items.removeWhere((item) => item.id == itemId);
    _movements.removeWhere((movement) => movement.inventoryItemId == itemId);
    _retiredItemIds.add(itemId);
    final pending = _pendingDeletions[itemId];
    if (pending != null) {
      _pendingDeletions[itemId] = pending.copyWith(
        status: PendingDeletionStatus.finalized,
      );
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
    _purgeExpiredDeletionsInternal();
    // 1. Search (name + SKU, trimmed, case-insensitive substring), excluding pending deletions
    Iterable<InventoryItem> filtered = _items.where(
      (item) => !_isPendingDeletion(item.id),
    );
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
    _purgeExpiredDeletionsInternal();
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
    _purgeExpiredDeletionsInternal();
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

    if (input.openingStock != null) {
      final trimmedActor = input.performedByUserId?.trim() ?? '';
      if (_canManageStock != null && !_canManageStock(trimmedActor)) {
        throw const InventoryAuthorizationException(
          'You do not have permission to set opening stock.',
        );
      }
      if (!input.openingStock!.isFinite || input.openingStock! <= 0) {
        throw const InventoryValidationException(
          'Opening stock must be greater than zero.',
        );
      }
      if (trimmedActor.isEmpty) {
        throw const InventoryValidationException('User ID cannot be blank.');
      }

      if (_simulateMovementFailure != null &&
          _simulateMovementFailure(trimmedSku)) {
        throw Exception('Simulated movement creation failure');
      }

      final movementId = _generateNextDeterministicMovementId();
      final movement = StockMovement(
        id: movementId,
        inventoryItemId: id,
        type: StockMovementType.openingStock,
        quantityDelta: input.openingStock!,
        createdAt: _nowProvider(),
        performedByUserId: trimmedActor,
        reason: null,
      );

      _items.add(newItem);
      _movements.add(movement);
    } else {
      _items.add(newItem);
    }

    return InventoryItemSummary(
      item: newItem,
      quantityOnHand: _deriveQuantityOnHand(id),
    );
  }

  @override
  Future<InventoryItemSummary> updateItem(
    UpdateInventoryItemInput input,
  ) async {
    _purgeExpiredDeletionsInternal();
    if (_isPendingDeletion(input.id)) {
      throw const InventoryDeletionConflictException(
        'Cannot edit an item that is pending deletion.',
      );
    }
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
    _purgeExpiredDeletionsInternal();
    if (_isPendingDeletion(input.itemId)) {
      throw const InventoryDeletionConflictException(
        'Cannot record opening stock for an item that is pending deletion.',
      );
    }
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

    if (_canManageStock != null && !_canManageStock(trimmedActor)) {
      throw const InventoryAuthorizationException(
        'User does not have permission to set opening stock.',
      );
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
    _purgeExpiredDeletionsInternal();
    if (_isPendingDeletion(input.itemId)) {
      throw const InventoryDeletionConflictException(
        'Cannot adjust stock for an item that is pending deletion.',
      );
    }
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

    if (_canManageStock != null && !_canManageStock(trimmedActor)) {
      throw const InventoryAuthorizationException(
        'User does not have permission to adjust stock.',
      );
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
  Future<InventoryStockMutationResult> adjustStockToTarget(
    AdjustInventoryStockToTargetInput input,
  ) async {
    _purgeExpiredDeletionsInternal();
    if (_isPendingDeletion(input.itemId)) {
      throw const InventoryDeletionConflictException(
        'Cannot adjust stock for an item that is pending deletion.',
      );
    }
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

    if (_canManageStock != null && !_canManageStock(trimmedActor)) {
      throw const InventoryAuthorizationException(
        'User does not have permission to adjust stock.',
      );
    }

    if (!input.targetQuantity.isFinite || input.targetQuantity < 0) {
      throw const InventoryValidationException(
        'Target quantity must be a finite number greater than or equal to zero.',
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

    // Atomic write-time calculation against current authoritative movement balance
    final latestBalance = _deriveQuantityOnHand(input.itemId);
    final delta = input.targetQuantity - latestBalance;

    if (delta == 0.0) {
      throw const InventoryStockUnchangedException(
        'The stock quantity is already at this value.',
      );
    }

    if (latestBalance + delta < 0) {
      throw InventoryNegativeStockException(
        'Adjustment would result in negative stock ($latestBalance -> ${latestBalance + delta}).',
      );
    }

    final id = _generateNextDeterministicMovementId();
    final movement = StockMovement(
      id: id,
      inventoryItemId: input.itemId,
      type: StockMovementType.adjustment,
      quantityDelta: delta,
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

  @override
  Future<PendingInventoryDeletion> requestItemDeletion({
    required String itemId,
    required String performedByUserId,
  }) async {
    _purgeExpiredDeletionsInternal();
    final matching = _items.where((item) => item.id == itemId);
    if (matching.isEmpty) {
      throw const InventoryItemNotFoundException('Inventory item not found.');
    }
    final item = matching.first;
    if (_isPendingDeletion(itemId)) {
      throw const InventoryDeletionConflictException(
        'Item is already pending deletion.',
      );
    }
    if (_hasExternalReference != null && _hasExternalReference(itemId)) {
      throw const InventoryDeletionBlockedException(
        'Item deletion is blocked because it is referenced by external records.',
      );
    }
    final requestedAt = _nowProvider();
    final undoDeadline = requestedAt.add(const Duration(seconds: 60));
    final pending = PendingInventoryDeletion(
      itemId: itemId,
      itemName: item.name,
      itemSku: item.sku,
      initiatedByUserId: performedByUserId,
      requestedAt: requestedAt,
      undoDeadline: undoDeadline,
      status: PendingDeletionStatus.pending,
    );
    _pendingDeletions[itemId] = pending;
    return pending;
  }

  @override
  Future<void> undoItemDeletion({
    required String itemId,
    required String performedByUserId,
  }) async {
    final pending = _pendingDeletions[itemId];
    if (pending == null || pending.status != PendingDeletionStatus.pending) {
      throw const InventoryItemNotFoundException(
        'No active pending deletion found for this item.',
      );
    }
    if (!_nowProvider().isBefore(pending.undoDeadline)) {
      _finalizeSingleItem(itemId);
      throw const InventoryDeletionConflictException(
        'The undo deadline for this deletion has expired.',
      );
    }
    _pendingDeletions.remove(itemId);
  }

  @override
  Future<void> finalizeExpiredDeletions() async {
    _purgeExpiredDeletionsInternal();
  }

  @override
  Future<List<PendingInventoryDeletion>> getPendingDeletions() async {
    _purgeExpiredDeletionsInternal();
    final now = _nowProvider();
    return _pendingDeletions.values.where((p) => p.isPendingAt(now)).toList();
  }

  @override
  Future<List<StockMovementRecord>> getStockMovements(String itemId) async {
    _purgeExpiredDeletionsInternal();

    final itemExists = _items.any((item) => item.id == itemId);
    if (!itemExists) {
      throw InventoryItemNotFoundException(
        'Inventory item with ID "$itemId" not found.',
      );
    }

    // 1. Extract item movements paired with their original ledger index for
    // deterministic secondary sequencing if timestamps are identical.
    final itemIndexedMovements = <({StockMovement movement, int index})>[];
    for (var i = 0; i < _movements.length; i++) {
      final m = _movements[i];
      if (m.inventoryItemId == itemId) {
        itemIndexedMovements.add((movement: m, index: i));
      }
    }

    if (itemIndexedMovements.isEmpty) {
      return const <StockMovementRecord>[];
    }

    // 2. Authoritative chronological ordering:
    // Primary: createdAt ascending (earliest to latest)
    // Secondary: original ledger insertion index ascending
    itemIndexedMovements.sort((a, b) {
      final timeCompare = a.movement.createdAt.compareTo(b.movement.createdAt);
      if (timeCompare != 0) return timeCompare;
      return a.index.compareTo(b.index);
    });

    // 3. Calculate running balance chronologically forward from genesis (0.0)
    var runningBalance = 0.0;
    final chronologicalRecords = <StockMovementRecord>[];
    for (final entry in itemIndexedMovements) {
      runningBalance += entry.movement.quantityDelta;
      chronologicalRecords.add(
        StockMovementRecord(
          movement: entry.movement,
          runningBalance: runningBalance,
        ),
      );
    }

    // 4. Return newest first (reversed) as an unmodifiable list
    return List.unmodifiable(chronologicalRecords.reversed);
  }
}
