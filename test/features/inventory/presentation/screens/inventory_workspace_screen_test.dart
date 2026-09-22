import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_item_details_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryWorkspaceScreen Widget Tests', () {
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
      'renders title, search field, sort dropdown, and items table on desktop',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = MockInventoryRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryWorkspaceScreen(user: adminUser, repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Inventory'), findsOneWidget);
        expect(find.byKey(const Key('inventory_search_field')), findsOneWidget);
        expect(
          find.byKey(const Key('inventory_sort_dropdown')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('inventory_items_table')), findsOneWidget);
        expect(find.text('27-inch 4K Monitor'), findsOneWidget);
        expect(find.text('INV-005'), findsOneWidget);
      },
    );

    testWidgets('renders card list layout on mobile (< 600px)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockInventoryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: standardUser, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_items_list')), findsOneWidget);
      expect(find.byKey(const Key('inventory_items_table')), findsNothing);
      expect(find.text('27-inch 4K Monitor'), findsOneWidget);
      expect(find.text('SKU: INV-005'), findsOneWidget);
    });

    testWidgets('Admin sees Add Item button; Standard User does not', (
      tester,
    ) async {
      final repo = MockInventoryRepository();

      // Admin workspace
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: adminUser, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('inventory_workspace_add_item_button')),
        findsOneWidget,
      );
      expect(find.text('Add Item'), findsOneWidget);

      // Standard User workspace
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: standardUser, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('inventory_workspace_add_item_button')),
        findsNothing,
      );
      expect(find.text('Add Item'), findsNothing);
    });

    testWidgets(
      'VERIFIED NO STOCK MUTATION: delete, adjust, receive, dispatch buttons remain absent',
      (tester) async {
        final repo = MockInventoryRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryWorkspaceScreen(user: adminUser, repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Delete'), findsNothing);
        expect(find.text('Adjust Stock'), findsNothing);
        expect(find.text('Purchase'), findsNothing);
        expect(find.text('Dispatch'), findsNothing);
        expect(find.byIcon(Icons.delete), findsNothing);
      },
    );

    testWidgets('tapping an item row opens InventoryItemDetailsScreen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockInventoryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: adminUser, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('27-inch 4K Monitor'));
      await tester.pumpAndSettle();

      expect(find.byType(InventoryItemDetailsScreen), findsOneWidget);
      expect(find.text('Inventory Item Details'), findsOneWidget);
      expect(find.text('27-inch 4K Monitor'), findsOneWidget);
    });

    testWidgets('search filters list dynamically', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockInventoryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: adminUser, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('inventory_search_field')),
        'INV-002',
      );
      await tester.pumpAndSettle();

      expect(find.text('USB-C Multiport Dock'), findsOneWidget);
      expect(find.text('27-inch 4K Monitor'), findsNothing);
    });

    testWidgets(
      'displays search empty state when search returns zero results',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = MockInventoryRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryWorkspaceScreen(user: adminUser, repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('inventory_search_field')),
          'nonexistent-product-search-term',
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('inventory_search_empty_view')),
          findsOneWidget,
        );
        expect(find.text('No matching inventory items found.'), findsOneWidget);

        // Tapping clear search resets search
        await tester.tap(
          find.byKey(const Key('inventory_clear_search_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('27-inch 4K Monitor'), findsOneWidget);
      },
    );

    testWidgets('displays empty state when repository has no items', (
      tester,
    ) async {
      final repo = MockInventoryRepository(items: [], movements: []);

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: adminUser, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_empty_view')), findsOneWidget);
      expect(find.text('No inventory items found.'), findsOneWidget);
    });

    testWidgets('pagination controls allow navigating between pages', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockInventoryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryWorkspaceScreen(user: adminUser, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1–20 of 25 items'), findsOneWidget);
      expect(find.text('Page 1 of 2'), findsOneWidget);

      // Tap Next page
      await tester.tap(
        find.byKey(const Key('inventory_pagination_next_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('21–25 of 25 items'), findsOneWidget);
      expect(find.text('Page 2 of 2'), findsOneWidget);

      // Tap Previous page
      await tester.tap(
        find.byKey(const Key('inventory_pagination_previous_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('1–20 of 25 items'), findsOneWidget);
    });

    testWidgets(
      'newly created item appears after refresh when matching active query',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = MockInventoryRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryWorkspaceScreen(user: adminUser, repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('inventory_search_field')),
          'Custom Keyboard',
        );
        await tester.pumpAndSettle();

        expect(find.text('CK-999'), findsNothing);

        // Add item to repository
        await repo.createItem(
          const CreateInventoryItemInput(
            name: 'Custom Keyboard',
            sku: 'CK-999',
          ),
        );

        // Tap refresh
        await tester.tap(find.byKey(const Key('inventory_refresh_button')));
        await tester.pumpAndSettle();

        expect(find.text('CK-999'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('inventory_items_table')),
            matching: find.text('Custom Keyboard'),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
