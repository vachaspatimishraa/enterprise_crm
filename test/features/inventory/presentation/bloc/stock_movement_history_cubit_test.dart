import 'dart:async';

import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_page.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_stock_mutation_result.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/pending_inventory_deletion.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_record.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:enterprise_crm/features/inventory/domain/exceptions/inventory_exception.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_to_target_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/record_opening_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/update_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/stock_movement_history_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/stock_movement_history_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHistoryInventoryRepository implements InventoryRepository {
  Future<List<StockMovementRecord>> Function(String itemId)?
  onGetStockMovements;
  int getStockMovementsCallCount = 0;

  _FakeHistoryInventoryRepository();

  @override
  Future<List<StockMovementRecord>> getStockMovements(String itemId) async {
    getStockMovementsCallCount++;
    if (onGetStockMovements != null) {
      return onGetStockMovements!(itemId);
    }
    return [];
  }

  @override
  Future<InventoryPage> getItems(InventoryQuery query) =>
      throw UnimplementedError();
  @override
  Future<InventoryItemSummary?> getItemById(String id) =>
      throw UnimplementedError();
  @override
  Future<InventoryItemSummary> createItem(CreateInventoryItemInput input) =>
      throw UnimplementedError();
  @override
  Future<InventoryItemSummary> updateItem(UpdateInventoryItemInput input) =>
      throw UnimplementedError();
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
  Future<InventoryStockMutationResult> adjustStockToTarget(
    AdjustInventoryStockToTargetInput input,
  ) => throw UnimplementedError();
  @override
  Future<Set<String>> getExistingSkus() => throw UnimplementedError();
  @override
  Future<InventoryImportResult> importItems(InventoryImportRequest request) =>
      throw UnimplementedError();
  @override
  Future<PendingInventoryDeletion> requestItemDeletion({
    required String itemId,
    required String performedByUserId,
  }) => throw UnimplementedError();
  @override
  Future<void> undoItemDeletion({
    required String itemId,
    required String performedByUserId,
  }) => throw UnimplementedError();
  @override
  Future<void> finalizeExpiredDeletions() => throw UnimplementedError();
  @override
  Future<List<PendingInventoryDeletion>> getPendingDeletions() =>
      throw UnimplementedError();
}

void main() {
  group('StockMovementHistoryCubit', () {
    late _FakeHistoryInventoryRepository fakeRepo;

    final adminUser = const CurrentUser(
      id: 'admin_1',
      displayName: 'Admin User',
      accountType: AccountType.admin,
    );

    final authorizedUser = const CurrentUser(
      id: 'user_1',
      displayName: 'Inventory Viewer',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {CrmPermissions.inventoryView},
    );

    final unauthorizedUser = const CurrentUser(
      id: 'user_2',
      displayName: 'No Access User',
      accountType: AccountType.user,
      modules: {},
      permissions: {},
    );

    StockMovementRecord createSampleRecord({
      required String id,
      required String itemId,
      required double delta,
      required double balance,
      StockMovementType type = StockMovementType.adjustment,
      String? reason,
    }) {
      return StockMovementRecord(
        movement: StockMovement(
          id: id,
          inventoryItemId: itemId,
          type: type,
          quantityDelta: delta,
          createdAt: DateTime.utc(2026, 1, 1, 9, 0),
          performedByUserId: 'usr_admin',
          reason: reason,
        ),
        runningBalance: balance,
      );
    }

    setUp(() {
      fakeRepo = _FakeHistoryInventoryRepository();
    });

    test('initial state is StockMovementHistoryInitial', () {
      final cubit = StockMovementHistoryCubit(
        repository: fakeRepo,
        currentUser: adminUser,
      );
      expect(cubit.state, equals(const StockMovementHistoryInitial()));
      expect(cubit.lastItemId, isNull);
      expect(fakeRepo.getStockMovementsCallCount, 0);
    });

    test('rejects blank item ID with StockMovementHistoryFailure', () async {
      final cubit = StockMovementHistoryCubit(
        repository: fakeRepo,
        currentUser: adminUser,
      );

      await cubit.loadHistory('   ');

      expect(cubit.state, isA<StockMovementHistoryFailure>());
      final failure = cubit.state as StockMovementHistoryFailure;
      expect(failure.message, 'Item ID cannot be blank.');
      expect(fakeRepo.getStockMovementsCallCount, 0);
    });

    test(
      'successful load emits Loading and Loaded preserving repository records and order',
      () async {
        final sampleRecords = [
          createSampleRecord(
            id: 'mov_2',
            itemId: 'item_1',
            delta: 20.0,
            balance: 70.0,
            reason: 'Restock',
          ),
          createSampleRecord(
            id: 'mov_1',
            itemId: 'item_1',
            delta: 50.0,
            balance: 50.0,
            type: StockMovementType.openingStock,
          ),
        ];

        fakeRepo.onGetStockMovements = (id) async => sampleRecords;

        final cubit = StockMovementHistoryCubit(
          repository: fakeRepo,
          currentUser: authorizedUser,
        );

        final states = <StockMovementHistoryState>[];
        cubit.stream.listen(states.add);

        await cubit.loadHistory('item_1');
        await pumpEventQueue();

        expect(states, [
          const StockMovementHistoryLoading('item_1'),
          StockMovementHistoryLoaded(itemId: 'item_1', records: sampleRecords),
        ]);

        final loaded = cubit.state as StockMovementHistoryLoaded;
        expect(loaded.records, hasLength(2));
        expect(loaded.records[0].runningBalance, 70.0);
        expect(loaded.records[1].runningBalance, 50.0);
        expect(loaded.itemId, 'item_1');
        expect(cubit.lastItemId, 'item_1');
      },
    );

    test(
      'initialized item with resulting balance zero emits Loaded rather than Empty',
      () async {
        final zeroBalanceRecords = [
          createSampleRecord(
            id: 'mov_2',
            itemId: 'item_1',
            delta: -50.0,
            balance: 0.0,
            reason: 'Zeroed out',
          ),
          createSampleRecord(
            id: 'mov_1',
            itemId: 'item_1',
            delta: 50.0,
            balance: 50.0,
            type: StockMovementType.openingStock,
          ),
        ];

        fakeRepo.onGetStockMovements = (id) async => zeroBalanceRecords;

        final cubit = StockMovementHistoryCubit(
          repository: fakeRepo,
          currentUser: authorizedUser,
        );

        await cubit.loadHistory('item_1');

        expect(cubit.state, isA<StockMovementHistoryLoaded>());
        final loaded = cubit.state as StockMovementHistoryLoaded;
        expect(loaded.records, hasLength(2));
        expect(loaded.records.first.runningBalance, 0.0);
      },
    );

    test('existing item with zero movements emits Empty', () async {
      fakeRepo.onGetStockMovements = (id) async => [];

      final cubit = StockMovementHistoryCubit(
        repository: fakeRepo,
        currentUser: authorizedUser,
      );

      await cubit.loadHistory('item_uninitialized');

      expect(
        cubit.state,
        const StockMovementHistoryEmpty('item_uninitialized'),
      );
    });

    test(
      'missing or permanently deleted item throws InventoryItemNotFoundException and emits NotFound',
      () async {
        fakeRepo.onGetStockMovements = (id) async =>
            throw const InventoryItemNotFoundException('Item not found.');

        final cubit = StockMovementHistoryCubit(
          repository: fakeRepo,
          currentUser: authorizedUser,
        );

        await cubit.loadHistory('item_deleted');

        expect(cubit.state, const StockMovementHistoryNotFound('item_deleted'));
      },
    );

    test(
      'unexpected repository exception emits Failure without leaking raw stack trace',
      () async {
        fakeRepo.onGetStockMovements = (id) async =>
            throw Exception('Database disk error');

        final cubit = StockMovementHistoryCubit(
          repository: fakeRepo,
          currentUser: authorizedUser,
        );

        await cubit.loadHistory('item_1');

        expect(cubit.state, isA<StockMovementHistoryFailure>());
        final failure = cubit.state as StockMovementHistoryFailure;
        expect(failure.message, 'Unable to load stock movement history.');
        expect(failure.itemId, 'item_1');
      },
    );

    group('Authorization Matrix', () {
      test('Admin is unconditionally authorized to view history', () async {
        fakeRepo.onGetStockMovements = (id) async => [];

        final cubit = StockMovementHistoryCubit(
          repository: fakeRepo,
          currentUser: adminUser,
        );

        await cubit.loadHistory('item_1');

        expect(cubit.state, const StockMovementHistoryEmpty('item_1'));
        expect(fakeRepo.getStockMovementsCallCount, 1);
      });

      test(
        'Standard user with inventory module and inventory.view is authorized',
        () async {
          fakeRepo.onGetStockMovements = (id) async => [];

          final cubit = StockMovementHistoryCubit(
            repository: fakeRepo,
            currentUser: authorizedUser,
          );

          await cubit.loadHistory('item_1');

          expect(cubit.state, const StockMovementHistoryEmpty('item_1'));
          expect(fakeRepo.getStockMovementsCallCount, 1);
        },
      );

      test(
        'Standard user lacking inventory module emits Restricted without querying repository',
        () async {
          final userWithoutModule = const CurrentUser(
            id: 'user_no_module',
            displayName: 'No Module User',
            accountType: AccountType.user,
            modules: {CrmModule.leadManagement},
            permissions: {CrmPermissions.inventoryView},
          );

          final cubit = StockMovementHistoryCubit(
            repository: fakeRepo,
            currentUser: userWithoutModule,
          );

          await cubit.loadHistory('item_1');

          expect(cubit.state, const StockMovementHistoryRestricted('item_1'));
          expect(fakeRepo.getStockMovementsCallCount, 0);
        },
      );

      test(
        'Standard user with inventory module but lacking inventory.view emits Restricted without querying repository',
        () async {
          final userWithoutView = const CurrentUser(
            id: 'user_no_view',
            displayName: 'No View User',
            accountType: AccountType.user,
            modules: {CrmModule.inventory},
            permissions: {},
          );

          final cubit = StockMovementHistoryCubit(
            repository: fakeRepo,
            currentUser: userWithoutView,
          );

          await cubit.loadHistory('item_1');

          expect(cubit.state, const StockMovementHistoryRestricted('item_1'));
          expect(fakeRepo.getStockMovementsCallCount, 0);
        },
      );

      test(
        'Other inventory permissions without inventory.view do NOT grant access',
        () async {
          final permissionsToTest = [
            CrmPermissions.inventoryCreate,
            CrmPermissions.inventoryEdit,
            CrmPermissions.inventoryDelete,
            CrmPermissions.inventoryStockManage,
            CrmPermissions.inventoryImportCsv,
            CrmPermissions.inventoryImportXlsx,
          ];

          for (final perm in permissionsToTest) {
            fakeRepo.getStockMovementsCallCount = 0;
            final user = CurrentUser(
              id: 'user_test',
              displayName: 'Test User',
              accountType: AccountType.user,
              modules: {CrmModule.inventory},
              permissions: {perm},
            );

            final cubit = StockMovementHistoryCubit(
              repository: fakeRepo,
              currentUser: user,
            );

            await cubit.loadHistory('item_1');

            expect(
              cubit.state,
              const StockMovementHistoryRestricted('item_1'),
              reason: 'Permission $perm should not grant history access',
            );
            expect(fakeRepo.getStockMovementsCallCount, 0);
          }
        },
      );
    });

    group('Retry Flow', () {
      test(
        'retry re-attempts loading using the last requested item ID',
        () async {
          var failFirst = true;
          fakeRepo.onGetStockMovements = (id) async {
            if (failFirst) {
              failFirst = false;
              throw Exception('Temporary network glitch');
            }
            return [
              createSampleRecord(
                id: 'mov_1',
                itemId: id,
                delta: 10.0,
                balance: 10.0,
              ),
            ];
          };

          final cubit = StockMovementHistoryCubit(
            repository: fakeRepo,
            currentUser: authorizedUser,
          );

          await cubit.loadHistory('item_retry');
          expect(cubit.state, isA<StockMovementHistoryFailure>());
          expect(fakeRepo.getStockMovementsCallCount, 1);

          await cubit.retry();
          expect(cubit.state, isA<StockMovementHistoryLoaded>());
          final loaded = cubit.state as StockMovementHistoryLoaded;
          expect(loaded.records, hasLength(1));
          expect(fakeRepo.getStockMovementsCallCount, 2);
        },
      );

      test(
        'retry rechecks authorization and denies access if permission was revoked',
        () async {
          var user = authorizedUser;
          fakeRepo.onGetStockMovements = (id) async =>
              throw Exception('First attempt error');

          final cubit = StockMovementHistoryCubit(
            repository: fakeRepo,
            currentUser: user,
            currentUserProvider: () => user,
          );

          await cubit.loadHistory('item_1');
          expect(cubit.state, isA<StockMovementHistoryFailure>());

          // Revoke permissions before retry
          user = unauthorizedUser;

          await cubit.retry();
          expect(cubit.state, const StockMovementHistoryRestricted('item_1'));
          // Repository should not have been called a second time
          expect(fakeRepo.getStockMovementsCallCount, 1);
        },
      );

      test('calling retry before loadHistory does nothing', () async {
        final cubit = StockMovementHistoryCubit(
          repository: fakeRepo,
          currentUser: authorizedUser,
        );

        await cubit.retry();

        expect(cubit.state, const StockMovementHistoryInitial());
        expect(fakeRepo.getStockMovementsCallCount, 0);
      });
    });

    group('Concurrency & Race Condition Protection', () {
      test(
        'newer request result wins even if older request completes later',
        () async {
          final completerA = Completer<List<StockMovementRecord>>();
          final completerB = Completer<List<StockMovementRecord>>();

          fakeRepo.onGetStockMovements = (id) {
            if (id == 'item_A') return completerA.future;
            if (id == 'item_B') return completerB.future;
            return Future.value([]);
          };

          final cubit = StockMovementHistoryCubit(
            repository: fakeRepo,
            currentUser: authorizedUser,
          );

          // Start request A
          final futureA = cubit.loadHistory('item_A');
          expect(cubit.state, const StockMovementHistoryLoading('item_A'));

          // Start request B (supersedes A)
          final futureB = cubit.loadHistory('item_B');
          expect(cubit.state, const StockMovementHistoryLoading('item_B'));

          // Complete B first
          completerB.complete([
            createSampleRecord(
              id: 'mov_B',
              itemId: 'item_B',
              delta: 25.0,
              balance: 25.0,
            ),
          ]);
          await futureB;

          expect(cubit.state, isA<StockMovementHistoryLoaded>());
          expect((cubit.state as StockMovementHistoryLoaded).itemId, 'item_B');

          // Complete A later
          completerA.complete([
            createSampleRecord(
              id: 'mov_A',
              itemId: 'item_A',
              delta: 50.0,
              balance: 50.0,
            ),
          ]);
          await futureA;

          // State MUST remain associated with item_B (late A is dropped)
          expect(cubit.state, isA<StockMovementHistoryLoaded>());
          expect((cubit.state as StockMovementHistoryLoaded).itemId, 'item_B');
        },
      );

      test(
        'late failure from older request does not overwrite newer successful state',
        () async {
          final completerA = Completer<List<StockMovementRecord>>();
          final completerB = Completer<List<StockMovementRecord>>();

          fakeRepo.onGetStockMovements = (id) {
            if (id == 'item_A') return completerA.future;
            if (id == 'item_B') return completerB.future;
            return Future.value([]);
          };

          final cubit = StockMovementHistoryCubit(
            repository: fakeRepo,
            currentUser: authorizedUser,
          );

          final futureA = cubit.loadHistory('item_A');
          final futureB = cubit.loadHistory('item_B');

          completerB.complete([
            createSampleRecord(
              id: 'mov_B',
              itemId: 'item_B',
              delta: 25.0,
              balance: 25.0,
            ),
          ]);
          await futureB;

          expect(cubit.state, isA<StockMovementHistoryLoaded>());

          // Throw error on late request A
          completerA.completeError(Exception('Late error from A'));
          await futureA;

          // State remains item_B Loaded
          expect(cubit.state, isA<StockMovementHistoryLoaded>());
          expect((cubit.state as StockMovementHistoryLoaded).itemId, 'item_B');
        },
      );
    });

    group('Disposal & Safety', () {
      test(
        'asynchronous repository completion after cubit close does not emit or throw',
        () async {
          final completer = Completer<List<StockMovementRecord>>();
          fakeRepo.onGetStockMovements = (id) => completer.future;

          final cubit = StockMovementHistoryCubit(
            repository: fakeRepo,
            currentUser: authorizedUser,
          );

          final loadFuture = cubit.loadHistory('item_1');
          expect(cubit.state, const StockMovementHistoryLoading('item_1'));

          // Close cubit while request is awaiting
          await cubit.close();

          // Complete the future
          completer.complete([
            createSampleRecord(
              id: 'mov_1',
              itemId: 'item_1',
              delta: 10.0,
              balance: 10.0,
            ),
          ]);
          await loadFuture;

          // No exception thrown, cubit remains safely closed
          expect(cubit.isClosed, isTrue);
        },
      );
    });

    group('Permission Revocation in Flight', () {
      test(
        'revoking permission while request is awaiting emits Restricted upon completion',
        () async {
          var user = authorizedUser;
          final completer = Completer<List<StockMovementRecord>>();
          fakeRepo.onGetStockMovements = (id) => completer.future;

          final cubit = StockMovementHistoryCubit(
            repository: fakeRepo,
            currentUser: user,
            currentUserProvider: () => user,
          );

          final future = cubit.loadHistory('item_1');
          expect(cubit.state, const StockMovementHistoryLoading('item_1'));

          // Permission is revoked in-flight
          user = unauthorizedUser;

          completer.complete([
            createSampleRecord(
              id: 'mov_1',
              itemId: 'item_1',
              delta: 100.0,
              balance: 100.0,
            ),
          ]);
          await future;

          // Must emit Restricted and NOT expose the records
          expect(cubit.state, const StockMovementHistoryRestricted('item_1'));
        },
      );
    });
  });
}
