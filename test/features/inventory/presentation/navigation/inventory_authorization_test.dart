import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_page.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_item_details_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpyInventoryRepository implements InventoryRepository {
  int getItemsCallCount = 0;
  int getItemByIdCallCount = 0;

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
  });
}
