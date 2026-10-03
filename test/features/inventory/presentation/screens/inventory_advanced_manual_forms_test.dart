import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/custom_field_definition.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_stock_status.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/create_inventory_item_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/edit_inventory_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const adminUser = CurrentUser(
    id: 'admin_usr',
    displayName: 'Admin User',
    accountType: AccountType.admin,
    modules: {CrmModule.inventory},
    permissions: {
      CrmPermissions.inventoryView,
      CrmPermissions.inventoryCreate,
      CrmPermissions.inventoryEdit,
    },
  );

  const standardUser = CurrentUser(
    id: 'standard_usr',
    displayName: 'Standard User',
    accountType: AccountType.user,
    modules: {CrmModule.inventory},
    permissions: {
      CrmPermissions.inventoryView,
      CrmPermissions.inventoryCreate,
      CrmPermissions.inventoryEdit,
    },
  );

  const viewOnlyUser = CurrentUser(
    id: 'view_only_usr',
    displayName: 'View Only User',
    accountType: AccountType.user,
    modules: {CrmModule.inventory},
    permissions: {
      CrmPermissions.inventoryView,
    },
  );

  group('INVENTORY-7.3 Manual Create Item Tests', () {
    testWidgets('all 5 sections render for authorized user', (tester) async {
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
      expect(find.text('Product Information'), findsOneWidget);
      expect(find.text('Warehouse & Stock'), findsOneWidget);
      expect(find.text('Pricing & Commercial Details'), findsOneWidget);
      expect(find.text('Tracking & Lifecycle'), findsOneWidget);
      expect(find.text('Custom Fields'), findsOneWidget);
    });

    testWidgets('creates item with complete standard and custom fields', (tester) async {
      final repo = MockInventoryRepository(items: [], movements: []);
      await repo.saveCustomFieldDefinition(
        CustomFieldDefinition(
          id: 'def_warranty',
          key: 'warranty_months',
          label: 'Warranty Months',
          dataType: CustomFieldDataType.number,
          defaultValue: '12',
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

      // Enter product information
      await tester.enterText(find.byKey(const Key('create_inventory_item_name')), 'Enterprise Switch 48-Port');
      await tester.enterText(find.byKey(const Key('create_inventory_item_sku')), '0048-NET');
      await tester.enterText(find.byKey(const Key('inventory_form_brand')), 'Cisco Systems');
      await tester.enterText(find.byKey(const Key('inventory_form_barcode')), '8901234567890');

      // Enter storage info
      await tester.enterText(find.byKey(const Key('inventory_form_bin_location')), 'B-12-04');
      await tester.enterText(find.byKey(const Key('inventory_form_reorder_level')), '5');
      await tester.enterText(find.byKey(const Key('inventory_form_max_stock')), '20');
      await tester.enterText(find.byKey(const Key('create_inventory_item_opening_stock')), '10');

      // Enter commercial info
      await tester.enterText(find.byKey(const Key('inventory_form_supplier')), 'Cisco Direct Distributor');
      await tester.enterText(find.byKey(const Key('inventory_form_unit_cost')), '15000.50');
      await tester.enterText(find.byKey(const Key('inventory_form_selling_price')), '22500.00');
      await tester.enterText(find.byKey(const Key('inventory_form_gst_percent')), '18');

      // Enter tracking & lifecycle
      await tester.enterText(find.byKey(const Key('inventory_form_batch_number')), 'BATCH-2026-X1');
      await tester.enterText(find.byKey(const Key('inventory_form_notes')), 'Critical datacenter infrastructure switch.');

      // Enter custom field value
      await tester.enterText(find.byKey(const Key('custom_field_warranty_months')), '24');

      // Submit
      await tester.tap(find.byKey(const Key('create_inventory_item_submit')));
      await tester.pumpAndSettle();

      final page = await repo.getItems(const InventoryQuery());
      expect(page.totalItems, 1);
      final item = page.items.first;

      // Verify SKU preserves leading zero
      expect(item.item.sku, '0048-NET');
      expect(item.item.name, 'Enterprise Switch 48-Port');
      expect(item.item.brand, 'Cisco Systems');
      expect(item.item.barcode, '8901234567890');
      expect(item.item.binLocation, 'B-12-04');
      expect(item.item.reorderLevel, 5.0);
      expect(item.item.maxStock, 20.0);
      expect(item.item.supplier, 'Cisco Direct Distributor');
      expect(item.item.unitCostInr, 15000.50);
      expect(item.item.sellingPriceInr, 22500.00);
      expect(item.item.gstPercent, 18.0);
      expect(item.item.batchNumber, 'BATCH-2026-X1');
      expect(item.item.notes, 'Critical datacenter infrastructure switch.');
      expect(item.item.customFields['warranty_months'], 24);

      // Verify opening stock movement created and derived balance updated
      expect(item.quantityOnHand, 10.0);
      expect(item.stockStatus, InventoryStockStatus.inStock);
    });

    testWidgets('duplicate SKU is rejected with user friendly message', (tester) async {
      final repo = MockInventoryRepository();
      // repo already contains INV-001

      await tester.pumpWidget(
        MaterialApp(
          home: CreateInventoryItemScreen(
            user: adminUser,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('create_inventory_item_name')), 'Another Laptop');
      await tester.enterText(find.byKey(const Key('create_inventory_item_sku')), 'inv-001'); // case-insensitive duplicate

      await tester.tap(find.byKey(const Key('create_inventory_item_submit')));
      await tester.pumpAndSettle();

      expect(find.text('An item with this SKU already exists.'), findsOneWidget);
    });

    testWidgets('validation enforces max stock >= reorder level', (tester) async {
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

      await tester.enterText(find.byKey(const Key('create_inventory_item_name')), 'Test Item');
      await tester.enterText(find.byKey(const Key('create_inventory_item_sku')), 'SKU-THRESH');
      await tester.enterText(find.byKey(const Key('inventory_form_reorder_level')), '50');
      await tester.enterText(find.byKey(const Key('inventory_form_max_stock')), '20');

      await tester.tap(find.byKey(const Key('create_inventory_item_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Max stock (20.0) cannot be lower than reorder level (50.0).'), findsOneWidget);
    });

    testWidgets('sensitive cost & supplier fields are hidden for standard user', (tester) async {
      final repo = MockInventoryRepository(items: [], movements: []);

      await tester.pumpWidget(
        MaterialApp(
          home: CreateInventoryItemScreen(
            user: standardUser,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Standard user lacks inventory.cost.view and inventory.supplier.view
      expect(find.byKey(const Key('inventory_form_supplier')), findsNothing);
      expect(find.byKey(const Key('inventory_form_unit_cost')), findsNothing);
      expect(find.text('Supplier Details: Access Restricted'), findsOneWidget);
      expect(find.text('Unit Cost (INR): Access Restricted'), findsOneWidget);

      // Selling price is accessible to standard users
      expect(find.byKey(const Key('inventory_form_selling_price')), findsOneWidget);
    });
  });

  group('INVENTORY-7.3 Manual Edit Item Tests', () {
    testWidgets('pre-populates all standard and custom fields', (tester) async {
      final repo = MockInventoryRepository(
        items: [
          InventoryItem(
            id: 'item_extended_1',
            name: 'Ergonomic Desk',
            sku: '0099-DSK',
            category: 'Furniture',
            brand: 'Herman Miller',
            unit: 'pcs',
            barcode: '9988776655',
            warehouse: 'Main Warehouse',
            binLocation: 'A-01',
            reorderLevel: 2,
            maxStock: 10,
            supplier: 'Premium Office Ltd',
            unitCostInr: 45000,
            sellingPriceInr: 65000,
            gstPercent: 18,
            batchNumber: 'BATCH-DESK-99',
            isActive: true,
            notes: 'High quality adjustable desk',
            customFields: const {'eco_friendly': true, 'color': 'Walnut'},
          ),
        ],
        movements: [],
      );

      await repo.saveCustomFieldDefinition(
        CustomFieldDefinition(
          id: 'def_eco',
          key: 'eco_friendly',
          label: 'Eco Friendly',
          dataType: CustomFieldDataType.boolean,
        ),
      );
      await repo.saveCustomFieldDefinition(
        CustomFieldDefinition(
          id: 'def_color',
          key: 'color',
          label: 'Color',
          dataType: CustomFieldDataType.dropdown,
          options: const ['Walnut', 'Oak', 'White', 'Black'],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditInventoryItemScreen(
            user: adminUser,
            repository: repo,
            itemId: 'item_extended_1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Inventory Item'), findsOneWidget);
      expect(find.text('Edit Item Identity'), findsOneWidget);

      final nameField = tester.widget<TextFormField>(find.byKey(const Key('edit_inventory_item_name')));
      final skuField = tester.widget<TextFormField>(find.byKey(const Key('edit_inventory_item_sku')));
      final brandField = tester.widget<TextFormField>(find.byKey(const Key('inventory_form_brand')));

      expect(nameField.controller?.text, 'Ergonomic Desk');
      expect(skuField.controller?.text, '0099-DSK');
      expect(brandField.controller?.text, 'Herman Miller');

      // Verify read-only stock quantity display
      expect(find.text('Current Stock Quantity'), findsOneWidget);
      expect(find.text('0.0 pcs'), findsOneWidget);
      expect(find.text('Out of Stock'), findsOneWidget);

      // Verify custom field values
      final ecoSwitch = tester.widget<SwitchListTile>(find.byKey(const Key('custom_field_eco_friendly')));
      expect(ecoSwitch.value, isTrue);
    });

    testWidgets('clears nullable fields and preserves untouched fields', (tester) async {
      final repo = MockInventoryRepository(
        items: [
          InventoryItem(
            id: 'item_to_clear',
            name: 'Original Item',
            sku: 'SKU-CLR-01',
            brand: 'Original Brand',
            barcode: '12345678',
            binLocation: 'BIN-1',
            supplier: 'Original Supplier',
            unitCostInr: 100,
            sellingPriceInr: 150,
            gstPercent: 18,
            notes: 'Some notes to remove',
          ),
        ],
        movements: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditInventoryItemScreen(
            user: adminUser,
            repository: repo,
            itemId: 'item_to_clear',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear brand, barcode, and notes
      await tester.enterText(find.byKey(const Key('inventory_form_brand')), '');
      await tester.enterText(find.byKey(const Key('inventory_form_barcode')), '');
      await tester.enterText(find.byKey(const Key('inventory_form_notes')), '');

      // Update name
      await tester.enterText(find.byKey(const Key('edit_inventory_item_name')), 'Updated Item Name');

      // Save
      await tester.tap(find.byKey(const Key('edit_inventory_item_save')));
      await tester.pumpAndSettle();

      final updated = (await repo.getItemById('item_to_clear'))!;
      expect(updated.item.name, 'Updated Item Name');
      expect(updated.item.sku, 'SKU-CLR-01'); // SKU unchanged
      expect(updated.item.brand, isNull); // Cleared
      expect(updated.item.barcode, isNull); // Cleared
      expect(updated.item.notes, isNull); // Cleared
      expect(updated.item.binLocation, 'BIN-1'); // Untouched preserved
      expect(updated.item.supplier, 'Original Supplier'); // Untouched preserved
      expect(updated.item.unitCostInr, 100.0); // Untouched preserved
    });

    testWidgets('standard user editing item does NOT clear restricted cost and supplier', (tester) async {
      final repo = MockInventoryRepository(
        items: [
          InventoryItem(
            id: 'item_restricted_edit',
            name: 'Confidential Cost Item',
            sku: 'CONF-001',
            supplier: 'Top Secret Supplier',
            unitCostInr: 9999.0,
            sellingPriceInr: 15000.0,
          ),
        ],
        movements: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditInventoryItemScreen(
            user: standardUser, // lacks cost & supplier permissions
            repository: repo,
            itemId: 'item_restricted_edit',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify restricted placeholders are shown
      expect(find.text('Supplier Details: Access Restricted'), findsOneWidget);
      expect(find.text('Unit Cost (INR): Access Restricted'), findsOneWidget);

      // Edit an authorized field: name
      await tester.enterText(find.byKey(const Key('edit_inventory_item_name')), 'Renamed Item');

      // Save changes
      await tester.tap(find.byKey(const Key('edit_inventory_item_save')));
      await tester.pumpAndSettle();

      final saved = (await repo.getItemById('item_restricted_edit'))!;
      expect(saved.item.name, 'Renamed Item');
      // Crucial: Restricted fields MUST be preserved and not wiped!
      expect(saved.item.supplier, 'Top Secret Supplier');
      expect(saved.item.unitCostInr, 9999.0);
    });

    testWidgets('unauthorized user without edit permission is blocked by route guard', (tester) async {
      final repo = MockInventoryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: EditInventoryItemScreen(
            user: viewOnlyUser,
            repository: repo,
            itemId: 'item_001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.byKey(const Key('edit_inventory_item_save')), findsNothing);
    });
  });

  group('INVENTORY-7.3 Dynamic Custom Field Management Tests', () {
    testWidgets('authorized admin can add a new custom field definition via dialog', (tester) async {
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

      // Scroll to Add Custom Field button
      await tester.ensureVisible(find.byKey(const Key('inventory_add_custom_field_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_add_custom_field_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('inventory_add_custom_field_button')));
      await tester.pumpAndSettle();

      expect(find.text('Add Custom Field'), findsOneWidget);

      // Fill dialog
      await tester.enterText(find.byKey(const Key('custom_field_def_label')), 'Special Voltage');
      await tester.enterText(find.byKey(const Key('custom_field_def_key')), 'special_voltage');

      // Save definition
      await tester.tap(find.byKey(const Key('custom_field_def_save')));
      await tester.pumpAndSettle();

      // Check definition was saved in repository
      final defs = await repo.getCustomFieldDefinitions();
      expect(defs.any((d) => d.key == 'special_voltage' && d.label == 'Special Voltage'), isTrue);

      // Verify the new field appears on the screen
      await tester.ensureVisible(find.byKey(const Key('custom_field_special_voltage')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('custom_field_special_voltage')), findsOneWidget);
    });

    testWidgets('standard user without custom fields manage permission does not see Add Field button', (tester) async {
      final repo = MockInventoryRepository(items: [], movements: []);

      await tester.pumpWidget(
        MaterialApp(
          home: CreateInventoryItemScreen(
            user: standardUser,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_add_custom_field_button')), findsNothing);
    });

    testWidgets('custom field validation blocks reserved standard keys in dialog', (tester) async {
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

      await tester.ensureVisible(find.byKey(const Key('inventory_add_custom_field_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inventory_add_custom_field_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('custom_field_def_label')), 'SKU Override');
      await tester.enterText(find.byKey(const Key('custom_field_def_key')), 'sku'); // reserved!

      await tester.tap(find.byKey(const Key('custom_field_def_save')));
      await tester.pumpAndSettle();

      expect(find.text('Key "sku" is reserved for standard inventory fields.'), findsOneWidget);
    });
  });
}
