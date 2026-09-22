import 'dart:async';

import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_page.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_stock_mutation_result.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:enterprise_crm/features/inventory/domain/exceptions/inventory_exception.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/record_opening_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/update_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/adjust_inventory_stock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TrackingInventoryRepository implements InventoryRepository {
  final Future<InventoryItemSummary?> Function(String)? onGetItemById;
  final Future<bool> Function(String)? onHasStockMovements;
  final Future<InventoryStockMutationResult> Function(
    AdjustInventoryStockInput,
  )?
  onAdjustStock;

  int adjustStockCalls = 0;
  int getItemByIdCalls = 0;
  int hasStockMovementsCalls = 0;

  _TrackingInventoryRepository({
    this.onGetItemById,
    this.onHasStockMovements,
    this.onAdjustStock,
  });

  @override
  Future<InventoryPage> getItems(InventoryQuery query) =>
      throw UnimplementedError();

  @override
  Future<InventoryItemSummary?> getItemById(String id) {
    getItemByIdCalls++;
    if (onGetItemById != null) return onGetItemById!(id);
    return MockInventoryRepository().getItemById(id);
  }

  @override
  Future<InventoryItemSummary> createItem(CreateInventoryItemInput input) =>
      throw UnimplementedError();

  @override
  Future<InventoryItemSummary> updateItem(UpdateInventoryItemInput input) =>
      throw UnimplementedError();

  @override
  Future<bool> hasStockMovements(String itemId) {
    hasStockMovementsCalls++;
    if (onHasStockMovements != null) return onHasStockMovements!(itemId);
    return Future.value(true);
  }

  @override
  Future<InventoryStockMutationResult> recordOpeningStock(
    RecordOpeningStockInput input,
  ) => throw UnimplementedError();

  @override
  Future<InventoryStockMutationResult> adjustStock(
    AdjustInventoryStockInput input,
  ) {
    adjustStockCalls++;
    if (onAdjustStock != null) return onAdjustStock!(input);
    return MockInventoryRepository().adjustStock(input);
  }
}

void main() {
  group('AdjustInventoryStockScreen Widget Tests', () {
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

    final sampleItem = InventoryItem(
      id: 'item_001',
      name: 'Laptop Stand',
      sku: 'ACC-001',
    );
    final sampleSummary = InventoryItemSummary(
      item: sampleItem,
      quantityOnHand: 25.0,
    );

    Widget createWidget({
      CurrentUser? user,
      InventoryRepository? repository,
      String itemId = 'item_001',
      ThemeMode themeMode = ThemeMode.light,
    }) {
      return MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: themeMode,
        home: AdjustInventoryStockScreen(
          user: user ?? adminUser,
          repository:
              repository ??
              _TrackingInventoryRepository(
                onGetItemById: (id) async => sampleSummary,
                onHasStockMovements: (id) async => true,
              ),
          itemId: itemId,
        ),
      );
    }

    testWidgets('authorized Admin renders adjust stock form', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Adjust Stock'), findsOneWidget);
      expect(find.text('Manual Stock Adjustment'), findsOneWidget);
      expect(
        find.byKey(const Key('adjust_stock_direction_increase')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('adjust_stock_direction_decrease')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('adjust_stock_quantity')), findsOneWidget);
      expect(find.byKey(const Key('adjust_stock_reason')), findsOneWidget);
      expect(find.byKey(const Key('adjust_stock_submit')), findsOneWidget);
      expect(find.byKey(const Key('adjust_stock_cancel')), findsOneWidget);
    });

    testWidgets(
      'Standard User is restricted with AccessRestrictedScreen and 0 calls',
      (tester) async {
        final repo = _TrackingInventoryRepository();
        await tester.pumpWidget(
          createWidget(user: standardUser, repository: repo),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(repo.getItemByIdCalls, 0);
        expect(repo.hasStockMovementsCalls, 0);
        expect(repo.adjustStockCalls, 0);
      },
    );

    testWidgets(
      'renders read-only item context (name, SKU, current quantity)',
      (tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('adjust_stock_context_name')),
          findsOneWidget,
        );
        expect(find.text('Laptop Stand'), findsOneWidget);
        expect(find.text('SKU: ACC-001'), findsOneWidget);
        expect(find.text('Current: 25'), findsOneWidget);
      },
    );

    testWidgets('does NOT render actor field', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('User ID'), findsNothing);
      expect(find.text('Actor'), findsNothing);
      expect(find.byKey(const Key('adjust_stock_actor')), findsNothing);
    });

    Future<void> tapSubmit(WidgetTester tester) async {
      final submitFinder = find.byKey(const Key('adjust_stock_submit'));
      await tester.ensureVisible(submitFinder);
      await tester.pumpAndSettle();
      await tester.tap(submitFinder);
    }

    testWidgets('validation displays error for missing or invalid inputs', (
      tester,
    ) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Submit with empty quantity and reason
      await tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Quantity is required.'), findsOneWidget);
      expect(find.text('Reason is required.'), findsOneWidget);

      // Enter 0 quantity
      await tester.enterText(
        find.byKey(const Key('adjust_stock_quantity')),
        '0',
      );
      await tester.enterText(
        find.byKey(const Key('adjust_stock_reason')),
        'Count correction',
      );
      await tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Quantity must be greater than zero.'), findsOneWidget);

      // Enter negative quantity
      await tester.enterText(
        find.byKey(const Key('adjust_stock_quantity')),
        '-10',
      );
      await tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Quantity must be greater than zero.'), findsOneWidget);

      // Enter invalid non-numeric text
      await tester.enterText(
        find.byKey(const Key('adjust_stock_quantity')),
        'xyz',
      );
      await tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid quantity.'), findsOneWidget);
    });

    testWidgets(
      'successful Increase adjustment calls repository with positive delta',
      (tester) async {
        AdjustInventoryStockInput? capturedInput;
        final repo = _TrackingInventoryRepository(
          onGetItemById: (id) async => sampleSummary,
          onHasStockMovements: (id) async => true,
          onAdjustStock: (input) async {
            capturedInput = input;
            return InventoryStockMutationResult(
              movement: StockMovement(
                id: 'mov_200',
                inventoryItemId: 'item_001',
                type: StockMovementType.adjustment,
                quantityDelta: 10.0,
                createdAt: DateTime.utc(2026, 1, 1),
                performedByUserId: 'usr_admin',
                reason: 'Received return',
              ),
              item: sampleSummary,
            );
          },
        );

        await tester.pumpWidget(createWidget(repository: repo));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('adjust_stock_quantity')),
          '10',
        );
        await tester.enterText(
          find.byKey(const Key('adjust_stock_reason')),
          '  Received return  ',
        );

        await tapSubmit(tester);
        await tester.pump();

        expect(repo.adjustStockCalls, 1);
        expect(capturedInput?.itemId, 'item_001');
        expect(capturedInput?.quantityDelta, 10.0);
        expect(capturedInput?.reason, 'Received return');
        expect(capturedInput?.performedByUserId, 'usr_admin');
      },
    );

    testWidgets(
      'successful Decrease adjustment calls repository with negative delta',
      (tester) async {
        AdjustInventoryStockInput? capturedInput;
        final repo = _TrackingInventoryRepository(
          onGetItemById: (id) async => sampleSummary,
          onHasStockMovements: (id) async => true,
          onAdjustStock: (input) async {
            capturedInput = input;
            return InventoryStockMutationResult(
              movement: StockMovement(
                id: 'mov_201',
                inventoryItemId: 'item_001',
                type: StockMovementType.adjustment,
                quantityDelta: -5.0,
                createdAt: DateTime.utc(2026, 1, 1),
                performedByUserId: 'usr_admin',
                reason: 'Damaged item',
              ),
              item: sampleSummary,
            );
          },
        );

        await tester.pumpWidget(createWidget(repository: repo));
        await tester.pumpAndSettle();

        // Tap Decrease segment
        await tester.tap(
          find.byKey(const Key('adjust_stock_direction_decrease')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('adjust_stock_quantity')),
          '5',
        );
        await tester.enterText(
          find.byKey(const Key('adjust_stock_reason')),
          'Damaged item',
        );

        await tapSubmit(tester);
        await tester.pump();

        expect(repo.adjustStockCalls, 1);
        expect(capturedInput?.itemId, 'item_001');
        expect(capturedInput?.quantityDelta, -5.0);
        expect(capturedInput?.reason, 'Damaged item');
        expect(capturedInput?.performedByUserId, 'usr_admin');
      },
    );

    testWidgets(
      'displays error snackbar when adjustment causes negative stock',
      (tester) async {
        final repo = _TrackingInventoryRepository(
          onGetItemById: (id) async => sampleSummary,
          onHasStockMovements: (id) async => true,
          onAdjustStock: (input) =>
              throw const InventoryNegativeStockException(),
        );

        await tester.pumpWidget(createWidget(repository: repo));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('adjust_stock_direction_decrease')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('adjust_stock_quantity')),
          '100',
        );
        await tester.enterText(
          find.byKey(const Key('adjust_stock_reason')),
          'Damaged inventory',
        );

        await tapSubmit(tester);
        await tester.pumpAndSettle();

        expect(
          find.text('This adjustment would make stock negative.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows unavailable view when item has no movements', (
      tester,
    ) async {
      final repo = _TrackingInventoryRepository(
        onGetItemById: (id) async => sampleSummary,
        onHasStockMovements: (id) async => false,
      );

      await tester.pumpWidget(createWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(
        find.text('Stock must be initialized before it can be adjusted.'),
        findsOneWidget,
      );
      expect(find.text('Back to Details'), findsOneWidget);
      expect(find.byKey(const Key('adjust_stock_quantity')), findsNothing);
    });

    testWidgets(
      'disables submit button during submission to prevent double submits',
      (tester) async {
        final completer = Completer<InventoryStockMutationResult>();
        final repo = _TrackingInventoryRepository(
          onGetItemById: (id) async => sampleSummary,
          onHasStockMovements: (id) async => true,
          onAdjustStock: (input) => completer.future,
        );

        await tester.pumpWidget(createWidget(repository: repo));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('adjust_stock_quantity')),
          '5',
        );
        await tester.enterText(
          find.byKey(const Key('adjust_stock_reason')),
          'Cycle count',
        );

        final submitFinder = find.byKey(const Key('adjust_stock_submit'));
        await tester.ensureVisible(submitFinder);
        await tester.pumpAndSettle();
        await tester.tap(submitFinder);
        await tester.pump();

        // Submit button is disabled
        final filledBtn = tester.widget<FilledButton>(submitFinder);
        expect(filledBtn.onPressed, isNull);

        // Attempt second tap
        await tester.tap(submitFinder, warnIfMissed: false);
        await tester.pump();
        expect(repo.adjustStockCalls, 1);

        completer.complete(
          InventoryStockMutationResult(
            movement: StockMovement(
              id: 'mov_1',
              inventoryItemId: 'item_001',
              type: StockMovementType.adjustment,
              quantityDelta: 5.0,
              createdAt: DateTime.utc(2026, 1, 1),
              performedByUserId: 'usr_admin',
              reason: 'Cycle count',
            ),
            item: sampleSummary,
          ),
        );
        await tester.pumpAndSettle();
      },
    );

    group('Responsive Viewport Tests', () {
      final sizes = [
        const Size(320, 568),
        const Size(360, 640),
        const Size(768, 1024),
        const Size(1200, 800),
      ];

      for (final size in sizes) {
        testWidgets(
          'renders cleanly without overflow at ${size.width}x${size.height}',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(createWidget());
            await tester.pumpAndSettle();

            expect(find.widgetWithText(AppBar, 'Adjust Stock'), findsOneWidget);
            expect(
              find.byKey(const Key('adjust_stock_quantity')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    });

    testWidgets('renders cleanly in dark mode', (tester) async {
      await tester.pumpWidget(createWidget(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Adjust Stock'), findsOneWidget);
      expect(find.byKey(const Key('adjust_stock_quantity')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
