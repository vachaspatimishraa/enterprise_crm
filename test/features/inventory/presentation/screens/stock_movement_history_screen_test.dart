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

class _SpyInventoryRepository extends MockInventoryRepository {
  int getStockMovementsCalls = 0;
  _SpyInventoryRepository({super.items, super.movements});

  @override
  Future<List<StockMovementRecord>> getStockMovements(String itemId) {
    getStockMovementsCalls++;
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

      // Filter control
      expect(find.byKey(const Key('stock_history_filter_segmented_button')), findsOneWidget);

      // List of movements (newest first: mov_2 then mov_1)
      expect(find.byKey(const Key('stock_history_list')), findsOneWidget);
      expect(find.byKey(const Key('stock_movement_card_mov_2')), findsOneWidget);
      expect(find.byKey(const Key('stock_movement_card_mov_1')), findsOneWidget);

      // Verify mov_2 (Adjustment)
      expect(find.byKey(const Key('movement_type_mov_2')), findsOneWidget);
      expect((tester.widget(find.byKey(const Key('movement_type_mov_2'))) as Text).data, 'Adjustment');
      expect(find.text('-15'), findsOneWidget);
      expect(find.text('Balance: 35'), findsOneWidget);
      expect(find.text('usr_admin'), findsOneWidget);
      expect(find.text('Physical count adjustment'), findsOneWidget);

      // Verify mov_1 (Opening Stock, null actor, null reason)
      expect(find.byKey(const Key('movement_type_mov_1')), findsOneWidget);
      expect((tester.widget(find.byKey(const Key('movement_type_mov_1'))) as Text).data, 'Opening Stock');
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
      expect(find.byKey(const Key('stock_history_filter_segmented_button')), findsNothing);
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

    group('INVENTORY-5.3B Movement Type Filtering Tests', () {
      final multiMovementItem = InventoryItem(
        id: 'item_multi',
        name: 'Multi Movement Item',
        sku: 'MM-001',
      );
      final multiMovements = [
        StockMovement(
          id: 'mov_open',
          inventoryItemId: 'item_multi',
          type: StockMovementType.openingStock,
          quantityDelta: 50.0,
          createdAt: DateTime.utc(2026, 1, 1, 10, 0),
          performedByUserId: 'usr_admin',
          reason: 'Initial intake',
        ),
        StockMovement(
          id: 'mov_adj_1',
          inventoryItemId: 'item_multi',
          type: StockMovementType.adjustment,
          quantityDelta: 20.0,
          createdAt: DateTime.utc(2026, 1, 2, 11, 0),
          performedByUserId: 'usr_admin',
          reason: 'Stock received',
        ),
        StockMovement(
          id: 'mov_adj_2',
          inventoryItemId: 'item_multi',
          type: StockMovementType.adjustment,
          quantityDelta: -10.0,
          createdAt: DateTime.utc(2026, 1, 3, 12, 0),
          performedByUserId: 'usr_manager',
          reason: 'Physical loss',
        ),
      ];

      testWidgets(
        'All Movements filter is selected by default and renders all movements newest-first',
        (tester) async {
          final repo = MockInventoryRepository(
            items: [multiMovementItem],
            movements: multiMovements,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: StockMovementHistoryScreen(
                user: authorizedViewer,
                repository: repo,
                itemId: 'item_multi',
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Header quantity = 50 + 20 - 10 = 60
          expect(find.text('60'), findsOneWidget);

          // All 3 movements visible in newest-first order
          expect(find.byKey(const Key('stock_movement_card_mov_adj_2')), findsOneWidget);
          expect(find.byKey(const Key('stock_movement_card_mov_adj_1')), findsOneWidget);
          expect(find.byKey(const Key('stock_movement_card_mov_open')), findsOneWidget);

          // Check running balance invariant on all cards
          expect(find.text('Balance: 60'), findsOneWidget); // mov_adj_2
          expect(find.text('Balance: 70'), findsOneWidget); // mov_adj_1
          expect(find.text('Balance: 50'), findsOneWidget); // mov_open
        },
      );

      testWidgets(
        'Opening Stock filter displays only openingStock and preserves running balance & header quantity',
        (tester) async {
          final repo = _SpyInventoryRepository(
            items: [multiMovementItem],
            movements: multiMovements,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: StockMovementHistoryScreen(
                user: authorizedViewer,
                repository: repo,
                itemId: 'item_multi',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(repo.getStockMovementsCalls, 1);

          // Select Opening Stock filter
          await tester.tap(find.byKey(const Key('stock_history_filter_opening_stock')));
          await tester.pumpAndSettle();

          // Repository is NOT called again (local filtering)
          expect(repo.getStockMovementsCalls, 1);

          // Header quantity remains authoritative current quantity (60), NOT opening stock quantity (50)
          expect(find.text('60'), findsOneWidget);

          // Only opening stock card is visible
          expect(find.byKey(const Key('stock_movement_card_mov_open')), findsOneWidget);
          expect(find.byKey(const Key('stock_movement_card_mov_adj_1')), findsNothing);
          expect(find.byKey(const Key('stock_movement_card_mov_adj_2')), findsNothing);

          // Running balance of opening stock card remains unchanged (50)
          expect(find.text('Balance: 50'), findsOneWidget);
        },
      );

      testWidgets(
        'Adjustment filter displays only adjustment movements newest-first with unchanged running balances',
        (tester) async {
          final repo = _SpyInventoryRepository(
            items: [multiMovementItem],
            movements: multiMovements,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: StockMovementHistoryScreen(
                user: authorizedViewer,
                repository: repo,
                itemId: 'item_multi',
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Select Adjustment filter
          await tester.tap(find.byKey(const Key('stock_history_filter_adjustment')));
          await tester.pumpAndSettle();

          // Zero additional repository calls
          expect(repo.getStockMovementsCalls, 1);

          // Header quantity remains authoritative current balance (60)
          expect(find.text('60'), findsOneWidget);

          // Adjustment cards are visible newest-first
          expect(find.byKey(const Key('stock_movement_card_mov_adj_2')), findsOneWidget);
          expect(find.byKey(const Key('stock_movement_card_mov_adj_1')), findsOneWidget);
          expect(find.byKey(const Key('stock_movement_card_mov_open')), findsNothing);

          // Individual authoritative balances preserved (60 and 70)
          expect(find.text('Balance: 60'), findsOneWidget);
          expect(find.text('Balance: 70'), findsOneWidget);

          // Switching back to All Movements restores all records
          await tester.tap(find.byKey(const Key('stock_history_filter_all')));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('stock_movement_card_mov_adj_2')), findsOneWidget);
          expect(find.byKey(const Key('stock_movement_card_mov_adj_1')), findsOneWidget);
          expect(find.byKey(const Key('stock_movement_card_mov_open')), findsOneWidget);
        },
      );

      testWidgets(
        'filter-specific empty state displays when selected filter has no matches and allows switching back',
        (tester) async {
          final singleOpenItem = InventoryItem(
            id: 'item_open_only',
            name: 'Opening Stock Only Item',
            sku: 'OPEN-001',
          );
          final openOnlyMovements = [
            StockMovement(
              id: 'mov_single_open',
              inventoryItemId: 'item_open_only',
              type: StockMovementType.openingStock,
              quantityDelta: 25.0,
              createdAt: DateTime.utc(2026, 1, 1, 10, 0),
            ),
          ];

          final repo = MockInventoryRepository(
            items: [singleOpenItem],
            movements: openOnlyMovements,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: StockMovementHistoryScreen(
                user: authorizedViewer,
                repository: repo,
                itemId: 'item_open_only',
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Header shows 25
          expect(find.text('25'), findsOneWidget);
          expect(find.byKey(const Key('stock_movement_card_mov_single_open')), findsOneWidget);

          // Select Adjustment filter -> no adjustment movements exist
          await tester.tap(find.byKey(const Key('stock_history_filter_adjustment')));
          await tester.pumpAndSettle();

          // Header still shows current balance 25
          expect(find.text('25'), findsOneWidget);
          expect(find.byKey(const Key('stock_history_header_card')), findsOneWidget);
          expect(find.byKey(const Key('stock_history_filter_segmented_button')), findsOneWidget);

          // Filter-specific empty view
          expect(find.byKey(const Key('stock_history_filter_empty_view')), findsOneWidget);
          expect(find.text('No adjustment movements found.'), findsOneWidget);
          expect(find.byKey(const Key('stock_movement_card_mov_single_open')), findsNothing);

          // Switch back to All Movements -> restores opening stock movement
          await tester.tap(find.byKey(const Key('stock_history_filter_all')));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('stock_history_filter_empty_view')), findsNothing);
          expect(find.byKey(const Key('stock_movement_card_mov_single_open')), findsOneWidget);
        },
      );

      testWidgets(
        'filter-specific empty state for missing opening stock',
        (tester) async {
          final adjOnlyItem = InventoryItem(
            id: 'item_adj_only',
            name: 'Adjustment Only Item',
            sku: 'ADJ-001',
          );
          final adjOnlyMovements = [
            StockMovement(
              id: 'mov_single_adj',
              inventoryItemId: 'item_adj_only',
              type: StockMovementType.adjustment,
              quantityDelta: 10.0,
              createdAt: DateTime.utc(2026, 1, 1, 10, 0),
            ),
          ];

          final repo = MockInventoryRepository(
            items: [adjOnlyItem],
            movements: adjOnlyMovements,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: StockMovementHistoryScreen(
                user: authorizedViewer,
                repository: repo,
                itemId: 'item_adj_only',
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Select Opening Stock filter -> no opening stock exists
          await tester.tap(find.byKey(const Key('stock_history_filter_opening_stock')));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('stock_history_filter_empty_view')), findsOneWidget);
          expect(find.text('No opening stock movements found.'), findsOneWidget);
        },
      );
    });

    testWidgets('renders cleanly without overflow across responsive screen sizes and dark theme with filter active', (tester) async {
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
        Size(320, 568),   // Compact mobile
        Size(360, 640),   // Standard mobile
        Size(768, 1024),  // Tablet
        Size(1200, 800),  // Desktop
      ];

      for (final size in testSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        for (final isDark in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: StockMovementHistoryScreen(
                user: adminUser,
                repository: repo,
                itemId: 'item_resp',
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('stock_history_header_card')), findsOneWidget);
          expect(find.byKey(const Key('stock_history_filter_segmented_button')), findsOneWidget);
          expect(find.byKey(const Key('stock_history_list')), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Test scrolling and switching filter under compact/dark view
          await tester.ensureVisible(find.byKey(const Key('stock_history_filter_adjustment')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('stock_history_filter_adjustment')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.ensureVisible(find.byKey(const Key('stock_history_filter_all')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('stock_history_filter_all')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    });
  });
}
