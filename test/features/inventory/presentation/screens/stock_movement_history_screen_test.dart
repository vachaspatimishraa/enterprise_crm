import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_record.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_item_details_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/stock_movement_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingInventoryRepository extends MockInventoryRepository {
  bool shouldFail;
  _FailingInventoryRepository({
    required this.shouldFail,
    super.items,
    super.movements,
  });

  @override
  Future<List<StockMovementRecord>> getStockMovements(String itemId) async {
    if (shouldFail) {
      throw Exception('Database disk error');
    }
    return super.getStockMovements(itemId);
  }
}

void main() {
  group('StockMovementHistoryScreen Widget Tests', () {
    final adminUser = CurrentUser(
      id: 'usr_admin',
      displayName: 'Admin User',
      accountType: AccountType.admin,
      modules: {CrmModule.inventory},
      permissions: {
        CrmPermissions.inventoryView,
        CrmPermissions.inventoryStockManage,
      },
    );

    final authorizedViewer = CurrentUser(
      id: 'usr_viewer',
      displayName: 'Viewer User',
      accountType: AccountType.user,
      modules: {CrmModule.inventory},
      permissions: {CrmPermissions.inventoryView},
    );

    final unauthorizedUser = CurrentUser(
      id: 'usr_unauth',
      displayName: 'Unauthorized User',
      accountType: AccountType.user,
      modules: {},
      permissions: {},
    );

    testWidgets('unauthorized user receives AccessRestrictedScreen via pre-guard', (tester) async {
      final repo = MockInventoryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: StockMovementHistoryScreen(
            user: unauthorizedUser,
            repository: repo,
            itemId: 'item_001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
      expect(find.byType(StockMovementHistoryScreen), findsOneWidget);
      expect(find.text('Stock History'), findsNothing);
    });

    testWidgets('authorized viewer can inspect history and renders items newest-first', (tester) async {
      final item = InventoryItem(id: 'item_test', name: 'Widget Pro', sku: 'WP-100');
      final movements = [
        StockMovement(
          id: 'mov_1',
          inventoryItemId: 'item_test',
          type: StockMovementType.openingStock,
          quantityDelta: 50.0,
          createdAt: DateTime.utc(2026, 1, 1, 10, 0),
          performedByUserId: null,
          reason: null,
        ),
        StockMovement(
          id: 'mov_2',
          inventoryItemId: 'item_test',
          type: StockMovementType.adjustment,
          quantityDelta: -15.0,
          createdAt: DateTime.utc(2026, 1, 2, 14, 30),
          performedByUserId: 'usr_admin',
          reason: 'Physical count adjustment',
        ),
      ];

      final repo = MockInventoryRepository(
        items: [item],
        movements: movements,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StockMovementHistoryScreen(
            user: authorizedViewer,
            repository: repo,
            itemId: 'item_test',
          ),
        ),
      );

      // Loading state visible initially
      expect(find.byKey(const Key('stock_history_loading_indicator')), findsOneWidget);

      await tester.pumpAndSettle();

      // Header card
      expect(find.byKey(const Key('stock_history_header_card')), findsOneWidget);
      expect(find.text('Widget Pro'), findsOneWidget);
      expect(find.text('SKU: WP-100'), findsOneWidget);
      // Authoritative derived current balance: 50 - 15 = 35
      expect(find.byKey(const Key('stock_history_item_current_quantity')), findsOneWidget);
      expect(find.text('35'), findsOneWidget);

      // List of movements (newest first: mov_2 then mov_1)
      expect(find.byKey(const Key('stock_history_list')), findsOneWidget);
      expect(find.byKey(const Key('stock_movement_card_mov_2')), findsOneWidget);
      expect(find.byKey(const Key('stock_movement_card_mov_1')), findsOneWidget);

      // Verify mov_2 (Adjustment)
      expect(find.byKey(const Key('movement_type_mov_2')), findsOneWidget);
      expect(find.text('Adjustment'), findsOneWidget);
      expect(find.text('-15'), findsOneWidget);
      expect(find.text('Balance: 35'), findsOneWidget);
      expect(find.text('usr_admin'), findsOneWidget);
      expect(find.text('Physical count adjustment'), findsOneWidget);

      // Verify mov_1 (Opening Stock, null actor, null reason)
      expect(find.byKey(const Key('movement_type_mov_1')), findsOneWidget);
      expect(find.text('Opening Stock'), findsOneWidget);
      expect(find.text('+50'), findsOneWidget);
      expect(find.text('Balance: 50'), findsOneWidget);
      expect(find.text('Not recorded'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('empty state displays clean guidance and zero balance in header', (tester) async {
      final item = InventoryItem(id: 'item_empty', name: 'Zero Stock Item', sku: 'ZSI-000');
      final repo = MockInventoryRepository(items: [item], movements: []);

      await tester.pumpWidget(
        MaterialApp(
          home: StockMovementHistoryScreen(
            user: adminUser,
            repository: repo,
            itemId: 'item_empty',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stock_history_header_card')), findsOneWidget);
      expect(find.text('Zero Stock Item'), findsOneWidget);
      expect(find.text('SKU: ZSI-000'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);

      expect(find.byKey(const Key('stock_history_empty_view')), findsOneWidget);
      expect(find.text('No stock movements recorded yet.'), findsOneWidget);
    });

    testWidgets('not found state displays informative view and back button pops navigator', (tester) async {
      final repo = MockInventoryRepository(items: [], movements: []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open_history'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StockMovementHistoryScreen(
                      user: adminUser,
                      repository: repo,
                      itemId: 'non_existent_id',
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_history')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stock_history_not_found_view')), findsOneWidget);
      expect(find.text('Item not found'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byKey(const Key('stock_history_not_found_back_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stock_history_not_found_view')), findsNothing);
      expect(find.byKey(const Key('open_history')), findsOneWidget);
    });

    testWidgets('failure state displays error message and retry button functions', (tester) async {
      final repo = _FailingInventoryRepository(
        shouldFail: true,
        items: [InventoryItem(id: 'item_fail', name: 'Faulty Item', sku: 'FLT-001')],
        movements: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StockMovementHistoryScreen(
            user: adminUser,
            repository: repo,
            itemId: 'item_fail',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stock_history_failure_view')), findsOneWidget);
      expect(find.byKey(const Key('stock_history_retry_button')), findsOneWidget);

      // Now disable failure simulation and retry
      repo.shouldFail = false;
      await tester.tap(find.byKey(const Key('stock_history_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stock_history_failure_view')), findsNothing);
      expect(find.byKey(const Key('stock_history_empty_view')), findsOneWidget);
    });

    testWidgets('navigating from InventoryItemDetailsScreen opens StockMovementHistoryScreen', (tester) async {
      final repo = MockInventoryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryItemDetailsScreen(
            user: authorizedViewer,
            repository: repo,
            itemId: 'item_001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check both navigation entry points exist on details screen
      expect(find.byKey(const Key('inventory_details_stock_history_button')), findsOneWidget);
      expect(find.byKey(const Key('inventory_details_view_history_button')), findsOneWidget);

      // Tap AppBar history button
      await tester.tap(find.byKey(const Key('inventory_details_stock_history_button')));
      await tester.pumpAndSettle();

      // History screen is now visible
      expect(find.byType(StockMovementHistoryScreen), findsOneWidget);
      expect(find.text('Stock History'), findsOneWidget);
      expect(find.text('Laptop Stand'), findsOneWidget);
      expect(find.text('SKU: INV-001'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byKey(const Key('stock_history_back_button')));
      await tester.pumpAndSettle();

      // Back to details
      expect(find.byType(StockMovementHistoryScreen), findsNothing);
      expect(find.byType(InventoryItemDetailsScreen), findsOneWidget);

      // Tap view history button in details card
      await tester.tap(find.byKey(const Key('inventory_details_view_history_button')));
      await tester.pumpAndSettle();

      expect(find.byType(StockMovementHistoryScreen), findsOneWidget);
    });

    testWidgets('accessible during pending deletion window', (tester) async {
      final item = InventoryItem(id: 'item_pending', name: 'Pending Item', sku: 'PND-999');
      final repo = MockInventoryRepository(
        items: [item],
        movements: [
          StockMovement(
            id: 'mov_pnd',
            inventoryItemId: 'item_pending',
            type: StockMovementType.openingStock,
            quantityDelta: 10.0,
            createdAt: DateTime.utc(2026, 1, 1, 10, 0),
          ),
        ],
      );

      // Request deletion (places into 60-second window)
      await repo.requestItemDeletion(
        itemId: 'item_pending',
        performedByUserId: adminUser.id,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StockMovementHistoryScreen(
            user: authorizedViewer,
            repository: repo,
            itemId: 'item_pending',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // History screen renders successfully without restrictions
      expect(find.byType(StockMovementHistoryScreen), findsOneWidget);
      expect(find.text('Pending Item'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.byKey(const Key('stock_movement_card_mov_pnd')), findsOneWidget);
    });

    testWidgets('renders cleanly without overflow across responsive screen sizes', (tester) async {
      final item = InventoryItem(id: 'item_resp', name: 'Responsive Test Item with a Long Product Name', sku: 'RESP-LONG-SKU-99999');
      final movements = [
        StockMovement(
          id: 'mov_r1',
          inventoryItemId: 'item_resp',
          type: StockMovementType.openingStock,
          quantityDelta: 1250.0,
          createdAt: DateTime.utc(2026, 3, 15, 9, 30),
          performedByUserId: 'usr_admin_very_long_identifier',
          reason: 'Initial warehouse stock intake from international supplier',
        ),
        StockMovement(
          id: 'mov_r2',
          inventoryItemId: 'item_resp',
          type: StockMovementType.adjustment,
          quantityDelta: -250.0,
          createdAt: DateTime.utc(2026, 3, 20, 15, 45),
          performedByUserId: 'usr_manager',
          reason: 'Damaged packaging during transit to regional hub',
        ),
      ];

      final repo = MockInventoryRepository(items: [item], movements: movements);

      const testSizes = [
        Size(320, 640),   // Compact mobile
        Size(360, 800),   // Standard mobile
        Size(768, 1024),  // Tablet
        Size(1200, 900),  // Desktop
      ];

      for (final size in testSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: ThemeMode.light,
            home: StockMovementHistoryScreen(
              user: adminUser,
              repository: repo,
              itemId: 'item_resp',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('stock_history_header_card')), findsOneWidget);
        expect(find.byKey(const Key('stock_history_list')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
