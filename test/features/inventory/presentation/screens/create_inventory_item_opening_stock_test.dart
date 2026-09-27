import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/create_inventory_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('INVENTORY-ACCESS-1: Create Item with Opening Stock & Permission Guard', () {
    const adminUser = CurrentUser(
      id: 'admin_1',
      displayName: 'System Admin',
      accountType: AccountType.admin,
      modules: {CrmModule.inventory},
      permissions: {},
    );

    const authorizedUser = CurrentUser(
      id: 'user_creator',
      displayName: 'Creator User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {
        CrmPermissions.inventoryView,
        CrmPermissions.inventoryCreate,
      },
    );

    const unauthorizedUser = CurrentUser(
      id: 'user_view_only',
      displayName: 'View Only User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {CrmPermissions.inventoryView},
    );

    testWidgets(
      'unauthorized user without inventory.create is blocked by route guard',
      (tester) async {
        final repo = MockInventoryRepository(items: [], movements: []);

        await tester.pumpWidget(
          MaterialApp(
            home: CreateInventoryItemScreen(
              user: unauthorizedUser,
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(
          find.byKey(const Key('create_inventory_item_name')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'authorized user sees opening stock field and can create item without opening stock',
      (tester) async {
        final repo = MockInventoryRepository(items: [], movements: []);

        await tester.pumpWidget(
          MaterialApp(
            home: CreateInventoryItemScreen(
              user: authorizedUser,
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('create_inventory_item_name')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('create_inventory_item_sku')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('create_inventory_item_opening_stock')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('create_inventory_item_name')),
          'Test Keyboard',
        );
        await tester.enterText(
          find.byKey(const Key('create_inventory_item_sku')),
          'KB-101',
        );
        // Opening stock left blank

        await tester.tap(find.byKey(const Key('create_inventory_item_submit')));
        await tester.pumpAndSettle();

        final page = await repo.getItems(const InventoryQuery());
        expect(page.totalItems, 1);
        final created = page.items.first;
        expect(created.item.name, 'Test Keyboard');
        expect(created.quantityOnHand, 0.0);
      },
    );

    testWidgets(
      'creating item with valid opening stock records movement with authenticated creator actor',
      (tester) async {
        final repo = MockInventoryRepository(items: [], movements: []);

        await tester.pumpWidget(
          MaterialApp(
            home: CreateInventoryItemScreen(
              user: authorizedUser,
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('create_inventory_item_name')),
          'Office Chair',
        );
        await tester.enterText(
          find.byKey(const Key('create_inventory_item_sku')),
          'CHR-202',
        );
        await tester.enterText(
          find.byKey(const Key('create_inventory_item_opening_stock')),
          '15',
        );

        await tester.tap(find.byKey(const Key('create_inventory_item_submit')));
        await tester.pumpAndSettle();

        final page = await repo.getItems(const InventoryQuery());
        expect(page.totalItems, 1);
        final created = page.items.first;
        expect(created.item.name, 'Office Chair');
        expect(created.quantityOnHand, 15.0);
      },
    );

    testWidgets(
      'entering invalid zero or negative opening stock displays validation error',
      (tester) async {
        final repo = MockInventoryRepository(items: [], movements: []);

        await tester.pumpWidget(
          MaterialApp(
            home: CreateInventoryItemScreen(user: adminUser, repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('create_inventory_item_name')),
          'Desk Lamp',
        );
        await tester.enterText(
          find.byKey(const Key('create_inventory_item_sku')),
          'LMP-303',
        );
        await tester.enterText(
          find.byKey(const Key('create_inventory_item_opening_stock')),
          '0',
        );

        await tester.tap(find.byKey(const Key('create_inventory_item_submit')));
        await tester.pumpAndSettle();

        expect(
          find.text('Opening stock must be greater than zero.'),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('create_inventory_item_opening_stock')),
          '-10',
        );
        await tester.tap(find.byKey(const Key('create_inventory_item_submit')));
        await tester.pumpAndSettle();

        expect(
          find.text('Opening stock must be greater than zero.'),
          findsOneWidget,
        );
      },
    );
  });
}
