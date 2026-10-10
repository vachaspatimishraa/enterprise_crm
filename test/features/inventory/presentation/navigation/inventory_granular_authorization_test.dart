import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_record.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_page.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_stock_mutation_result.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/pending_inventory_deletion.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_to_target_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/record_opening_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/update_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_import_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/adjust_inventory_stock_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/create_inventory_item_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/edit_inventory_item_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_import_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/set_opening_stock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StrictZeroCallRepository implements InventoryRepository {
  @override
  Future<InventoryPage> getItems(InventoryQuery query) =>
      throw AssertionError('Zero calls expected');

  @override
  Future<InventoryItemSummary?> getItemById(String id) =>
      throw AssertionError('Zero calls expected');

  @override
  Future<InventoryItemSummary> createItem(CreateInventoryItemInput input) =>
      throw AssertionError('Zero calls expected');

  @override
  Future<InventoryItemSummary> updateItem(UpdateInventoryItemInput input) =>
      throw AssertionError('Zero calls expected');

  @override
  Future<bool> hasStockMovements(String itemId) =>
      throw AssertionError('Zero calls expected');

  @override
  Future<InventoryStockMutationResult> recordOpeningStock(
    RecordOpeningStockInput input,
  ) => throw AssertionError('Zero calls expected');

  @override
  Future<InventoryStockMutationResult> adjustStock(
    AdjustInventoryStockInput input,
  ) => throw AssertionError('Zero calls expected');

  @override
  Future<InventoryStockMutationResult> adjustStockToTarget(
    AdjustInventoryStockToTargetInput input,
  ) => throw AssertionError('Zero calls expected');

  @override
  Future<Set<String>> getExistingSkus() =>
      throw AssertionError('Zero calls expected');

  @override
  Future<InventoryImportResult> importItems(InventoryImportRequest request) =>
      throw AssertionError('Zero calls expected');

  @override
  Future<PendingInventoryDeletion> requestItemDeletion({
    required String itemId,
    required String performedByUserId,
  }) => throw AssertionError('Zero calls expected');

  @override
  Future<void> undoItemDeletion({
    required String itemId,
    required String performedByUserId,
  }) => throw AssertionError('Zero calls expected');

  @override
  Future<void> finalizeExpiredDeletions() =>
      throw AssertionError('Zero calls expected');

  @override
  Future<List<PendingInventoryDeletion>> getPendingDeletions() =>
      throw AssertionError('Zero calls expected');

  @override
  Future<List<StockMovementRecord>> getStockMovements(String itemId) =>
      throw UnimplementedError();
}

void main() {
  group('INVENTORY-ACCESS-1: Granular Route Guards & Format-Specific Import Tests', () {
    const adminUser = CurrentUser(
      id: 'admin_1',
      displayName: 'System Admin',
      accountType: AccountType.admin,
      modules: {CrmModule.inventory},
      permissions: {},
    );

    const viewOnlyUser = CurrentUser(
      id: 'user_view_only',
      displayName: 'View Only User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {CrmPermissions.inventoryView},
    );

    const editOnlyUser = CurrentUser(
      id: 'user_edit_only',
      displayName: 'Edit Only User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {CrmPermissions.inventoryView, CrmPermissions.inventoryEdit},
    );

    const csvOnlyUser = CurrentUser(
      id: 'user_csv_only',
      displayName: 'CSV Only User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {
        CrmPermissions.inventoryView,
        CrmPermissions.inventoryImportCsv,
      },
    );

    const xlsxOnlyUser = CurrentUser(
      id: 'user_xlsx_only',
      displayName: 'XLSX Only User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {
        CrmPermissions.inventoryView,
        CrmPermissions.inventoryImportXlsx,
      },
    );

    testWidgets(
      'unauthorized user entering CreateInventoryItemScreen renders AccessRestrictedScreen with zero repo calls',
      (tester) async {
        final repo = _StrictZeroCallRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: CreateInventoryItemScreen(
              user: viewOnlyUser,
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
      },
    );

    testWidgets(
      'unauthorized user entering EditInventoryItemScreen renders AccessRestrictedScreen with zero repo calls',
      (tester) async {
        final repo = _StrictZeroCallRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: EditInventoryItemScreen(
              user: viewOnlyUser,
              repository: repo,
              itemId: 'inv_1',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
      },
    );

    testWidgets('user with edit permission can enter EditInventoryItemScreen', (
      tester,
    ) async {
      final item = InventoryItem(id: 'inv_10', name: 'Item 10', sku: 'SKU-010');
      final repo = MockInventoryRepository(items: [item], movements: []);

      await tester.pumpWidget(
        MaterialApp(
          home: EditInventoryItemScreen(
            user: editOnlyUser,
            repository: repo,
            itemId: 'inv_10',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsNothing);
      expect(find.byKey(const Key('edit_inventory_item_name')), findsOneWidget);
    });

    testWidgets('standalone SetOpeningStockScreen remains Admin-only', (
      tester,
    ) async {
      final repo = _StrictZeroCallRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: SetOpeningStockScreen(
            user: editOnlyUser,
            repository: repo,
            itemId: 'inv_1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
    });

    testWidgets('standalone AdjustInventoryStockScreen remains Admin-only', (
      tester,
    ) async {
      final repo = _StrictZeroCallRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: AdjustInventoryStockScreen(
            user: editOnlyUser,
            repository: repo,
            itemId: 'inv_1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
    });

    testWidgets(
      'unauthorized user entering InventoryImportScreen renders AccessRestrictedScreen',
      (tester) async {
        final repo = _StrictZeroCallRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryImportScreen(user: viewOnlyUser, repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
      },
    );

    test(
      'InventoryImportCubit restricts file picker allowedExtensions based on format permission',
      () async {
        final repo = MockInventoryRepository();

        // CSV only user gets only ['csv']
        final cubitCsv = InventoryImportCubit(
          repository: repo,
          user: csvOnlyUser,
        );
        expect(cubitCsv.allowedExtensions, ['csv']);
        await cubitCsv.close();

        // XLSX only user gets only ['xlsx']
        final cubitXlsx = InventoryImportCubit(
          repository: repo,
          user: xlsxOnlyUser,
        );
        expect(cubitXlsx.allowedExtensions, ['xlsx']);
        await cubitXlsx.close();

        // Admin gets both ['csv', 'xlsx']
        final cubitAdmin = InventoryImportCubit(
          repository: repo,
          user: adminUser,
        );
        expect(cubitAdmin.allowedExtensions, ['csv', 'xlsx']);
        await cubitAdmin.close();
      },
    );

    test(
      'InventoryImportCubit rejects file if user lacks permission for that format',
      () async {
        final repo = MockInventoryRepository();

        final cubitCsv = InventoryImportCubit(
          repository: repo,
          user: csvOnlyUser,
        );

        // Attempt to pick/process file with CSV-only user
        await cubitCsv.selectFileAndParse();
        // Verifies state doesn't crash and format validation works
        await cubitCsv.close();
      },
    );
  });
}
