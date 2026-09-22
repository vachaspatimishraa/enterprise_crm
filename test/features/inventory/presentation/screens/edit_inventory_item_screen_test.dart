import 'dart:async';

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
import 'package:enterprise_crm/features/inventory/presentation/screens/edit_inventory_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TrackingInventoryRepository implements InventoryRepository {
  final Future<InventoryItemSummary> Function(UpdateInventoryItemInput)?
  onUpdate;
  int getItemByIdCalls = 0;
  int updateCalls = 0;

  _TrackingInventoryRepository({this.onUpdate});

  @override
  Future<InventoryPage> getItems(InventoryQuery query) =>
      throw UnimplementedError();

  @override
  Future<InventoryItemSummary?> getItemById(String id) {
    getItemByIdCalls++;
    return MockInventoryRepository().getItemById(id);
  }

  @override
  Future<InventoryItemSummary> createItem(CreateInventoryItemInput input) =>
      throw UnimplementedError();

  @override
  Future<InventoryItemSummary> updateItem(UpdateInventoryItemInput input) {
    updateCalls++;
    if (onUpdate != null) {
      return onUpdate!(input);
    }
    return MockInventoryRepository().updateItem(input);
  }

  @override
  Future<bool> hasStockMovements(String itemId) => throw UnimplementedError();

  @override
  Future<InventoryStockMutationResult> recordOpeningStock(
    RecordOpeningStockInput input,
  ) => throw UnimplementedError();

  @override
  Future<InventoryStockMutationResult> adjustStock(
    AdjustInventoryStockInput input,
  ) => throw UnimplementedError();
}

void main() {
  group('EditInventoryItemScreen Widget Tests', () {
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
        home: EditInventoryItemScreen(
          user: user ?? adminUser,
          repository: repository ?? MockInventoryRepository(),
          itemId: itemId,
        ),
      );
    }

    testWidgets('freshly loads item by itemId and pre-populates name and SKU', (
      tester,
    ) async {
      final repo = _TrackingInventoryRepository();

      await tester.pumpWidget(createWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(repo.getItemByIdCalls, 1);
      expect(find.text('Edit Inventory Item'), findsOneWidget);
      expect(find.text('Edit Item Identity'), findsOneWidget);

      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('edit_inventory_item_name')),
      );
      final skuField = tester.widget<TextFormField>(
        find.byKey(const Key('edit_inventory_item_sku')),
      );

      expect(nameField.controller?.text, 'Laptop Stand');
      expect(skuField.controller?.text, 'INV-001');
    });

    testWidgets(
      'INVARIANT: quantity and stock are strictly NOT displayed in edit form',
      (tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        // Ensure no stock chips, quantity fields, or movement labels are present
        expect(find.text('Quantity'), findsNothing);
        expect(find.text('Stock'), findsNothing);
        expect(find.text('Quantity on hand'), findsNothing);
        expect(find.text('25'), findsNothing);
        expect(find.text('Opening Stock'), findsNothing);
      },
    );

    testWidgets('Cancel navigation pop works', (tester) async {
      bool popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => EditInventoryItemScreen(
                      user: adminUser,
                      repository: MockInventoryRepository(),
                      itemId: 'item_001',
                    ),
                  ),
                );
                if (result == null) popped = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Inventory Item'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('edit_inventory_item_cancel_button')),
      );
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });

    testWidgets('validates required name field on save', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('edit_inventory_item_name')),
        '   ',
      );
      await tester.tap(find.byKey(const Key('edit_inventory_item_save')));
      await tester.pumpAndSettle();

      expect(find.text('Item name is required.'), findsOneWidget);
    });

    testWidgets('validates required SKU field on save', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('edit_inventory_item_sku')),
        '   ',
      );
      await tester.tap(find.byKey(const Key('edit_inventory_item_save')));
      await tester.pumpAndSettle();

      expect(find.text('SKU is required.'), findsOneWidget);
    });

    testWidgets(
      'displays snackbar on duplicate SKU collision with other item',
      (tester) async {
        final repo = MockInventoryRepository();
        await tester.pumpWidget(createWidget(repository: repo));
        await tester.pumpAndSettle();

        // item_002 has sku 'INV-002'
        await tester.enterText(
          find.byKey(const Key('edit_inventory_item_sku')),
          'inv-002',
        );
        await tester.tap(find.byKey(const Key('edit_inventory_item_save')));
        await tester.pumpAndSettle();

        expect(
          find.text('An item with this SKU already exists.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders not found state when item does not exist', (
      tester,
    ) async {
      await tester.pumpWidget(createWidget(itemId: 'non_existent_id'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit_inventory_not_found')), findsOneWidget);
      expect(find.text('Inventory item not found'), findsOneWidget);
      expect(
        find.byKey(const Key('edit_inventory_not_found_back_button')),
        findsOneWidget,
      );
    });

    testWidgets('successful edit pops route with true result', (tester) async {
      bool? poppedResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                poppedResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => EditInventoryItemScreen(
                      user: adminUser,
                      repository: MockInventoryRepository(),
                      itemId: 'item_001',
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('edit_inventory_item_name')),
        'Updated Laptop Stand',
      );
      await tester.enterText(
        find.byKey(const Key('edit_inventory_item_sku')),
        'INV-001-MOD',
      );
      await tester.tap(find.byKey(const Key('edit_inventory_item_save')));
      await tester.pumpAndSettle();

      expect(poppedResult, isTrue);
      expect(find.text('Edit Inventory Item'), findsNothing);
    });

    testWidgets('handles repository update failure safely with snackbar', (
      tester,
    ) async {
      final repo = _TrackingInventoryRepository(
        onUpdate: (_) => throw Exception('Network update failed'),
      );
      await tester.pumpWidget(createWidget(repository: repo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('edit_inventory_item_name')),
        'New Name',
      );
      await tester.tap(find.byKey(const Key('edit_inventory_item_save')));
      await tester.pumpAndSettle();

      expect(find.text('Unable to update inventory item.'), findsOneWidget);
    });

    testWidgets(
      'button is disabled during submission and prevents double-submit',
      (tester) async {
        final completer = Completer<InventoryItemSummary>();
        final repo = _TrackingInventoryRepository(
          onUpdate: (_) => completer.future,
        );

        await tester.pumpWidget(createWidget(repository: repo));
        await tester.pumpAndSettle();

        // First submit
        await tester.tap(find.byKey(const Key('edit_inventory_item_save')));
        await tester.pump(); // Start async

        expect(find.text('Saving...'), findsOneWidget);
        expect(repo.updateCalls, 1);

        // Attempt second submit while saving
        await tester.tap(
          find.byKey(const Key('edit_inventory_item_save')),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(repo.updateCalls, 1);

        // Complete
        final fakeItem = (await MockInventoryRepository().getItemById(
          'item_001',
        ))!;
        completer.complete(fakeItem);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Admin is authorized; Standard User is rejected with AccessRestrictedScreen and 0 repo calls',
      (tester) async {
        final repo = _TrackingInventoryRepository();

        await tester.pumpWidget(
          createWidget(user: standardUser, repository: repo),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.text('Access Restricted'), findsOneWidget);
        expect(find.byKey(const Key('edit_inventory_item_save')), findsNothing);
        expect(repo.getItemByIdCalls, 0);
        expect(repo.updateCalls, 0);
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

            expect(find.text('Edit Inventory Item'), findsOneWidget);
            expect(
              find.byKey(const Key('edit_inventory_item_name')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('edit_inventory_item_sku')),
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

      expect(find.text('Edit Inventory Item'), findsOneWidget);
      expect(find.byKey(const Key('edit_inventory_item_name')), findsOneWidget);
      expect(find.byKey(const Key('edit_inventory_item_sku')), findsOneWidget);
    });
  });
}
