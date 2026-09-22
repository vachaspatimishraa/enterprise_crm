import 'dart:async';

import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_page.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/exceptions/inventory_exception.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/update_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/create_inventory_item_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/create_inventory_item_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _CustomInventoryRepository implements InventoryRepository {
  final Future<InventoryItemSummary> Function(CreateInventoryItemInput)?
  onCreateItem;
  int createCalls = 0;

  _CustomInventoryRepository({this.onCreateItem});

  @override
  Future<InventoryPage> getItems(InventoryQuery query) =>
      throw UnimplementedError();

  @override
  Future<InventoryItemSummary?> getItemById(String id) =>
      throw UnimplementedError();

  @override
  Future<InventoryItemSummary> createItem(CreateInventoryItemInput input) {
    createCalls++;
    if (onCreateItem != null) {
      return onCreateItem!(input);
    }
    throw Exception('Default failure');
  }

  @override
  Future<InventoryItemSummary> updateItem(UpdateInventoryItemInput input) =>
      throw UnimplementedError();
}

void main() {
  group('CreateInventoryItemCubit Tests', () {
    test('initial state is CreateInventoryItemInitial', () {
      final repo = MockInventoryRepository();
      final cubit = CreateInventoryItemCubit(repo);

      expect(cubit.state, isA<CreateInventoryItemInitial>());
      cubit.close();
    });

    test(
      'submit emits [Submitting, Success] on valid input and success',
      () async {
        final repo = MockInventoryRepository();
        final cubit = CreateInventoryItemCubit(repo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<CreateInventoryItemSubmitting>(),
            isA<CreateInventoryItemSuccess>()
                .having((s) => s.item.item.name, 'name', 'New Item')
                .having((s) => s.item.item.sku, 'sku', 'NEW-SKU-001'),
          ]),
        );

        await cubit.submit(name: 'New Item', sku: 'NEW-SKU-001');
        cubit.close();
      },
    );

    test(
      'submit emits Failure when name is blank without calling repository',
      () async {
        final repo = _CustomInventoryRepository();
        final cubit = CreateInventoryItemCubit(repo);

        expectLater(
          cubit.stream,
          emits(
            isA<CreateInventoryItemFailure>().having(
              (s) => s.message,
              'message',
              'Item name is required.',
            ),
          ),
        );

        await cubit.submit(name: '   ', sku: 'SKU-001');
        expect(repo.createCalls, 0);
        cubit.close();
      },
    );

    test(
      'submit emits Failure when SKU is blank without calling repository',
      () async {
        final repo = _CustomInventoryRepository();
        final cubit = CreateInventoryItemCubit(repo);

        expectLater(
          cubit.stream,
          emits(
            isA<CreateInventoryItemFailure>().having(
              (s) => s.message,
              'message',
              'SKU is required.',
            ),
          ),
        );

        await cubit.submit(name: 'Valid Name', sku: '   ');
        expect(repo.createCalls, 0);
        cubit.close();
      },
    );

    test(
      'maps InventoryValidationException from repository to safe message',
      () async {
        final repo = _CustomInventoryRepository(
          onCreateItem: (_) => throw const InventoryValidationException(
            'Custom validation message',
          ),
        );
        final cubit = CreateInventoryItemCubit(repo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<CreateInventoryItemSubmitting>(),
            isA<CreateInventoryItemFailure>().having(
              (s) => s.message,
              'message',
              'Custom validation message',
            ),
          ]),
        );

        await cubit.submit(name: 'Name', sku: 'SKU');
        cubit.close();
      },
    );

    test(
      'maps InventoryDuplicateSkuException to duplicate SKU message',
      () async {
        final repo = MockInventoryRepository();
        final cubit = CreateInventoryItemCubit(repo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<CreateInventoryItemSubmitting>(),
            isA<CreateInventoryItemFailure>().having(
              (s) => s.message,
              'message',
              'An item with this SKU already exists.',
            ),
          ]),
        );

        // INV-001 exists in seed data
        await cubit.submit(name: 'Laptop Stand Copy', sku: 'INV-001');
        cubit.close();
      },
    );

    test(
      'maps unexpected repository failure to safe generic error message',
      () async {
        final repo = _CustomInventoryRepository(
          onCreateItem: (_) => throw Exception('Fatal network/database crash'),
        );
        final cubit = CreateInventoryItemCubit(repo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<CreateInventoryItemSubmitting>(),
            isA<CreateInventoryItemFailure>().having(
              (s) => s.message,
              'message',
              'Unable to create inventory item.',
            ),
          ]),
        );

        await cubit.submit(name: 'Name', sku: 'SKU');
        cubit.close();
      },
    );

    test(
      'double-submit prevention prevents duplicate repository calls',
      () async {
        final completer = Completer<InventoryItemSummary>();
        final repo = _CustomInventoryRepository(
          onCreateItem: (_) => completer.future,
        );
        final cubit = CreateInventoryItemCubit(repo);

        // Start first submit
        final future1 = cubit.submit(name: 'Item 1', sku: 'SKU-001');
        expect(cubit.state, isA<CreateInventoryItemSubmitting>());

        // Second submit while first is active
        final future2 = cubit.submit(name: 'Item 1', sku: 'SKU-001');

        expect(repo.createCalls, 1);

        final fakeItem = (await MockInventoryRepository().getItemById(
          'item_001',
        ))!;
        completer.complete(fakeItem);

        await future1;
        await future2;

        expect(repo.createCalls, 1);
        cubit.close();
      },
    );
  });
}
