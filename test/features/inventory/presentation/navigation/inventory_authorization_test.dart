import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_page.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/update_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_stock_mutation_result.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/record_opening_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/adjust_inventory_stock_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/create_inventory_item_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/edit_inventory_item_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_item_details_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_workspace_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/set_opening_stock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpyInventoryRepository implements InventoryRepository {
  int getItemsCallCount = 0;
  int getItemByIdCallCount = 0;
  int createItemCallCount = 0;
  int updateItemCallCount = 0;
  int hasStockMovementsCallCount = 0;
  int recordOpeningStockCallCount = 0;
  int adjustStockCallCount = 0;

  @override
  Future<InventoryPage> getItems(InventoryQuery query) async {
    getItemsCallCount++;
    return const InventoryPage(
      items: [],
      currentPage: 1,
      pageSize: 20,
      totalItems: 0,
      hasNext: false,
    );
  }

  @override
  Future<InventoryItemSummary?> getItemById(String id) async {
    getItemByIdCallCount++;
    return null;
  }

  @override
  Future<InventoryItemSummary> createItem(
    CreateInventoryItemInput input,
  ) async {
    createItemCallCount++;
    throw UnimplementedError();
  }

  @override
  Future<InventoryItemSummary> updateItem(
    UpdateInventoryItemInput input,
  ) async {
    updateItemCallCount++;
    throw UnimplementedError();
  }

  @override
  Future<bool> hasStockMovements(String itemId) async {
    hasStockMovementsCallCount++;
    return false;
  }

  @override
  Future<InventoryStockMutationResult> recordOpeningStock(
    RecordOpeningStockInput input,
  ) async {
    recordOpeningStockCallCount++;
    throw UnimplementedError();
  }

  @override
  Future<InventoryStockMutationResult> adjustStock(
    AdjustInventoryStockInput input,
  ) async {
    adjustStockCallCount++;
    throw UnimplementedError();
  }
}

void main() {
  group('Inventory Module Authorization & Pre-Cubit Security Guard Tests', () {
    testWidgets(
      'Admin user accesses Inventory workspace and details unconditionally',
      (tester) async {
        final adminUser = CurrentUser(
          id: 'admin_1',
          displayName: 'Administrator',
          accountType: AccountType.admin,
          modules:
              {}, // Empty modules, but Admin accountType gives access via AccessPolicy
          permissions: {},
        );

        final repo = MockInventoryRepository();

        // Workspace check
        await tester.pumpWidget(
          MaterialApp(
            home: InventoryWorkspaceScreen(user: adminUser, repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsNothing);
        expect(find.text('Inventory'), findsOneWidget);

        // Details check
        await tester.pumpWidget(
          MaterialApp(
            home: InventoryItemDetailsScreen(
              user: adminUser,
              repository: repo,
              itemId: 'item_001',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsNothing);
        expect(find.text('Inventory Item Details'), findsOneWidget);
      },
    );

    testWidgets(
      'Standard user with Inventory module and inventory.view permission accesses workspace',
      (tester) async {
        final authorizedUser = CurrentUser(
          id: 'user_1',
          displayName: 'Inventory Manager',
          accountType: AccountType.user,
          modules: {CrmModule.inventory},
          permissions: {CrmPermissions.inventoryView},
        );

        final repo = MockInventoryRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryWorkspaceScreen(
              user: authorizedUser,
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsNothing);
        expect(find.text('Inventory'), findsOneWidget);
      },
    );

    testWidgets(
      'Standard user lacking Inventory module is blocked with 0 repository calls',
      (tester) async {
        final userWithoutModule = CurrentUser(
          id: 'user_2',
          displayName: 'Sales Rep',
          accountType: AccountType.user,
          modules: {CrmModule.leadManagement},
          permissions: {
            CrmPermissions.inventoryView,
          }, // Has permission string, but NOT the module
        );

        final spyRepo = _SpyInventoryRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryWorkspaceScreen(
              user: userWithoutModule,
              repository: spyRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pre-Cubit guard fires: shows AccessRestrictedScreen
        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.text('Inventory'), findsNothing);

        // ZERO calls made to repository
        expect(spyRepo.getItemsCallCount, 0);
        expect(spyRepo.getItemByIdCallCount, 0);
      },
    );

    testWidgets(
      'Standard user lacking inventory.view permission is blocked with 0 repository calls',
      (tester) async {
        final userWithoutPermission = CurrentUser(
          id: 'user_3',
          displayName: 'Junior Staff',
          accountType: AccountType.user,
          modules: {CrmModule.inventory},
          permissions: {}, // Module assigned, but lacks inventory.view
        );

        final spyRepo = _SpyInventoryRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryWorkspaceScreen(
              user: userWithoutPermission,
              repository: spyRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.text('Inventory'), findsNothing);
        expect(spyRepo.getItemsCallCount, 0);
        expect(spyRepo.getItemByIdCallCount, 0);
      },
    );

    testWidgets(
      'Details screen blocks unauthorized user with 0 repository calls',
      (tester) async {
        final unauthorizedUser = CurrentUser(
          id: 'user_4',
          displayName: 'Unauthorized User',
          accountType: AccountType.user,
          modules: {},
          permissions: {},
        );

        final spyRepo = _SpyInventoryRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryItemDetailsScreen(
              user: unauthorizedUser,
              repository: spyRepo,
              itemId: 'item_001',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.text('Inventory Item Details'), findsNothing);
        expect(spyRepo.getItemByIdCallCount, 0);
      },
    );

    group('Full Matrix Authorization Tests (Section 43)', () {
      final admin = CurrentUser(
        id: 'admin_full',
        displayName: 'Admin User',
        accountType: AccountType.admin,
        modules: {CrmModule.inventory},
        permissions: {CrmPermissions.inventoryView},
      );

      final userWithView = CurrentUser(
        id: 'user_view',
        displayName: 'Standard User with View',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {CrmPermissions.inventoryView},
      );

      final userMissingView = CurrentUser(
        id: 'user_no_view',
        displayName: 'Standard User missing View',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {},
      );

      final userWithoutModule = CurrentUser(
        id: 'user_no_module',
        displayName: 'User without Inventory',
        accountType: AccountType.user,
        modules: {CrmModule.leadManagement},
        permissions: {CrmPermissions.inventoryView},
      );

      testWidgets(
        'Admin: Workspace allowed, Details allowed, Create allowed, Edit allowed',
        (tester) async {
          final repo = MockInventoryRepository();

          // Workspace
          await tester.pumpWidget(
            MaterialApp(
              home: InventoryWorkspaceScreen(user: admin, repository: repo),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsNothing);
          expect(find.text('Inventory'), findsOneWidget);

          // Details
          await tester.pumpWidget(
            MaterialApp(
              home: InventoryItemDetailsScreen(
                user: admin,
                repository: repo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsNothing);
          expect(find.text('Inventory Item Details'), findsOneWidget);

          // Create
          await tester.pumpWidget(
            MaterialApp(
              home: CreateInventoryItemScreen(user: admin, repository: repo),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsNothing);
          expect(find.text('Add Inventory Item'), findsOneWidget);

          // Edit
          await tester.pumpWidget(
            MaterialApp(
              home: EditInventoryItemScreen(
                user: admin,
                repository: repo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsNothing);
          expect(find.text('Edit Inventory Item'), findsOneWidget);

          // Set Opening Stock
          await tester.pumpWidget(
            MaterialApp(
              home: SetOpeningStockScreen(
                user: admin,
                repository: repo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsNothing);
          expect(
            find.widgetWithText(AppBar, 'Set Opening Stock'),
            findsOneWidget,
          );

          // Adjust Stock
          await tester.pumpWidget(
            MaterialApp(
              home: AdjustInventoryStockScreen(
                user: admin,
                repository: repo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsNothing);
          expect(find.widgetWithText(AppBar, 'Adjust Stock'), findsOneWidget);
        },
      );

      testWidgets(
        'User with Inventory + inventory.view: Workspace allowed, Details allowed, Create denied, Edit denied, Stock mutation denied with 0 writes',
        (tester) async {
          final spyRepo = _SpyInventoryRepository();

          // Workspace allowed
          await tester.pumpWidget(
            MaterialApp(
              home: InventoryWorkspaceScreen(
                user: userWithView,
                repository: spyRepo,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsNothing);
          expect(find.text('Inventory'), findsOneWidget);

          // Details allowed
          await tester.pumpWidget(
            MaterialApp(
              home: InventoryItemDetailsScreen(
                user: userWithView,
                repository: spyRepo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsNothing);

          // Create denied
          await tester.pumpWidget(
            MaterialApp(
              home: CreateInventoryItemScreen(
                user: userWithView,
                repository: spyRepo,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);
          expect(spyRepo.createItemCallCount, 0);

          // Edit denied
          await tester.pumpWidget(
            MaterialApp(
              home: EditInventoryItemScreen(
                user: userWithView,
                repository: spyRepo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);
          expect(spyRepo.updateItemCallCount, 0);

          // Set Opening Stock denied
          await tester.pumpWidget(
            MaterialApp(
              home: SetOpeningStockScreen(
                user: userWithView,
                repository: spyRepo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);
          expect(spyRepo.recordOpeningStockCallCount, 0);

          // Adjust Stock denied
          await tester.pumpWidget(
            MaterialApp(
              home: AdjustInventoryStockScreen(
                user: userWithView,
                repository: spyRepo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);
          expect(spyRepo.adjustStockCallCount, 0);
        },
      );

      testWidgets(
        'User missing inventory.view: all routes denied with 0 writes',
        (tester) async {
          final spyRepo = _SpyInventoryRepository();

          // Workspace denied
          await tester.pumpWidget(
            MaterialApp(
              home: InventoryWorkspaceScreen(
                user: userMissingView,
                repository: spyRepo,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);

          // Details denied
          await tester.pumpWidget(
            MaterialApp(
              home: InventoryItemDetailsScreen(
                user: userMissingView,
                repository: spyRepo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);

          // Create denied
          await tester.pumpWidget(
            MaterialApp(
              home: CreateInventoryItemScreen(
                user: userMissingView,
                repository: spyRepo,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);
          expect(spyRepo.createItemCallCount, 0);

          // Edit denied
          await tester.pumpWidget(
            MaterialApp(
              home: EditInventoryItemScreen(
                user: userMissingView,
                repository: spyRepo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);
          expect(spyRepo.updateItemCallCount, 0);

          // Set Opening Stock denied
          await tester.pumpWidget(
            MaterialApp(
              home: SetOpeningStockScreen(
                user: userMissingView,
                repository: spyRepo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);
          expect(spyRepo.recordOpeningStockCallCount, 0);

          // Adjust Stock denied
          await tester.pumpWidget(
            MaterialApp(
              home: AdjustInventoryStockScreen(
                user: userMissingView,
                repository: spyRepo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);
          expect(spyRepo.adjustStockCallCount, 0);
        },
      );

      testWidgets(
        'User without Inventory module: all routes denied with 0 writes',
        (tester) async {
          final spyRepo = _SpyInventoryRepository();

          // Workspace denied
          await tester.pumpWidget(
            MaterialApp(
              home: InventoryWorkspaceScreen(
                user: userWithoutModule,
                repository: spyRepo,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);

          // Details denied
          await tester.pumpWidget(
            MaterialApp(
              home: InventoryItemDetailsScreen(
                user: userWithoutModule,
                repository: spyRepo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);

          // Create denied
          await tester.pumpWidget(
            MaterialApp(
              home: CreateInventoryItemScreen(
                user: userWithoutModule,
                repository: spyRepo,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);
          expect(spyRepo.createItemCallCount, 0);

          // Edit denied
          await tester.pumpWidget(
            MaterialApp(
              home: EditInventoryItemScreen(
                user: userWithoutModule,
                repository: spyRepo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);
          expect(spyRepo.updateItemCallCount, 0);

          // Set Opening Stock denied
          await tester.pumpWidget(
            MaterialApp(
              home: SetOpeningStockScreen(
                user: userWithoutModule,
                repository: spyRepo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);
          expect(spyRepo.recordOpeningStockCallCount, 0);

          // Adjust Stock denied
          await tester.pumpWidget(
            MaterialApp(
              home: AdjustInventoryStockScreen(
                user: userWithoutModule,
                repository: spyRepo,
                itemId: 'item_001',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessRestrictedScreen), findsOneWidget);
          expect(spyRepo.adjustStockCallCount, 0);
        },
      );
    });
  });
}
