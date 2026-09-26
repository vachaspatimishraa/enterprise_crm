import 'dart:async';

import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_page.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/exceptions/inventory_exception.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/update_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_stock_mutation_result.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/record_opening_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/edit_inventory_item_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/edit_inventory_item_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';

class _CustomInventoryRepository implements InventoryRepository {
  final Future<InventoryItemSummary?> Function(String id)? onGetItemById;
  final Future<InventoryItemSummary> Function(UpdateInventoryItemInput)?
  onUpdateItem;
  int getItemByIdCalls = 0;
  int updateCalls = 0;

  _CustomInventoryRepository({this.onGetItemById, this.onUpdateItem});

  @override
  Future<InventoryPage> getItems(InventoryQuery query) =>
      throw UnimplementedError();

  @override
  Future<InventoryItemSummary?> getItemById(String id) {
    getItemByIdCalls++;
    if (onGetItemById != null) {
      return onGetItemById!(id);
    }
    return MockInventoryRepository().getItemById(id);
  }

  @override
  Future<InventoryItemSummary> createItem(CreateInventoryItemInput input) =>
      throw UnimplementedError();

  @override
  Future<InventoryItemSummary> updateItem(UpdateInventoryItemInput input) {
    updateCalls++;
    if (onUpdateItem != null) {
      return onUpdateItem!(input);
    }
    throw Exception('Default failure');
  }

  @override
  Future<bool> hasStockMovements(String itemId) => throw UnimplementedError();

  @override
  Future<InventoryStockMutationResult> recordOpeningStock(
    RecordOpeningStockInput input,
  ) => throw UnimplementedError();

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
  group('EditInventoryItemCubit Tests', () {
    test('initial state is EditInventoryItemInitial', () {
      final repo = MockInventoryRepository();
      final cubit = EditInventoryItemCubit(repo);

      expect(cubit.state, isA<EditInventoryItemInitial>());
      cubit.close();
    });

    test(
      'load emits [Loading, Loaded] and fetches fresh item by itemId',
      () async {
        final repo = _CustomInventoryRepository();
        final cubit = EditInventoryItemCubit(repo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<EditInventoryItemLoading>(),
            isA<EditInventoryItemLoaded>()
                .having((s) => s.item.item.id, 'id', 'item_001')
                .having((s) => s.item.item.name, 'name', 'Laptop Stand'),
          ]),
        );

        await cubit.load('item_001');
        expect(repo.getItemByIdCalls, 1);
        cubit.close();
      },
    );

    test('load emits [Loading, NotFound] when item does not exist', () async {
      final repo = MockInventoryRepository();
      final cubit = EditInventoryItemCubit(repo);

      expectLater(
        cubit.stream,
        emitsInOrder([
          isA<EditInventoryItemLoading>(),
          isA<EditInventoryItemNotFound>(),
        ]),
      );

      await cubit.load('missing_id');
      cubit.close();
    });

    test(
      'load emits [Loading, Failure] when repository throws error',
      () async {
        final repo = _CustomInventoryRepository(
          onGetItemById: (_) => throw Exception('DB connection failed'),
        );
        final cubit = EditInventoryItemCubit(repo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<EditInventoryItemLoading>(),
            isA<EditInventoryItemFailure>().having(
              (s) => s.message,
              'message',
              'Unable to load inventory item.',
            ),
          ]),
        );

        await cubit.load('item_001');
        cubit.close();
      },
    );

    test(
      'submit emits [Submitting, Success] on valid input and success',
      () async {
        final repo = MockInventoryRepository();
        final cubit = EditInventoryItemCubit(repo);

        await cubit.load('item_001');

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<EditInventoryItemSubmitting>(),
            isA<EditInventoryItemSuccess>()
                .having((s) => s.item.item.name, 'name', 'Laptop Stand Pro')
                .having((s) => s.item.item.sku, 'sku', 'INV-001-PRO')
                .having((s) => s.item.quantityOnHand, 'quantityOnHand', 25.0),
          ]),
        );

        await cubit.submit(name: 'Laptop Stand Pro', sku: 'INV-001-PRO');
        cubit.close();
      },
    );

    test(
      'submit emits Failure when name is blank without calling updateItem',
      () async {
        final repo = _CustomInventoryRepository();
        final cubit = EditInventoryItemCubit(repo);

        await cubit.load('item_001');

        expectLater(
          cubit.stream,
          emits(
            isA<EditInventoryItemFailure>().having(
              (s) => s.message,
              'message',
              'Item name is required.',
            ),
          ),
        );

        await cubit.submit(name: '   ', sku: 'INV-001');
        expect(repo.updateCalls, 0);
        cubit.close();
      },
    );

    test(
      'submit emits Failure when SKU is blank without calling updateItem',
      () async {
        final repo = _CustomInventoryRepository();
        final cubit = EditInventoryItemCubit(repo);

        await cubit.load('item_001');

        expectLater(
          cubit.stream,
          emits(
            isA<EditInventoryItemFailure>().having(
              (s) => s.message,
              'message',
              'SKU is required.',
            ),
          ),
        );

        await cubit.submit(name: 'Valid Name', sku: '   ');
        expect(repo.updateCalls, 0);
        cubit.close();
      },
    );

    test(
      'submit maps InventoryDuplicateSkuException to user-friendly message',
      () async {
        final repo = MockInventoryRepository();
        final cubit = EditInventoryItemCubit(repo);

        await cubit.load('item_001');

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<EditInventoryItemSubmitting>(),
            isA<EditInventoryItemFailure>().having(
              (s) => s.message,
              'message',
              'An item with this SKU already exists.',
            ),
          ]),
        );

        // item_002 has sku 'INV-002'
        await cubit.submit(name: 'Updated Name', sku: 'INV-002');
        cubit.close();
      },
    );

    test(
      'submit maps InventoryValidationException to validation message',
      () async {
        final repo = _CustomInventoryRepository(
          onUpdateItem: (_) => throw const InventoryValidationException(
            'Custom validation failure',
          ),
        );
        final cubit = EditInventoryItemCubit(repo);

        await cubit.load('item_001');

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<EditInventoryItemSubmitting>(),
            isA<EditInventoryItemFailure>().having(
              (s) => s.message,
              'message',
              'Custom validation failure',
            ),
          ]),
        );

        await cubit.submit(name: 'Valid Name', sku: 'VALID-SKU');
        cubit.close();
      },
    );

    test(
      'submit maps InventoryItemNotFoundException to EditInventoryItemNotFound',
      () async {
        final repo = _CustomInventoryRepository(
          onUpdateItem: (_) => throw const InventoryItemNotFoundException(),
        );
        final cubit = EditInventoryItemCubit(repo);

        await cubit.load('item_001');

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<EditInventoryItemSubmitting>(),
            isA<EditInventoryItemNotFound>(),
          ]),
        );

        await cubit.submit(name: 'Valid Name', sku: 'VALID-SKU');
        cubit.close();
      },
    );

    test('submit maps unexpected failure to safe generic message', () async {
      final repo = _CustomInventoryRepository(
        onUpdateItem: (_) => throw Exception('Fatal network crash'),
      );
      final cubit = EditInventoryItemCubit(repo);

      await cubit.load('item_001');

      expectLater(
        cubit.stream,
        emitsInOrder([
          isA<EditInventoryItemSubmitting>(),
          isA<EditInventoryItemFailure>().having(
            (s) => s.message,
            'message',
            'Unable to update inventory item.',
          ),
        ]),
      );

      await cubit.submit(name: 'Valid Name', sku: 'VALID-SKU');
      cubit.close();
    });

    test(
      'double-submit prevention prevents duplicate repository calls',
      () async {
        final completer = Completer<InventoryItemSummary>();
        final repo = _CustomInventoryRepository(
          onUpdateItem: (_) => completer.future,
        );
        final cubit = EditInventoryItemCubit(repo);

        await cubit.load('item_001');

        final future1 = cubit.submit(name: 'Item 1', sku: 'SKU-001');
        expect(cubit.state, isA<EditInventoryItemSubmitting>());

        final future2 = cubit.submit(name: 'Item 1', sku: 'SKU-001');
        expect(repo.updateCalls, 1);

        final fakeItem = (await MockInventoryRepository().getItemById(
          'item_001',
        ))!;
        completer.complete(fakeItem);

        await future1;
        await future2;

        expect(repo.updateCalls, 1);
        cubit.close();
      },
    );
  });
}
