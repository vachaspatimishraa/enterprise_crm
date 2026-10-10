import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const admin = CurrentUser(
    id: 'admin_test',
    displayName: 'Admin User',
    accountType: AccountType.admin,
    modules: {CrmModule.inventory},
    permissions: {},
  );

  Widget createTestWidget(MockInventoryRepository repo) {
    return MaterialApp(
      home: InventoryWorkspaceScreen(
        user: admin,
        repository: repo,
        currentUserProvider: () => admin,
      ),
    );
  }

  group('Inventory Dynamic Template Grid & 2D Scrolling Tests (Phase 1)', () {
    testWidgets('renders strict column hierarchy with #, Product Name, and SKU headers', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockInventoryRepository(
        items: [
          InventoryItem(
            id: 'item_01',
            name: 'Alpha Widget',
            sku: 'AW-01',
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_items_table')), findsOneWidget);
      expect(find.text('#'), findsOneWidget);
      expect(find.text('Product Name'), findsOneWidget);
      expect(find.text('SKU'), findsOneWidget);
      expect(find.text('Alpha Widget'), findsOneWidget);
      expect(find.text('AW-01'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('dynamic column visibility: hides Barcode when absent in dataset', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repoWithoutBarcode = MockInventoryRepository(
        items: [
          InventoryItem(
            id: 'item_01',
            name: 'Item Without Barcode',
            sku: 'SKU-01',
            barcode: null,
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(repoWithoutBarcode));
      await tester.pumpAndSettle();

      expect(find.text('Barcode'), findsNothing);
    });

    testWidgets('dynamic column visibility: shows Barcode when present in dataset', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repoWithBarcode = MockInventoryRepository(
        items: [
          InventoryItem(
            id: 'item_01',
            name: 'Item With Barcode',
            sku: 'SKU-01',
            barcode: '8901234567890',
          ),
          InventoryItem(
            id: 'item_02',
            name: 'Item Without Barcode',
            sku: 'SKU-02',
            barcode: null,
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(repoWithBarcode));
      await tester.pumpAndSettle();

      expect(find.text('Barcode'), findsOneWidget);
      expect(find.text('8901234567890'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('dynamic column visibility: auto-displays custom fields with title-cased headers', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockInventoryRepository(
        items: [
          InventoryItem(
            id: 'item_01',
            name: 'Pro Laptop',
            sku: 'PL-01',
            customFields: {
              'warranty_period': '3 Years',
              'color': 'Midnight Blue',
            },
          ),
          InventoryItem(
            id: 'item_02',
            name: 'Basic Mouse',
            sku: 'BM-02',
            customFields: {
              'color': 'Black',
            },
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(repo));
      await tester.pumpAndSettle();

      expect(find.text('Warranty Period'), findsOneWidget);
      expect(find.text('Color'), findsOneWidget);
      expect(find.text('3 Years'), findsOneWidget);
      expect(find.text('Midnight Blue'), findsOneWidget);
      expect(find.text('Black'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('header select-all checkbox toggles all workspace row selections', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockInventoryRepository(
        items: [
          InventoryItem(id: 'item_01', name: 'Item 1', sku: 'SKU-01'),
          InventoryItem(id: 'item_02', name: 'Item 2', sku: 'SKU-02'),
        ],
      );

      await tester.pumpWidget(createTestWidget(repo));
      await tester.pumpAndSettle();

      final selectAllCheckbox = find.byKey(const Key('inventory_select_all_checkbox'));
      expect(selectAllCheckbox, findsOneWidget);

      await tester.tap(selectAllCheckbox);
      await tester.pumpAndSettle();

      final cb1 = tester.widget<Checkbox>(find.byKey(const Key('inventory_item_select_item_01')));
      final cb2 = tester.widget<Checkbox>(find.byKey(const Key('inventory_item_select_item_02')));
      expect(cb1.value, isTrue);
      expect(cb2.value, isTrue);

      await tester.tap(selectAllCheckbox);
      await tester.pumpAndSettle();

      final cb1Unchecked = tester.widget<Checkbox>(find.byKey(const Key('inventory_item_select_item_01')));
      final cb2Unchecked = tester.widget<Checkbox>(find.byKey(const Key('inventory_item_select_item_02')));
      expect(cb1Unchecked.value, isFalse);
      expect(cb2Unchecked.value, isFalse);
    });

    testWidgets('scrollbars support 2D scrolling for wide templates', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockInventoryRepository();

      await tester.pumpWidget(createTestWidget(repo));
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsWidgets);
    });
  });
}
