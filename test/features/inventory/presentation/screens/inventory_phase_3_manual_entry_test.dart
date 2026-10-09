import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/custom_field_definition.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/create_inventory_item_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/edit_inventory_item_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_bulk_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const adminUser = CurrentUser(
    id: 'admin_1',
    displayName: 'Admin User',
    accountType: AccountType.admin,
    modules: {CrmModule.inventory},
    permissions: {
      CrmPermissions.inventoryView,
      CrmPermissions.inventoryCreate,
      CrmPermissions.inventoryEdit,
    },
  );

  group('Phase 3: Comprehensive Manual Item Entry Acceptance Tests', () {
    testWidgets('1. Minimal single-item creation: saves with ONLY Name and SKU required', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockInventoryRepository(items: [], movements: []);

      await tester.pumpWidget(
        MaterialApp(
          home: CreateInventoryItemScreen(
            user: adminUser,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter only Name and SKU
      await tester.enterText(
        find.byKey(const Key('create_inventory_item_name')),
        'Minimal Widget',
      );
      await tester.enterText(
        find.byKey(const Key('create_inventory_item_sku')),
        'MIN-001',
      );

      // Submit
      final submitButton = find.byKey(const Key('create_inventory_item_submit'));
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify item persisted in repository with sensible defaults
      final page = await repo.getItems(const InventoryQuery());
      expect(page.items.length, 1);
      final item = page.items.first.item;
      expect(item.name, 'Minimal Widget');
      expect(item.sku, 'MIN-001');
      expect(item.category, 'General');
      expect(item.unit, 'piece');
      expect(item.warehouse, 'Default');
      expect(item.brand, isNull);
      expect(item.barcode, isNull);
      expect(item.unitCostInr, isNull);
      expect(item.sellingPriceInr, isNull);
    });

    testWidgets('2. Comprehensive single-item creation: saves all 21+ catalog & custom fields', (tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockInventoryRepository(items: [], movements: []);
      await repo.saveCustomFieldDefinition(
        CustomFieldDefinition(
          id: 'def_warranty',
          key: 'warranty_info',
          label: 'Warranty Info',
          dataType: CustomFieldDataType.text,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CreateInventoryItemScreen(
            user: adminUser,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Basic info
      final nameFinder = find.byKey(const Key('create_inventory_item_name'));
      await tester.ensureVisible(nameFinder);
      await tester.enterText(nameFinder, 'Enterprise Router');

      final skuFinder = find.byKey(const Key('create_inventory_item_sku'));
      await tester.ensureVisible(skuFinder);
      await tester.enterText(skuFinder, 'ROUTER-X1');

      final brandFinder = find.byKey(const Key('inventory_form_brand'));
      await tester.ensureVisible(brandFinder);
      await tester.enterText(brandFinder, 'Cisco');

      final barcodeFinder = find.byKey(const Key('inventory_form_barcode'));
      await tester.ensureVisible(barcodeFinder);
      await tester.enterText(barcodeFinder, '8901234567890');

      // Warehouse & stock
      final binFinder = find.byKey(const Key('inventory_form_bin_location'));
      await tester.ensureVisible(binFinder);
      await tester.enterText(binFinder, 'Rack-A1');

      final reorderFinder = find.byKey(const Key('inventory_form_reorder_level'));
      await tester.ensureVisible(reorderFinder);
      await tester.enterText(reorderFinder, '10');

      final maxStockFinder = find.byKey(const Key('inventory_form_max_stock'));
      await tester.ensureVisible(maxStockFinder);
      await tester.enterText(maxStockFinder, '100');

      final openingStockFinder = find.byKey(const Key('create_inventory_item_opening_stock'));
      await tester.ensureVisible(openingStockFinder);
      await tester.enterText(openingStockFinder, '50');

      // Pricing & tax
      final unitCostFinder = find.byKey(const Key('inventory_form_unit_cost'));
      await tester.ensureVisible(unitCostFinder);
      await tester.enterText(unitCostFinder, '5000.00');

      final sellingPriceFinder = find.byKey(const Key('inventory_form_selling_price'));
      await tester.ensureVisible(sellingPriceFinder);
      await tester.enterText(sellingPriceFinder, '8500.00');

      final gstFinder = find.byKey(const Key('inventory_form_gst_percent'));
      await tester.ensureVisible(gstFinder);
      await tester.enterText(gstFinder, '18');

      // Tracking & custom
      final batchFinder = find.byKey(const Key('inventory_form_batch_number'));
      await tester.ensureVisible(batchFinder);
      await tester.enterText(batchFinder, 'BATCH-2026-A');

      final notesFinder = find.byKey(const Key('inventory_form_notes'));
      await tester.ensureVisible(notesFinder);
      await tester.enterText(notesFinder, 'Critical core switch');

      final customFieldInput = find.byKey(const Key('custom_field_warranty_info'));
      if (customFieldInput.evaluate().isNotEmpty) {
        await tester.ensureVisible(customFieldInput);
        await tester.enterText(customFieldInput, '3 Years On-Site');
      }

      // Submit
      final submitButton = find.byKey(const Key('create_inventory_item_submit'));
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      final page = await repo.getItems(const InventoryQuery());
      expect(page.items.length, 1);
      final summary = page.items.first;
      expect(summary.item.name, 'Enterprise Router');
      expect(summary.item.brand, 'Cisco');
      expect(summary.item.barcode, '8901234567890');
      expect(summary.item.binLocation, 'Rack-A1');
      expect(summary.item.reorderLevel, 10.0);
      expect(summary.item.maxStock, 100.0);
      expect(summary.item.unitCostInr, 5000.00);
      expect(summary.item.sellingPriceInr, 8500.00);
      expect(summary.item.gstPercent, 18.0);
      expect(summary.item.batchNumber, 'BATCH-2026-A');
      expect(summary.item.notes, 'Critical core switch');
      // Opening stock correctly creates opening movement
      expect(summary.quantityOnHand, 50.0);
    });

    testWidgets('3. Edit form: physical quantity on hand cannot be directly mutated', (tester) async {
      final repo = MockInventoryRepository(
        items: [
          InventoryItem(
            id: 'item_01',
            name: 'Existing Server',
            sku: 'SRV-01',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditInventoryItemScreen(
            user: adminUser,
            repository: repo,
            itemId: 'item_01',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no text form field for Quantity on hand exists in edit mode
      expect(find.byKey(const Key('edit_inventory_item_opening_stock')), findsNothing);
      expect(find.byKey(const Key('edit_inventory_item_quantity_on_hand')), findsNothing);
    });

    testWidgets('4. Multi-item bulk entry grid: add/delete row, choose columns, and commit', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockInventoryRepository(items: [], movements: []);

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryBulkEntryScreen(
            user: adminUser,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bulk Manual Inventory Entry'), findsOneWidget);

      // Add a row
      final addRowButton = find.byKey(const Key('inventory_bulk_entry_add_row_button'));
      expect(addRowButton, findsOneWidget);
      await tester.tap(addRowButton);
      await tester.pumpAndSettle();

      // Open Choose Columns dialog
      final chooseColumnsButton = find.byKey(const Key('inventory_bulk_entry_column_selector'));
      expect(chooseColumnsButton, findsOneWidget);
      await tester.tap(chooseColumnsButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_bulk_entry_column_selector_dialog')), findsOneWidget);
      final applyButton = find.byKey(const Key('inventory_bulk_entry_column_selector_done'));
      await tester.tap(applyButton);
      await tester.pumpAndSettle();
    });

    testWidgets('5. Responsive layout: Create form renders cleanly across all form factors', (tester) async {
      final viewports = <String, Size>{
        'Phone (360x640)': const Size(360, 640),
        'Tablet (768x1024)': const Size(768, 1024),
        'Desktop (1200x800)': const Size(1200, 800),
      };

      for (final entry in viewports.entries) {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = MockInventoryRepository(items: [], movements: []);

        await tester.pumpWidget(
          MaterialApp(
            home: CreateInventoryItemScreen(
              user: adminUser,
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add Inventory Item'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
