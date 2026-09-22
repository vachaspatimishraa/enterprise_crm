import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/update_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_item_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryItemDetailsScreen Widget Tests', () {
    final adminUser = CurrentUser(
      id: 'usr_admin',
      displayName: 'Admin User',
      accountType: AccountType.admin,
      modules: {CrmModule.inventory},
      permissions: {CrmPermissions.inventoryView},
    );

    final standardUser = CurrentUser(
      id: 'usr_standard',
      displayName: 'Standard User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {CrmPermissions.inventoryView},
    );

    testWidgets(
      'renders item details card with Name, SKU, and derived Quantity',
      (tester) async {
        final repo = MockInventoryRepository();

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

        expect(find.text('Inventory Item Details'), findsOneWidget);
        expect(
          find.byKey(const Key('inventory_item_details_card')),
          findsOneWidget,
        );
        expect(find.text('Laptop Stand'), findsOneWidget);
        expect(find.text('SKU: INV-001'), findsOneWidget);
        expect(find.text('25'), findsOneWidget);
      },
    );

    testWidgets('zero-stock item renders quantity 0 cleanly', (tester) async {
      final repo = MockInventoryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryItemDetailsScreen(
            user: adminUser,
            repository: repo,
            itemId: 'item_003', // seeded with 0 delta
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wireless Mechanical Keyboard'), findsOneWidget);
      expect(find.text('SKU: INV-003'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('Admin sees Edit Item button; Standard User does not', (
      tester,
    ) async {
      final repo = MockInventoryRepository();

      // Admin details screen
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

      expect(
        find.byKey(const Key('inventory_details_edit_button')),
        findsOneWidget,
      );
      expect(find.text('Edit Item'), findsOneWidget);

      // Standard User details screen
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryItemDetailsScreen(
            user: standardUser,
            repository: repo,
            itemId: 'item_001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('inventory_details_edit_button')),
        findsNothing,
      );
      expect(find.text('Edit Item'), findsNothing);
    });

    testWidgets(
      'shows updated name and SKU while preserving derived quantity',
      (tester) async {
        final repo = MockInventoryRepository();

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

        expect(find.text('Laptop Stand'), findsOneWidget);
        expect(find.text('SKU: INV-001'), findsOneWidget);
        expect(find.text('25'), findsOneWidget);

        // Update item in repository
        await repo.updateItem(
          const UpdateInventoryItemInput(
            id: 'item_001',
            name: 'Laptop Stand Ultra Pro',
            sku: 'INV-001-PRO',
          ),
        );

        // Freshly re-load details screen
        await tester.pumpWidget(const SizedBox.shrink());
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

        expect(find.text('Laptop Stand Ultra Pro'), findsOneWidget);
        expect(find.text('SKU: INV-001-PRO'), findsOneWidget);
        expect(find.text('25'), findsOneWidget); // Quantity preserved!
      },
    );

    testWidgets(
      'Admin + uninitialized item: Edit Item and Set Opening Stock visible; Adjust Stock hidden',
      (tester) async {
        final repo = MockInventoryRepository();
        final newItem = await repo.createItem(
          const CreateInventoryItemInput(
            name: 'Freshly Created Item',
            sku: 'FRESH-001',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryItemDetailsScreen(
              user: adminUser,
              repository: repo,
              itemId: newItem.item.id,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('inventory_details_edit_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('inventory_details_set_opening_stock_button')),
          findsOneWidget,
        );
        expect(find.text('Set Opening Stock'), findsOneWidget);
        expect(
          find.byKey(const Key('inventory_details_adjust_stock_button')),
          findsNothing,
        );
        expect(find.text('Adjust Stock'), findsNothing);
      },
    );

    testWidgets(
      'Admin + initialized item: Edit Item and Adjust Stock visible; Set Opening Stock hidden',
      (tester) async {
        final repo = MockInventoryRepository();

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

        expect(
          find.byKey(const Key('inventory_details_edit_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('inventory_details_adjust_stock_button')),
          findsOneWidget,
        );
        expect(find.text('Adjust Stock'), findsOneWidget);
        expect(
          find.byKey(const Key('inventory_details_set_opening_stock_button')),
          findsNothing,
        );
        expect(find.text('Set Opening Stock'), findsNothing);
      },
    );

    testWidgets(
      'CRITICAL: initialized zero-stock item shows Adjust Stock, NOT Opening Stock (history-based)',
      (tester) async {
        final repo = MockInventoryRepository();

        // item_003 has quantity = 0, but has movement history
        await tester.pumpWidget(
          MaterialApp(
            home: InventoryItemDetailsScreen(
              user: adminUser,
              repository: repo,
              itemId: 'item_003',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('0'), findsOneWidget);
        expect(
          find.byKey(const Key('inventory_details_adjust_stock_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('inventory_details_set_opening_stock_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Standard User: all write buttons hidden (Edit, Opening Stock, Adjust)',
      (tester) async {
        final repo = MockInventoryRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryItemDetailsScreen(
              user: standardUser,
              repository: repo,
              itemId: 'item_001',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('inventory_details_edit_button')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('inventory_details_set_opening_stock_button')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('inventory_details_adjust_stock_button')),
          findsNothing,
        );
        expect(find.text('Edit Item'), findsNothing);
        expect(find.text('Set Opening Stock'), findsNothing);
        expect(find.text('Adjust Stock'), findsNothing);
      },
    );

    testWidgets(
      'DEFERRED: zero delete, purchase, dispatch, or history controls on details screen',
      (tester) async {
        final repo = MockInventoryRepository();

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

        expect(find.text('Delete'), findsNothing);
        expect(find.text('Purchase'), findsNothing);
        expect(find.text('Dispatch'), findsNothing);
        expect(find.text('History'), findsNothing);
        expect(find.text('Stock History'), findsNothing);
        expect(find.byIcon(Icons.delete), findsNothing);
      },
    );

    testWidgets('item not found shows not-found state with back action', (
      tester,
    ) async {
      final repo = MockInventoryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryItemDetailsScreen(
            user: adminUser,
            repository: repo,
            itemId: 'non_existent_item_id',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_item_not_found')), findsOneWidget);
      expect(find.text('Item not found'), findsOneWidget);
      expect(find.text('Back to Inventory'), findsOneWidget);
    });
  });
}
