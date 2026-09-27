import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_item_details_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'INVENTORY-ACCESS-1: Deletion Confirmation, Pending State, and Undo UI Tests',
    () {
      const adminUser = CurrentUser(
        id: 'admin_1',
        displayName: 'System Admin',
        accountType: AccountType.admin,
        modules: {CrmModule.inventory},
        permissions: {},
      );

      const authorizedDeleteUser = CurrentUser(
        id: 'user_delete_1',
        displayName: 'Delete User',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryDelete,
        },
      );

      const viewOnlyUser = CurrentUser(
        id: 'user_view_only',
        displayName: 'View Only User',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {CrmPermissions.inventoryView},
      );

      testWidgets(
        'unauthorized user does not see delete button on details screen',
        (tester) async {
          final item = InventoryItem(
            id: 'inv_1',
            name: 'Item 1',
            sku: 'SKU-001',
          );
          final repo = MockInventoryRepository(items: [item], movements: []);

          await tester.pumpWidget(
            MaterialApp(
              home: InventoryItemDetailsScreen(
                user: viewOnlyUser,
                repository: repo,
                itemId: 'inv_1',
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('inventory_details_delete_button')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'authorized user sees delete button and exact SKU confirmation dialog controls confirm button',
        (tester) async {
          final item = InventoryItem(
            id: 'inv_2',
            name: 'Item 2',
            sku: 'SKU-002',
          );
          final repo = MockInventoryRepository(items: [item], movements: []);

          await tester.pumpWidget(
            MaterialApp(
              home: InventoryItemDetailsScreen(
                user: authorizedDeleteUser,
                repository: repo,
                itemId: 'inv_2',
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('inventory_details_delete_button')),
            findsOneWidget,
          );

          await tester.tap(
            find.byKey(const Key('inventory_details_delete_button')),
          );
          await tester.pumpAndSettle();

          // Confirmation dialog is shown
          expect(find.text('Delete Inventory Item'), findsOneWidget);
          expect(
            find.byKey(const Key('delete_inventory_item_sku_input')),
            findsOneWidget,
          );

          // Confirm button is initially disabled
          final confirmFinder = find.byKey(
            const Key('delete_inventory_item_confirm_button'),
          );
          expect(confirmFinder, findsOneWidget);
          final FilledButton confirmButton = tester.widget(confirmFinder);
          expect(confirmButton.onPressed, isNull);

          // Entering mismatched SKU keeps confirm button disabled
          await tester.enterText(
            find.byKey(const Key('delete_inventory_item_sku_input')),
            'WRONG-SKU',
          );
          await tester.pumpAndSettle();
          final FilledButton confirmButton2 = tester.widget(confirmFinder);
          expect(confirmButton2.onPressed, isNull);

          // Entering exact SKU enables confirm button
          await tester.enterText(
            find.byKey(const Key('delete_inventory_item_sku_input')),
            'SKU-002',
          );
          await tester.pumpAndSettle();
          final FilledButton confirmButton3 = tester.widget(confirmFinder);
          expect(confirmButton3.onPressed, isNotNull);

          // Confirm deletion
          await tester.tap(confirmFinder);
          await tester.pumpAndSettle();

          // Item is now pending deletion and details displays pending deletion banner with Undo
          expect(
            find.byKey(const Key('inventory_details_pending_deletion_banner')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('inventory_details_undo_delete_button')),
            findsOneWidget,
          );

          // Normal mutation buttons are disabled / not available while pending
          expect(
            find.byKey(const Key('inventory_details_set_opening_stock_button')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('inventory_details_adjust_stock_button')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'tapping Undo restores normal item status on details screen',
        (tester) async {
          final item = InventoryItem(
            id: 'inv_3',
            name: 'Item 3',
            sku: 'SKU-003',
          );
          final repo = MockInventoryRepository(items: [item], movements: []);

          await repo.requestItemDeletion(
            itemId: 'inv_3',
            performedByUserId: adminUser.id,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: InventoryItemDetailsScreen(
                user: adminUser,
                repository: repo,
                itemId: 'inv_3',
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('inventory_details_pending_deletion_banner')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('inventory_details_undo_delete_button')),
            findsOneWidget,
          );

          // Tap Undo
          await tester.tap(
            find.byKey(const Key('inventory_details_undo_delete_button')),
          );
          await tester.pumpAndSettle();

          // Pending banner disappears, normal state restored
          expect(
            find.byKey(const Key('inventory_details_pending_deletion_banner')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'workspace displays pending deletions banner and allows undo',
        (tester) async {
          final item = InventoryItem(
            id: 'inv_4',
            name: 'Pending Item 4',
            sku: 'SKU-004',
          );
          final movement = StockMovement(
            id: 'mov_4',
            inventoryItemId: 'inv_4',
            type: StockMovementType.openingStock,
            quantityDelta: 10.0,
            createdAt: DateTime.utc(2026, 9, 27),
            performedByUserId: adminUser.id,
          );
          final repo = MockInventoryRepository(
            items: [item],
            movements: [movement],
          );

          await repo.requestItemDeletion(
            itemId: 'inv_4',
            performedByUserId: adminUser.id,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: InventoryWorkspaceScreen(user: adminUser, repository: repo),
            ),
          );
          await tester.pumpAndSettle();

          // Pending deletions banner is visible
          expect(
            find.byKey(
              const Key('inventory_workspace_pending_deletions_banner'),
            ),
            findsOneWidget,
          );
          expect(find.textContaining('Pending Item 4'), findsOneWidget);

          final undoButtonFinder = find.byKey(
            const Key('pending_deletion_undo_button_inv_4'),
          );
          expect(undoButtonFinder, findsOneWidget);

          // Tap Undo in workspace
          await tester.tap(undoButtonFinder);
          await tester.pumpAndSettle();

          // Item is restored to active items list and banner disappears
          expect(
            find.byKey(
              const Key('inventory_workspace_pending_deletions_banner'),
            ),
            findsNothing,
          );
          expect(find.text('Pending Item 4'), findsOneWidget);
        },
      );
    },
  );
}
