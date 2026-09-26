import 'dart:async';

import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_page.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_stock_mutation_result.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:enterprise_crm/features/inventory/domain/exceptions/inventory_exception.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/record_opening_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/update_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/adjust_inventory_stock_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/adjust_inventory_stock_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';

class _CustomInventoryRepository implements InventoryRepository {
  final Future<InventoryItemSummary?> Function(String)? onGetItemById;
  final Future<bool> Function(String)? onHasStockMovements;
  final Future<InventoryStockMutationResult> Function(
    AdjustInventoryStockInput,
  )?
  onAdjustStock;

  int adjustStockCalls = 0;

  _CustomInventoryRepository({
    this.onGetItemById,
    this.onHasStockMovements,
    this.onAdjustStock,
  });

  @override
  Future<InventoryPage> getItems(InventoryQuery query) =>
      throw UnimplementedError();

  @override
  Future<InventoryItemSummary?> getItemById(String id) {
    if (onGetItemById != null) return onGetItemById!(id);
    return Future.value(null);
  }

  @override
  Future<InventoryItemSummary> createItem(CreateInventoryItemInput input) =>
      throw UnimplementedError();

  @override
  Future<InventoryItemSummary> updateItem(UpdateInventoryItemInput input) =>
      throw UnimplementedError();

  @override
  Future<bool> hasStockMovements(String itemId) {
    if (onHasStockMovements != null) return onHasStockMovements!(itemId);
    return Future.value(false);
  }

  @override
  Future<InventoryStockMutationResult> recordOpeningStock(
    RecordOpeningStockInput input,
  ) => throw UnimplementedError();

  @override
  Future<InventoryStockMutationResult> adjustStock(
    AdjustInventoryStockInput input,
  ) {
    adjustStockCalls++;
    if (onAdjustStock != null) return onAdjustStock!(input);
    throw Exception('Default adjust failure');
  }

  @override
  Future<Set<String>> getExistingSkus() => Future.value({});

  @override
  Future<InventoryImportResult> importItems(InventoryImportRequest request) =>
      throw UnimplementedError();
}

void main() {
  group('AdjustInventoryStockCubit', () {
    final sampleItem = InventoryItem(
      id: 'item_001',
      name: 'Initialized Item',
      sku: 'SKU-001',
    );
    final sampleSummary = InventoryItemSummary(
      item: sampleItem,
      quantityOnHand: 50.0,
    );

    test('initial state is AdjustInventoryStockInitial', () {
      final cubit = AdjustInventoryStockCubit(MockInventoryRepository());
      expect(cubit.state, isA<AdjustInventoryStockInitial>());
    });

    test(
      'load transitions to AdjustInventoryStockReady for initialized item',
      () async {
        final customRepo = _CustomInventoryRepository(
          onGetItemById: (id) async => sampleSummary,
          onHasStockMovements: (id) async => true,
        );
        final cubit = AdjustInventoryStockCubit(customRepo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdjustInventoryStockLoading>(),
            isA<AdjustInventoryStockReady>().having(
              (s) => s.item.item.id,
              'item.item.id',
              'item_001',
            ),
          ]),
        );

        await cubit.load('item_001');
      },
    );

    test(
      'load transitions to AdjustInventoryStockUnavailable when no movements exist',
      () async {
        final customRepo = _CustomInventoryRepository(
          onGetItemById: (id) async => sampleSummary,
          onHasStockMovements: (id) async => false,
        );
        final cubit = AdjustInventoryStockCubit(customRepo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdjustInventoryStockLoading>(),
            isA<AdjustInventoryStockUnavailable>().having(
              (s) => s.message,
              'message',
              contains('Stock must be initialized'),
            ),
          ]),
        );

        await cubit.load('item_001');
      },
    );

    test(
      'load transitions to AdjustInventoryStockNotFound when item is missing',
      () async {
        final customRepo = _CustomInventoryRepository(
          onGetItemById: (id) async => null,
        );
        final cubit = AdjustInventoryStockCubit(customRepo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdjustInventoryStockLoading>(),
            isA<AdjustInventoryStockNotFound>().having(
              (s) => s.itemId,
              'itemId',
              'item_missing',
            ),
          ]),
        );

        await cubit.load('item_missing');
      },
    );

    test(
      'load transitions to AdjustInventoryStockFailure when repository throws',
      () async {
        final customRepo = _CustomInventoryRepository(
          onGetItemById: (id) => throw Exception('Fetch error'),
        );
        final cubit = AdjustInventoryStockCubit(customRepo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdjustInventoryStockLoading>(),
            isA<AdjustInventoryStockFailure>().having(
              (s) => s.message,
              'message',
              contains('Unable to load'),
            ),
          ]),
        );

        await cubit.load('item_error');
      },
    );

    test('submit rejects zero magnitude without calling repository', () async {
      final customRepo = _CustomInventoryRepository();
      final cubit = AdjustInventoryStockCubit(customRepo);

      await cubit.submit(
        itemId: 'item_001',
        direction: StockAdjustmentDirection.increase,
        magnitude: 0.0,
        reason: 'Restock',
        performedByUserId: 'user_admin',
      );

      expect(customRepo.adjustStockCalls, 0);
      expect(
        cubit.state,
        isA<AdjustInventoryStockFailure>().having(
          (s) => s.message,
          'message',
          contains('must be greater than zero'),
        ),
      );
    });

    test(
      'submit rejects negative magnitude without calling repository',
      () async {
        final customRepo = _CustomInventoryRepository();
        final cubit = AdjustInventoryStockCubit(customRepo);

        await cubit.submit(
          itemId: 'item_001',
          direction: StockAdjustmentDirection.increase,
          magnitude: -10.0,
          reason: 'Restock',
          performedByUserId: 'user_admin',
        );

        expect(customRepo.adjustStockCalls, 0);
        expect(
          cubit.state,
          isA<AdjustInventoryStockFailure>().having(
            (s) => s.message,
            'message',
            contains('must be greater than zero'),
          ),
        );
      },
    );

    test('submit rejects NaN and Infinity magnitude', () async {
      final customRepo = _CustomInventoryRepository();
      final cubit = AdjustInventoryStockCubit(customRepo);

      await cubit.submit(
        itemId: 'item_001',
        direction: StockAdjustmentDirection.increase,
        magnitude: double.nan,
        reason: 'Restock',
        performedByUserId: 'user_admin',
      );
      expect(customRepo.adjustStockCalls, 0);
      expect(cubit.state, isA<AdjustInventoryStockFailure>());

      await cubit.submit(
        itemId: 'item_001',
        direction: StockAdjustmentDirection.increase,
        magnitude: double.infinity,
        reason: 'Restock',
        performedByUserId: 'user_admin',
      );
      expect(customRepo.adjustStockCalls, 0);
      expect(cubit.state, isA<AdjustInventoryStockFailure>());
    });

    test('submit rejects blank or whitespace-only reason', () async {
      final customRepo = _CustomInventoryRepository();
      final cubit = AdjustInventoryStockCubit(customRepo);

      await cubit.submit(
        itemId: 'item_001',
        direction: StockAdjustmentDirection.increase,
        magnitude: 5.0,
        reason: '    ',
        performedByUserId: 'user_admin',
      );

      expect(customRepo.adjustStockCalls, 0);
      expect(
        cubit.state,
        isA<AdjustInventoryStockFailure>().having(
          (s) => s.message,
          'message',
          contains('Reason is required'),
        ),
      );
    });

    test('submit rejects blank actor user ID', () async {
      final customRepo = _CustomInventoryRepository();
      final cubit = AdjustInventoryStockCubit(customRepo);

      await cubit.submit(
        itemId: 'item_001',
        direction: StockAdjustmentDirection.increase,
        magnitude: 5.0,
        reason: 'Cycle count',
        performedByUserId: '   ',
      );

      expect(customRepo.adjustStockCalls, 0);
      expect(
        cubit.state,
        isA<AdjustInventoryStockFailure>().having(
          (s) => s.message,
          'message',
          contains('User ID cannot be blank'),
        ),
      );
    });

    test(
      'submit maps increase direction to positive delta and trims reason',
      () async {
        final movement = StockMovement(
          id: 'mov_101',
          inventoryItemId: 'item_001',
          type: StockMovementType.adjustment,
          quantityDelta: 10.0,
          createdAt: DateTime.utc(2026, 1, 1),
          performedByUserId: 'user_admin',
          reason: 'Audit correction',
        );
        final updatedSummary = InventoryItemSummary(
          item: sampleItem,
          quantityOnHand: 60.0,
        );

        AdjustInventoryStockInput? capturedInput;
        final customRepo = _CustomInventoryRepository(
          onGetItemById: (id) async => sampleSummary,
          onHasStockMovements: (id) async => true,
          onAdjustStock: (input) async {
            capturedInput = input;
            return InventoryStockMutationResult(
              movement: movement,
              item: updatedSummary,
            );
          },
        );

        final cubit = AdjustInventoryStockCubit(customRepo);
        await cubit.load('item_001');

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdjustInventoryStockSubmitting>(),
            isA<AdjustInventoryStockSuccess>().having(
              (s) => s.result.item.quantityOnHand,
              'quantityOnHand',
              60.0,
            ),
          ]),
        );

        await cubit.submit(
          itemId: 'item_001',
          direction: StockAdjustmentDirection.increase,
          magnitude: 10.0,
          reason: '  Audit correction  ',
          performedByUserId: 'user_admin_01',
        );

        expect(capturedInput?.itemId, 'item_001');
        expect(capturedInput?.quantityDelta, 10.0);
        expect(capturedInput?.reason, 'Audit correction');
        expect(capturedInput?.performedByUserId, 'user_admin_01');
      },
    );

    test('submit maps decrease direction to negative delta', () async {
      final movement = StockMovement(
        id: 'mov_102',
        inventoryItemId: 'item_001',
        type: StockMovementType.adjustment,
        quantityDelta: -5.5,
        createdAt: DateTime.utc(2026, 1, 1),
        performedByUserId: 'user_admin',
        reason: 'Damaged item',
      );
      final updatedSummary = InventoryItemSummary(
        item: sampleItem,
        quantityOnHand: 44.5,
      );

      AdjustInventoryStockInput? capturedInput;
      final customRepo = _CustomInventoryRepository(
        onGetItemById: (id) async => sampleSummary,
        onHasStockMovements: (id) async => true,
        onAdjustStock: (input) async {
          capturedInput = input;
          return InventoryStockMutationResult(
            movement: movement,
            item: updatedSummary,
          );
        },
      );

      final cubit = AdjustInventoryStockCubit(customRepo);
      await cubit.load('item_001');

      expectLater(
        cubit.stream,
        emitsInOrder([
          isA<AdjustInventoryStockSubmitting>(),
          isA<AdjustInventoryStockSuccess>().having(
            (s) => s.result.item.quantityOnHand,
            'quantityOnHand',
            44.5,
          ),
        ]),
      );

      await cubit.submit(
        itemId: 'item_001',
        direction: StockAdjustmentDirection.decrease,
        magnitude: 5.5,
        reason: 'Damaged item',
        performedByUserId: 'user_admin_01',
      );

      expect(capturedInput?.quantityDelta, -5.5);
    });

    test('submit maps InventoryNegativeStockException safely', () async {
      final customRepo = _CustomInventoryRepository(
        onGetItemById: (id) async => sampleSummary,
        onHasStockMovements: (id) async => true,
        onAdjustStock: (input) => throw const InventoryNegativeStockException(),
      );
      final cubit = AdjustInventoryStockCubit(customRepo);
      await cubit.load('item_001');

      await cubit.submit(
        itemId: 'item_001',
        direction: StockAdjustmentDirection.decrease,
        magnitude: 100.0,
        reason: 'Writeoff',
        performedByUserId: 'user_admin',
      );

      expect(
        cubit.state,
        isA<AdjustInventoryStockFailure>().having(
          (s) => s.message,
          'message',
          'This adjustment would make stock negative.',
        ),
      );
    });

    test('submit maps InventoryUninitializedStockException safely', () async {
      final customRepo = _CustomInventoryRepository(
        onGetItemById: (id) async => sampleSummary,
        onHasStockMovements: (id) async => true,
        onAdjustStock: (input) =>
            throw const InventoryUninitializedStockException('item_001'),
      );
      final cubit = AdjustInventoryStockCubit(customRepo);
      await cubit.load('item_001');

      await cubit.submit(
        itemId: 'item_001',
        direction: StockAdjustmentDirection.increase,
        magnitude: 10.0,
        reason: 'Initial add',
        performedByUserId: 'user_admin',
      );

      expect(
        cubit.state,
        isA<AdjustInventoryStockFailure>().having(
          (s) => s.message,
          'message',
          'Stock must be initialized before it can be adjusted.',
        ),
      );
    });

    test('submit maps generic failure safely', () async {
      final customRepo = _CustomInventoryRepository(
        onGetItemById: (id) async => sampleSummary,
        onHasStockMovements: (id) async => true,
        onAdjustStock: (input) => throw Exception('Crash'),
      );
      final cubit = AdjustInventoryStockCubit(customRepo);
      await cubit.load('item_001');

      await cubit.submit(
        itemId: 'item_001',
        direction: StockAdjustmentDirection.increase,
        magnitude: 10.0,
        reason: 'Restock',
        performedByUserId: 'user_admin',
      );

      expect(
        cubit.state,
        isA<AdjustInventoryStockFailure>().having(
          (s) => s.message,
          'message',
          'Unable to adjust stock.',
        ),
      );
    });

    test('double submit triggers repository mutation only once', () async {
      final completer = Completer<InventoryStockMutationResult>();
      final customRepo = _CustomInventoryRepository(
        onGetItemById: (id) async => sampleSummary,
        onHasStockMovements: (id) async => true,
        onAdjustStock: (input) => completer.future,
      );

      final cubit = AdjustInventoryStockCubit(customRepo);
      await cubit.load('item_001');

      final firstCall = cubit.submit(
        itemId: 'item_001',
        direction: StockAdjustmentDirection.increase,
        magnitude: 5.0,
        reason: 'Restock',
        performedByUserId: 'user_admin',
      );
      final secondCall = cubit.submit(
        itemId: 'item_001',
        direction: StockAdjustmentDirection.increase,
        magnitude: 5.0,
        reason: 'Restock',
        performedByUserId: 'user_admin',
      );

      completer.complete(
        InventoryStockMutationResult(
          movement: StockMovement(
            id: 'mov_1',
            inventoryItemId: 'item_001',
            type: StockMovementType.adjustment,
            quantityDelta: 5.0,
            createdAt: DateTime.utc(2026, 1, 1),
            performedByUserId: 'user_admin',
            reason: 'Restock',
          ),
          item: sampleSummary,
        ),
      );

      await Future.wait([firstCall, secondCall]);
      expect(customRepo.adjustStockCalls, 1);
    });
  });
}
