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
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/record_opening_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/update_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/set_opening_stock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';

class _TrackingInventoryRepository implements InventoryRepository {
  final Future<InventoryItemSummary?> Function(String)? onGetItemById;
  final Future<bool> Function(String)? onHasStockMovements;
  final Future<InventoryStockMutationResult> Function(RecordOpeningStockInput)?
  onRecordOpeningStock;

  int recordOpeningStockCalls = 0;
  int getItemByIdCalls = 0;
  int hasStockMovementsCalls = 0;

  _TrackingInventoryRepository({
    this.onGetItemById,
    this.onHasStockMovements,
    this.onRecordOpeningStock,
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
    return Future.value(false);
  }

  @override
  Future<InventoryStockMutationResult> recordOpeningStock(
    RecordOpeningStockInput input,
  ) {
    recordOpeningStockCalls++;
    if (onRecordOpeningStock != null) return onRecordOpeningStock!(input);
    return MockInventoryRepository().recordOpeningStock(input);
  }

  @override
  Future<InventoryStockMutationResult> adjustStock(
    AdjustInventoryStockInput input,
  ) => throw UnimplementedError();

  @override
  Future<Set<String>> getExistingSkus() => Future.value({});

  @override
  Future<InventoryImportResult> importItems(InventoryImportRequest request) =>
      throw UnimplementedError();
}

void main() {
  group('SetOpeningStockScreen Widget Tests', () {
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
      id: 'item_new_1',
      name: 'Uninitialized Item',
      sku: 'SKU-NEW-1',
    );
    final sampleSummary = InventoryItemSummary(
      item: sampleItem,
      quantityOnHand: 0.0,
    );

    Widget createWidget({
      CurrentUser? user,
      InventoryRepository? repository,
      String itemId = 'item_new_1',
      ThemeMode themeMode = ThemeMode.light,
    }) {
      return MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: themeMode,
        home: SetOpeningStockScreen(
          user: user ?? adminUser,
          repository:
              repository ??
              _TrackingInventoryRepository(
                onGetItemById: (id) async => sampleSummary,
                onHasStockMovements: (id) async => false,
              ),
          itemId: itemId,
        ),
      );
    }

    testWidgets('authorized Admin renders opening stock form', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Set Opening Stock'), findsOneWidget);
      expect(find.text('Initial Stock Count'), findsOneWidget);
      expect(
        find.byKey(const Key('set_opening_stock_quantity')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('set_opening_stock_submit')), findsOneWidget);
      expect(find.byKey(const Key('set_opening_stock_cancel')), findsOneWidget);
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
        expect(repo.recordOpeningStockCalls, 0);
      },
    );

    testWidgets(
      'renders read-only item context (name, SKU, current quantity)',
      (tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('set_opening_stock_context_name')),
          findsOneWidget,
        );
        expect(find.text('Uninitialized Item'), findsOneWidget);
        expect(find.text('SKU: SKU-NEW-1'), findsOneWidget);
        expect(find.text('Current: 0'), findsOneWidget);
      },
    );

    testWidgets('does NOT render reason field or actor field', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Reason'), findsNothing);
      expect(find.text('User ID'), findsNothing);
      expect(find.text('Actor'), findsNothing);
      expect(find.byKey(const Key('set_opening_stock_reason')), findsNothing);
      expect(find.byKey(const Key('set_opening_stock_actor')), findsNothing);
    });

    testWidgets('validation displays error for empty or invalid quantity', (
      tester,
    ) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Submit empty
      await tester.tap(find.byKey(const Key('set_opening_stock_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Opening quantity is required.'), findsOneWidget);

      // Enter 0
      await tester.enterText(
        find.byKey(const Key('set_opening_stock_quantity')),
        '0',
      );
      await tester.tap(find.byKey(const Key('set_opening_stock_submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('Opening quantity must be greater than zero.'),
        findsOneWidget,
      );

      // Enter negative
      await tester.enterText(
        find.byKey(const Key('set_opening_stock_quantity')),
        '-5',
      );
      await tester.tap(find.byKey(const Key('set_opening_stock_submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('Opening quantity must be greater than zero.'),
        findsOneWidget,
      );

      // Enter invalid numeric text
      await tester.enterText(
        find.byKey(const Key('set_opening_stock_quantity')),
        'abc',
      );
      await tester.tap(find.byKey(const Key('set_opening_stock_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid quantity.'), findsOneWidget);
    });

    testWidgets(
      'successful submit calls repository with authenticated user ID and quantity',
      (tester) async {
        RecordOpeningStockInput? capturedInput;
        final repo = _TrackingInventoryRepository(
          onGetItemById: (id) async => sampleSummary,
          onHasStockMovements: (id) async => false,
          onRecordOpeningStock: (input) async {
            capturedInput = input;
            return InventoryStockMutationResult(
              movement: StockMovement(
                id: 'mov_100',
                inventoryItemId: 'item_new_1',
                type: StockMovementType.openingStock,
                quantityDelta: 15.5,
                createdAt: DateTime.utc(2026, 1, 1),
                performedByUserId: 'usr_admin',
              ),
              item: sampleSummary,
            );
          },
        );

        await tester.pumpWidget(createWidget(repository: repo));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('set_opening_stock_quantity')),
          '15.5',
        );
        await tester.tap(find.byKey(const Key('set_opening_stock_submit')));
        await tester.pump();

        expect(repo.recordOpeningStockCalls, 1);
        expect(capturedInput?.itemId, 'item_new_1');
        expect(capturedInput?.quantity, 15.5);
        expect(capturedInput?.performedByUserId, 'usr_admin');
      },
    );

    testWidgets('shows unavailable view when item already has movements', (
      tester,
    ) async {
      final repo = _TrackingInventoryRepository(
        onGetItemById: (id) async => sampleSummary,
        onHasStockMovements: (id) async => true,
      );

      await tester.pumpWidget(createWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(
        find.text('Opening stock has already been initialized for this item.'),
        findsOneWidget,
      );
      expect(find.text('Back to Details'), findsOneWidget);
      expect(find.byKey(const Key('set_opening_stock_quantity')), findsNothing);
    });

    testWidgets('shows not found view when item does not exist', (
      tester,
    ) async {
      final repo = _TrackingInventoryRepository(
        onGetItemById: (id) async => null,
      );

      await tester.pumpWidget(createWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Inventory item not found.'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets(
      'disables submit button during submission to prevent double submits',
      (tester) async {
        final completer = Completer<InventoryStockMutationResult>();
        final repo = _TrackingInventoryRepository(
          onGetItemById: (id) async => sampleSummary,
          onHasStockMovements: (id) async => false,
          onRecordOpeningStock: (input) => completer.future,
        );

        await tester.pumpWidget(createWidget(repository: repo));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('set_opening_stock_quantity')),
          '10',
        );

        await tester.tap(find.byKey(const Key('set_opening_stock_submit')));
        await tester.pump();

        // Submit button is now disabled (onPressed is null)
        final submitButtonFinder = find.byKey(
          const Key('set_opening_stock_submit'),
        );
        final filledBtn = tester.widget<FilledButton>(submitButtonFinder);
        expect(filledBtn.onPressed, isNull);

        // Attempt second tap
        await tester.tap(submitButtonFinder, warnIfMissed: false);
        await tester.pump();
        expect(repo.recordOpeningStockCalls, 1);

        completer.complete(
          InventoryStockMutationResult(
            movement: StockMovement(
              id: 'mov_1',
              inventoryItemId: 'item_new_1',
              type: StockMovementType.openingStock,
              quantityDelta: 10.0,
              createdAt: DateTime.utc(2026, 1, 1),
              performedByUserId: 'usr_admin',
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

            expect(
              find.widgetWithText(AppBar, 'Set Opening Stock'),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('set_opening_stock_quantity')),
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

      expect(find.widgetWithText(AppBar, 'Set Opening Stock'), findsOneWidget);
      expect(
        find.byKey(const Key('set_opening_stock_quantity')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
