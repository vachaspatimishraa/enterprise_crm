import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_page.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_sort.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/update_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_stock_mutation_result.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/record_opening_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_state.dart';
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

  @override
  Future<InventoryItemSummary> createItem(CreateInventoryItemInput input) {
    throw Exception('Database connection failed');
  }

  @override
  Future<InventoryItemSummary> updateItem(UpdateInventoryItemInput input) {
    throw Exception('Database connection failed');
  }

  @override
  Future<bool> hasStockMovements(String itemId) {
    throw Exception('Database connection failed');
  }

  @override
  Future<InventoryStockMutationResult> recordOpeningStock(
    RecordOpeningStockInput input,
  ) {
    throw Exception('Database connection failed');
  }

  @override
  Future<InventoryStockMutationResult> adjustStock(
    AdjustInventoryStockInput input,
  ) {
    throw Exception('Database connection failed');
  }
}

void main() {
  group('InventoryCubit Tests', () {
    test('initial state is InventoryInitial', () {
      final repo = MockInventoryRepository();
      final cubit = InventoryCubit(repo);

      expect(cubit.state, isA<InventoryInitial>());
      cubit.close();
    });

    test(
      'loadItems emits [InventoryLoading, InventoryLoaded] when items exist',
      () async {
        final repo = MockInventoryRepository();
        final cubit = InventoryCubit(repo);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<InventoryLoading>(),
            isA<InventoryLoaded>().having(
              (s) => s.page.items.length,
              'items length',
              20,
            ),
          ]),
        );

        await cubit.loadItems();
        cubit.close();
      },
    );

    test(
      'loadItems emits [InventoryLoading, InventoryEmpty] when 0 items exist',
      () async {
        final repo = MockInventoryRepository(items: [], movements: []);
        final cubit = InventoryCubit(repo);

        expectLater(
          cubit.stream,
          emitsInOrder([isA<InventoryLoading>(), isA<InventoryEmpty>()]),
        );

        await cubit.loadItems();
        cubit.close();
      },
    );

    test(
      'search matching nothing emits InventoryEmpty with isSearchResult = true',
      () async {
        final repo = MockInventoryRepository();
        final cubit = InventoryCubit(repo);

        await cubit.loadItems();

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<InventoryLoading>(),
            isA<InventoryEmpty>()
                .having(
                  (s) => s.query.searchText,
                  'searchText',
                  'no-match-xyz-term',
                )
                .having((s) => s.isSearchResult, 'isSearchResult', true),
          ]),
        );

        await cubit.search('no-match-xyz-term');
        cubit.close();
      },
    );

    test('setSort updates query and resets page to 1', () async {
      final repo = MockInventoryRepository();
      final cubit = InventoryCubit(repo);

      await cubit.loadItems();
      await cubit.nextPage();
      expect((cubit.state as InventoryLoaded).page.currentPage, 2);

      await cubit.setSort(InventorySort.skuDesc);
      final state = cubit.state as InventoryLoaded;
      expect(state.query.sort, InventorySort.skuDesc);
      expect(state.page.currentPage, 1);

      cubit.close();
    });

    test(
      'nextPage requests target page and previousPage navigates back',
      () async {
        final repo = MockInventoryRepository();
        final cubit = InventoryCubit(repo);

        await cubit.loadItems();
        await cubit.nextPage();

        var state = cubit.state as InventoryLoaded;
        expect(state.page.currentPage, 2);
        expect(state.page.items.length, 5);

        await cubit.previousPage();
        state = cubit.state as InventoryLoaded;
        expect(state.page.currentPage, 1);
        expect(state.page.items.length, 20);

        cubit.close();
      },
    );

    test('repository failure emits user-safe InventoryFailure', () async {
      final failingRepo = _FailingInventoryRepository();
      final cubit = InventoryCubit(failingRepo);

      expectLater(
        cubit.stream,
        emitsInOrder([
          isA<InventoryLoading>(),
          isA<InventoryFailure>().having(
            (s) => s.message,
            'message',
            'Unable to load inventory.',
          ),
        ]),
      );

      await cubit.loadItems();
      cubit.close();
    });
  });
}
