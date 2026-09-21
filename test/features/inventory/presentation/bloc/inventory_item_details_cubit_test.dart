import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_page.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_item_details_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_item_details_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingInventoryRepository implements InventoryRepository {
  @override
  Future<InventoryPage> getItems(InventoryQuery query) {
    throw Exception('Database connection failed');
  }

  @override
  Future<InventoryItemSummary?> getItemById(String id) {
    throw Exception('Database connection failed');
  }
}

void main() {
  group('InventoryItemDetailsCubit Tests', () {
    test('initial state is InventoryItemDetailsInitial', () {
      final repo = MockInventoryRepository();
      final cubit = InventoryItemDetailsCubit(repo);

      expect(cubit.state, isA<InventoryItemDetailsInitial>());
      cubit.close();
    });

    test('load emits [Loading, Loaded] when item exists', () async {
      final repo = MockInventoryRepository();
      final cubit = InventoryItemDetailsCubit(repo);

      expectLater(
        cubit.stream,
        emitsInOrder([
          isA<InventoryItemDetailsLoading>(),
          isA<InventoryItemDetailsLoaded>().having(
            (s) => s.summary.item.name,
            'name',
            'Laptop Stand',
          ),
        ]),
      );

      await cubit.load('item_001');
      cubit.close();
    });

    test('load emits [Loading, NotFound] when item does not exist', () async {
      final repo = MockInventoryRepository();
      final cubit = InventoryItemDetailsCubit(repo);

      expectLater(
        cubit.stream,
        emitsInOrder([
          isA<InventoryItemDetailsLoading>(),
          isA<InventoryItemDetailsNotFound>().having(
            (s) => s.id,
            'id',
            'unknown_item',
          ),
        ]),
      );

      await cubit.load('unknown_item');
      cubit.close();
    });

    test(
      'load emits [Loading, Failure] when repository throws error',
      () async {
        final failingRepo = _FailingInventoryRepository();
        final cubit = InventoryItemDetailsCubit(failingRepo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<InventoryItemDetailsLoading>(),
            isA<InventoryItemDetailsFailure>().having(
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
  });
}
