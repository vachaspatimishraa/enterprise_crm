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
import 'package:enterprise_crm/features/inventory/presentation/bloc/set_opening_stock_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/set_opening_stock_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';

class _CustomInventoryRepository implements InventoryRepository {
  final Future<InventoryItemSummary?> Function(String)? onGetItemById;
  final Future<bool> Function(String)? onHasStockMovements;
  final Future<InventoryStockMutationResult> Function(RecordOpeningStockInput)?
  onRecordOpeningStock;

  int recordOpeningStockCalls = 0;

  _CustomInventoryRepository({
    this.onGetItemById,
    this.onHasStockMovements,
    this.onRecordOpeningStock,
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
  ) {
    recordOpeningStockCalls++;
    if (onRecordOpeningStock != null) return onRecordOpeningStock!(input);
    throw Exception('Default mutation failure');
  }

  @override
  Future<InventoryStockMutationResult> adjustStock(
    AdjustInventoryStockInput input,
  ) => throw UnimplementedError();

  @override
  Future<Set<String>> getExistingSkus() => Future.value({});

  @override
  Future<InventoryImportResult> importItems(InventoryImportRequest request) =>
      throw UnimplementedError();
}

void main() {
  group('SetOpeningStockCubit', () {
    final sampleItem = InventoryItem(
      id: 'item_new_1',
      name: 'Uninitialized Item',
      sku: 'SKU-NEW-1',
    );
    final sampleSummary = InventoryItemSummary(
      item: sampleItem,
      quantityOnHand: 0.0,
    );

    test('initial state is SetOpeningStockInitial', () {
      final cubit = SetOpeningStockCubit(MockInventoryRepository());
      expect(cubit.state, isA<SetOpeningStockInitial>());
    });

    test(
      'load transitions to SetOpeningStockReady for 0-movement item',
      () async {
        final customRepo = _CustomInventoryRepository(
          onGetItemById: (id) async => sampleSummary,
          onHasStockMovements: (id) async => false,
        );
        final cubit = SetOpeningStockCubit(customRepo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<SetOpeningStockLoading>(),
            isA<SetOpeningStockReady>().having(
              (s) => s.item.item.id,
              'item.item.id',
              'item_new_1',
            ),
          ]),
        );

        await cubit.load('item_new_1');
      },
    );

    test(
      'load transitions to SetOpeningStockUnavailable when movements exist',
      () async {
        final customRepo = _CustomInventoryRepository(
          onGetItemById: (id) async => sampleSummary,
          onHasStockMovements: (id) async => true,
        );
        final cubit = SetOpeningStockCubit(customRepo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<SetOpeningStockLoading>(),
            isA<SetOpeningStockUnavailable>().having(
              (s) => s.message,
              'message',
              contains('Opening stock has already been initialized'),
            ),
          ]),
        );

        await cubit.load('item_new_1');
      },
    );

    test(
      'load transitions to SetOpeningStockNotFound when item is missing',
      () async {
        final customRepo = _CustomInventoryRepository(
          onGetItemById: (id) async => null,
        );
        final cubit = SetOpeningStockCubit(customRepo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<SetOpeningStockLoading>(),
            isA<SetOpeningStockNotFound>().having(
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
      'load transitions to SetOpeningStockFailure when repository throws',
      () async {
        final customRepo = _CustomInventoryRepository(
          onGetItemById: (id) => throw Exception('Network error'),
        );
        final cubit = SetOpeningStockCubit(customRepo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<SetOpeningStockLoading>(),
            isA<SetOpeningStockFailure>().having(
              (s) => s.message,
              'message',
              contains('Unable to load'),
            ),
          ]),
        );

        await cubit.load('item_error');
      },
    );

    test('submit rejects zero quantity without calling repository', () async {
      final customRepo = _CustomInventoryRepository();
      final cubit = SetOpeningStockCubit(customRepo);

      await cubit.submit(
        itemId: 'item_new_1',
        quantity: 0.0,
        performedByUserId: 'user_admin',
      );

      expect(customRepo.recordOpeningStockCalls, 0);
      expect(
        cubit.state,
        isA<SetOpeningStockFailure>().having(
          (s) => s.message,
          'message',
          contains('must be greater than zero'),
        ),
      );
    });

    test(
      'submit rejects negative quantity without calling repository',
      () async {
        final customRepo = _CustomInventoryRepository();
        final cubit = SetOpeningStockCubit(customRepo);

        await cubit.submit(
          itemId: 'item_new_1',
          quantity: -5.0,
          performedByUserId: 'user_admin',
        );

        expect(customRepo.recordOpeningStockCalls, 0);
        expect(
          cubit.state,
          isA<SetOpeningStockFailure>().having(
            (s) => s.message,
            'message',
            contains('must be greater than zero'),
          ),
        );
      },
    );

    test('submit rejects NaN and Infinity quantity', () async {
      final customRepo = _CustomInventoryRepository();
      final cubit = SetOpeningStockCubit(customRepo);

      await cubit.submit(
        itemId: 'item_new_1',
        quantity: double.nan,
        performedByUserId: 'user_admin',
      );
      expect(customRepo.recordOpeningStockCalls, 0);
      expect(cubit.state, isA<SetOpeningStockFailure>());

      await cubit.submit(
        itemId: 'item_new_1',
        quantity: double.infinity,
        performedByUserId: 'user_admin',
      );
      expect(customRepo.recordOpeningStockCalls, 0);
      expect(cubit.state, isA<SetOpeningStockFailure>());
    });

    test('submit rejects blank actor user ID', () async {
      final customRepo = _CustomInventoryRepository();
      final cubit = SetOpeningStockCubit(customRepo);

      await cubit.submit(
        itemId: 'item_new_1',
        quantity: 10.0,
        performedByUserId: '   ',
      );

      expect(customRepo.recordOpeningStockCalls, 0);
      expect(
        cubit.state,
        isA<SetOpeningStockFailure>().having(
          (s) => s.message,
          'message',
          contains('User ID cannot be blank'),
        ),
      );
    });

    test('submit succeeds and emits SetOpeningStockSuccess', () async {
      final movement = StockMovement(
        id: 'mov_100',
        inventoryItemId: 'item_new_1',
        type: StockMovementType.openingStock,
        quantityDelta: 25.0,
        createdAt: DateTime.utc(2026, 1, 1),
        performedByUserId: 'user_admin',
        reason: null,
      );
      final updatedSummary = InventoryItemSummary(
        item: sampleItem,
        quantityOnHand: 25.0,
      );

      RecordOpeningStockInput? capturedInput;
      final customRepo = _CustomInventoryRepository(
        onGetItemById: (id) async => sampleSummary,
        onHasStockMovements: (id) async => false,
        onRecordOpeningStock: (input) async {
          capturedInput = input;
          return InventoryStockMutationResult(
            movement: movement,
            item: updatedSummary,
          );
        },
      );

      final cubit = SetOpeningStockCubit(customRepo);
      await cubit.load('item_new_1');

      expectLater(
        cubit.stream,
        emitsInOrder([
          isA<SetOpeningStockSubmitting>(),
          isA<SetOpeningStockSuccess>().having(
            (s) => s.result.item.quantityOnHand,
            'quantityOnHand',
            25.0,
          ),
        ]),
      );

      await cubit.submit(
        itemId: 'item_new_1',
        quantity: 25.0,
        performedByUserId: 'user_admin_01',
      );

      expect(capturedInput?.itemId, 'item_new_1');
      expect(capturedInput?.quantity, 25.0);
      expect(capturedInput?.performedByUserId, 'user_admin_01');
    });

    test(
      'submit maps InventoryOpeningStockAlreadyRecordedException safely',
      () async {
        final customRepo = _CustomInventoryRepository(
          onGetItemById: (id) async => sampleSummary,
          onHasStockMovements: (id) async => false,
          onRecordOpeningStock: (input) =>
              throw const InventoryOpeningStockAlreadyRecordedException(
                'item_new_1',
              ),
        );
        final cubit = SetOpeningStockCubit(customRepo);
        await cubit.load('item_new_1');

        await cubit.submit(
          itemId: 'item_new_1',
          quantity: 15.0,
          performedByUserId: 'user_admin',
        );

        expect(
          cubit.state,
          isA<SetOpeningStockFailure>().having(
            (s) => s.message,
            'message',
            contains('Opening stock has already been initialized'),
          ),
        );
      },
    );

    test('submit maps generic failure safely', () async {
      final customRepo = _CustomInventoryRepository(
        onGetItemById: (id) async => sampleSummary,
        onHasStockMovements: (id) async => false,
        onRecordOpeningStock: (input) => throw Exception('DB error'),
      );
      final cubit = SetOpeningStockCubit(customRepo);
      await cubit.load('item_new_1');

      await cubit.submit(
        itemId: 'item_new_1',
        quantity: 15.0,
        performedByUserId: 'user_admin',
      );

      expect(
        cubit.state,
        isA<SetOpeningStockFailure>().having(
          (s) => s.message,
          'message',
          'Unable to set opening stock.',
        ),
      );
    });

    test('double submit triggers repository mutation only once', () async {
      final completer = Completer<InventoryStockMutationResult>();
      final customRepo = _CustomInventoryRepository(
        onGetItemById: (id) async => sampleSummary,
        onHasStockMovements: (id) async => false,
        onRecordOpeningStock: (input) => completer.future,
      );

      final cubit = SetOpeningStockCubit(customRepo);
      await cubit.load('item_new_1');

      final firstCall = cubit.submit(
        itemId: 'item_new_1',
        quantity: 10.0,
        performedByUserId: 'user_admin',
      );
      final secondCall = cubit.submit(
        itemId: 'item_new_1',
        quantity: 10.0,
        performedByUserId: 'user_admin',
      );

      completer.complete(
        InventoryStockMutationResult(
          movement: StockMovement(
            id: 'mov_1',
            inventoryItemId: 'item_new_1',
            type: StockMovementType.openingStock,
            quantityDelta: 10.0,
            createdAt: DateTime.utc(2026, 1, 1),
            performedByUserId: 'user_admin',
          ),
          item: sampleSummary,
        ),
      );

      await Future.wait([firstCall, secondCall]);
      expect(customRepo.recordOpeningStockCalls, 1);
    });
  });
}
