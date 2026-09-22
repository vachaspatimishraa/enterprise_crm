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
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/create_inventory_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TrackingInventoryRepository implements InventoryRepository {
  final Future<InventoryItemSummary> Function(CreateInventoryItemInput)?
  onCreate;
  int createCalls = 0;

  _TrackingInventoryRepository({this.onCreate});

  @override
  Future<InventoryPage> getItems(InventoryQuery query) =>
      throw UnimplementedError();

  @override
  Future<InventoryItemSummary?> getItemById(String id) =>
      throw UnimplementedError();

  @override
  Future<InventoryItemSummary> createItem(CreateInventoryItemInput input) {
    createCalls++;
    if (onCreate != null) {
      return onCreate!(input);
    }
    return MockInventoryRepository().createItem(input);
  }

  @override
  Future<InventoryItemSummary> updateItem(UpdateInventoryItemInput input) =>
      throw UnimplementedError();
}

void main() {
  group('CreateInventoryItemScreen Widget Tests', () {
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
      ThemeMode themeMode = ThemeMode.light,
    }) {
      return MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: themeMode,
        home: CreateInventoryItemScreen(
          user: user ?? adminUser,
          repository: repository ?? MockInventoryRepository(),
        ),
      );
    }

    testWidgets('renders form fields, labels, and action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Add Inventory Item'), findsOneWidget);
      expect(
        find.byKey(const Key('create_inventory_item_name')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('create_inventory_item_sku')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('create_inventory_item_cancel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('create_inventory_item_cancel_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('create_inventory_item_submit')),
        findsOneWidget,
      );
      expect(find.text('Create Item'), findsOneWidget);

      // Verify no quantity, warehouse, price, tax, or movement controls exist
      expect(find.text('Quantity'), findsNothing);
      expect(find.text('Opening Stock'), findsNothing);
      expect(find.text('Price'), findsNothing);
      expect(find.text('Tax'), findsNothing);
    });

    testWidgets('Cancel navigation pop works', (tester) async {
      bool popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => CreateInventoryItemScreen(
                      user: adminUser,
                      repository: MockInventoryRepository(),
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

      expect(find.text('Add Inventory Item'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('create_inventory_item_cancel_button')),
      );
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });

    testWidgets('validates required name field', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('create_inventory_item_sku')),
        'SKU-001',
      );
      await tester.tap(find.byKey(const Key('create_inventory_item_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Item name is required.'), findsOneWidget);
    });

    testWidgets('validates required SKU field', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('create_inventory_item_name')),
        'Valid Item',
      );
      await tester.tap(find.byKey(const Key('create_inventory_item_submit')));
      await tester.pumpAndSettle();

      expect(find.text('SKU is required.'), findsOneWidget);
    });

    testWidgets('displays snackbar on duplicate SKU error', (tester) async {
      final repo = MockInventoryRepository();
      await tester.pumpWidget(createWidget(repository: repo));
      await tester.pumpAndSettle();

      // INV-001 exists in seed data
      await tester.enterText(
        find.byKey(const Key('create_inventory_item_name')),
        'Laptop Stand Duplicate',
      );
      await tester.enterText(
        find.byKey(const Key('create_inventory_item_sku')),
        'inv-001',
      );
      await tester.tap(find.byKey(const Key('create_inventory_item_submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('An item with this SKU already exists.'),
        findsOneWidget,
      );
    });

    testWidgets('successful create pops route with true result', (
      tester,
    ) async {
      bool? poppedResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                poppedResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => CreateInventoryItemScreen(
                      user: adminUser,
                      repository: MockInventoryRepository(),
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
        find.byKey(const Key('create_inventory_item_name')),
        'Brand New Monitor',
      );
      await tester.enterText(
        find.byKey(const Key('create_inventory_item_sku')),
        'MON-999',
      );
      await tester.tap(find.byKey(const Key('create_inventory_item_submit')));
      await tester.pumpAndSettle();

      expect(poppedResult, isTrue);
      expect(find.text('Add Inventory Item'), findsNothing);
    });

    testWidgets('handles general repository failure safely with snackbar', (
      tester,
    ) async {
      final repo = _TrackingInventoryRepository(
        onCreate: (_) => throw Exception('Network timeout'),
      );
      await tester.pumpWidget(createWidget(repository: repo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('create_inventory_item_name')),
        'Item Name',
      );
      await tester.enterText(
        find.byKey(const Key('create_inventory_item_sku')),
        'SKU-NEW',
      );
      await tester.tap(find.byKey(const Key('create_inventory_item_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Unable to create inventory item.'), findsOneWidget);
    });

    testWidgets(
      'button is disabled during submission and prevents double-submit',
      (tester) async {
        final completer = Completer<InventoryItemSummary>();
        final repo = _TrackingInventoryRepository(
          onCreate: (_) => completer.future,
        );

        await tester.pumpWidget(createWidget(repository: repo));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('create_inventory_item_name')),
          'Unique Widget',
        );
        await tester.enterText(
          find.byKey(const Key('create_inventory_item_sku')),
          'UW-001',
        );

        // First submit
        await tester.tap(find.byKey(const Key('create_inventory_item_submit')));
        await tester.pump(); // Start async action

        expect(find.text('Creating...'), findsOneWidget);
        expect(repo.createCalls, 1);

        // Attempt second submit while submitting
        await tester.tap(
          find.byKey(const Key('create_inventory_item_submit')),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(repo.createCalls, 1);

        // Complete async
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
        expect(
          find.byKey(const Key('create_inventory_item_submit')),
          findsNothing,
        );
        expect(repo.createCalls, 0);
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

            expect(find.text('Add Inventory Item'), findsOneWidget);
            expect(
              find.byKey(const Key('create_inventory_item_name')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('create_inventory_item_sku')),
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

      expect(find.text('Add Inventory Item'), findsOneWidget);
      expect(
        find.byKey(const Key('create_inventory_item_name')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('create_inventory_item_sku')),
        findsOneWidget,
      );
    });
  });
}
