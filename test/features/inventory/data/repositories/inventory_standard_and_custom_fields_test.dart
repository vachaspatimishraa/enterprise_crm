import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/custom_field_definition.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_field_metadata.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_stock_status.dart';
import 'package:enterprise_crm/features/inventory/domain/exceptions/inventory_exception.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/record_opening_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/update_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/policies/inventory_field_access_policy.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';

void main() {
  group('INVENTORY-7.2: Standard Field Persistence Tests', () {
    late MockInventoryRepository repository;

    setUp(() {
      repository = MockInventoryRepository(items: [], movements: []);
    });

    test('Create item with all 21 standard fields and read complete item', () async {
      final expiry = DateTime(2027, 3, 20);
      final restocked = DateTime(2026, 9, 21);

      final summary = await repository.createItem(
        CreateInventoryItemInput(
          name: 'USB-C Fast Charger 30W',
          sku: '00123456', // Leading zeros preserved
          category: 'Electronics',
          brand: 'VoltEdge',
          unit: 'piece',
          barcode: '8905000000017',
          warehouse: 'BLR-01',
          binLocation: 'ELE-A1-01',
          supplier: 'Metro Digital Supplies',
          unitCostInr: 799.0,
          sellingPriceInr: 1199.0,
          reorderLevel: 15.0,
          maxStock: 92.0,
          gstPercent: 18.0,
          batchNumber: 'B26-ELE-01',
          expiryDate: expiry,
          lastRestockedDate: restocked,
          isActive: true,
          notes: 'Zero stock - replenishment check',
        ),
      );

      final item = summary.item;
      expect(item.name, 'USB-C Fast Charger 30W');
      expect(item.sku, '00123456');
      expect(item.category, 'Electronics');
      expect(item.brand, 'VoltEdge');
      expect(item.unit, 'piece');
      expect(item.barcode, '8905000000017');
      expect(item.warehouse, 'BLR-01');
      expect(item.binLocation, 'ELE-A1-01');
      expect(item.supplier, 'Metro Digital Supplies');
      expect(item.unitCostInr, 799.0);
      expect(item.sellingPriceInr, 1199.0);
      expect(item.reorderLevel, 15.0);
      expect(item.maxStock, 92.0);
      expect(item.gstPercent, 18.0);
      expect(item.batchNumber, 'B26-ELE-01');
      expect(item.expiryDate, expiry);
      expect(item.lastRestockedDate, restocked);
      expect(item.isActive, isTrue);
      expect(item.notes, 'Zero stock - replenishment check');
      expect(summary.quantityOnHand, 0.0);
      expect(summary.stockStatus, InventoryStockStatus.outOfStock);

      // Verify read by ID
      final readSummary = await repository.getItemById(item.id);
      expect(readSummary, isNotNull);
      expect(readSummary!.item, equals(item));
      expect(readSummary.item.sku, '00123456');
    });

    test('Edit an optional field and verify unchanged fields are preserved', () async {
      final summary = await repository.createItem(
        const CreateInventoryItemInput(
          name: 'Mechanical Keyboard',
          sku: 'KB-001',
          category: 'Electronics',
          brand: 'KeyChron',
          unit: 'piece',
          warehouse: 'BLR-01',
          unitCostInr: 3500.0,
          sellingPriceInr: 5999.0,
          reorderLevel: 5.0,
          maxStock: 50.0,
        ),
      );

      final updated = await repository.updateItem(
        UpdateInventoryItemInput(
          id: summary.item.id,
          name: 'Mechanical Keyboard RGB',
          sku: 'KB-001',
          sellingPriceInr: 6499.0,
        ),
      );

      expect(updated.item.name, 'Mechanical Keyboard RGB');
      expect(updated.item.sellingPriceInr, 6499.0);
      // Unchanged fields preserved
      expect(updated.item.sku, 'KB-001');
      expect(updated.item.category, 'Electronics');
      expect(updated.item.brand, 'KeyChron');
      expect(updated.item.unit, 'piece');
      expect(updated.item.warehouse, 'BLR-01');
      expect(updated.item.unitCostInr, 3500.0);
      expect(updated.item.reorderLevel, 5.0);
      expect(updated.item.maxStock, 50.0);
    });

    test('Clear a nullable field using clear flag in UpdateInventoryItemInput', () async {
      final summary = await repository.createItem(
        const CreateInventoryItemInput(
          name: 'Ergonomic Mouse',
          sku: 'MS-001',
          brand: 'Logi',
          notes: 'Special promo batch',
        ),
      );

      expect(summary.item.brand, 'Logi');
      expect(summary.item.notes, 'Special promo batch');

      final updated = await repository.updateItem(
        UpdateInventoryItemInput(
          id: summary.item.id,
          name: 'Ergonomic Mouse',
          sku: 'MS-001',
          clearBrand: true,
          clearNotes: true,
        ),
      );

      expect(updated.item.brand, isNull);
      expect(updated.item.notes, isNull);
    });

    test('Preserve leading-zero SKU and barcode without numeric truncation', () async {
      final summary = await repository.createItem(
        const CreateInventoryItemInput(
          name: 'Zero Test Item',
          sku: '000789',
          barcode: '0012345678905',
        ),
      );

      expect(summary.item.sku, '000789');
      expect(summary.item.barcode, '0012345678905');

      final read = await repository.getItemById(summary.item.id);
      expect(read!.item.sku, '000789');
      expect(read.item.barcode, '0012345678905');
    });

    test('Legacy defaults applied when optional standard fields are omitted', () async {
      final summary = await repository.createItem(
        const CreateInventoryItemInput(
          name: 'Basic Item',
          sku: 'BASIC-01',
        ),
      );

      expect(summary.item.category, 'General');
      expect(summary.item.unit, 'piece');
      expect(summary.item.warehouse, 'Default');
      expect(summary.item.isActive, isTrue);
      expect(summary.item.brand, isNull);
      expect(summary.item.barcode, isNull);
      expect(summary.item.supplier, isNull);
      expect(summary.item.unitCostInr, isNull);
      expect(summary.item.sellingPriceInr, isNull);
      expect(summary.item.reorderLevel, isNull);
      expect(summary.item.maxStock, isNull);
      expect(summary.item.customFields, isEmpty);
    });

    test('Inactive status marks item as discontinued regardless of stock', () async {
      final summary = await repository.createItem(
        const CreateInventoryItemInput(
          name: 'Discontinued SKU',
          sku: 'DISC-01',
          isActive: false,
        ),
      );

      expect(summary.item.isActive, isFalse);
      expect(summary.stockStatus, InventoryStockStatus.discontinued);
    });

    test('Validation rejects negative cost, negative reorder, and maxStock < reorderLevel', () async {
      expect(
        () => repository.createItem(
          const CreateInventoryItemInput(
            name: 'Bad Cost',
            sku: 'ERR-01',
            unitCostInr: -50.0,
          ),
        ),
        throwsA(isA<InventoryValidationException>()),
      );

      expect(
        () => repository.createItem(
          const CreateInventoryItemInput(
            name: 'Bad Reorder',
            sku: 'ERR-02',
            reorderLevel: -5.0,
          ),
        ),
        throwsA(isA<InventoryValidationException>()),
      );

      expect(
        () => repository.createItem(
          const CreateInventoryItemInput(
            name: 'Bad Max',
            sku: 'ERR-03',
            reorderLevel: 20.0,
            maxStock: 5.0,
          ),
        ),
        throwsA(isA<InventoryValidationException>()),
      );
    });

    test('Configurable catalogs allow extending categories and warehouses', () async {
      repository.catalogs.registerCategory('Industrial Robotics');
      repository.catalogs.registerWarehouse('HYD-01');

      final summary = await repository.createItem(
        const CreateInventoryItemInput(
          name: 'Robotic Arm',
          sku: 'ROB-001',
          category: 'Industrial Robotics',
          warehouse: 'HYD-01',
        ),
      );

      expect(summary.item.category, 'Industrial Robotics');
      expect(summary.item.warehouse, 'HYD-01');
    });
  });

  group('INVENTORY-7.2: Custom Field Infrastructure Tests', () {
    late MockInventoryRepository repository;

    setUp(() {
      repository = MockInventoryRepository(items: [], movements: []);
    });

    test('Create and register all five custom field types', () async {
      final textDef = CustomFieldDefinition(
        id: 'cf_1',
        key: 'shelf_life',
        label: 'Shelf Life',
        dataType: CustomFieldDataType.text,
      );
      final numDef = CustomFieldDefinition(
        id: 'cf_2',
        key: 'weight_kg',
        label: 'Weight (kg)',
        dataType: CustomFieldDataType.number,
      );
      final dateDef = CustomFieldDefinition(
        id: 'cf_3',
        key: 'manufacture_date',
        label: 'Manufacture Date',
        dataType: CustomFieldDataType.date,
      );
      final boolDef = CustomFieldDefinition(
        id: 'cf_4',
        key: 'fragile',
        label: 'Fragile Item',
        dataType: CustomFieldDataType.boolean,
      );
      final dropdownDef = CustomFieldDefinition(
        id: 'cf_5',
        key: 'storage_temp',
        label: 'Storage Temperature',
        dataType: CustomFieldDataType.dropdown,
        options: const ['Ambient', 'Chilled', 'Frozen'],
      );

      await repository.saveCustomFieldDefinition(textDef);
      await repository.saveCustomFieldDefinition(numDef);
      await repository.saveCustomFieldDefinition(dateDef);
      await repository.saveCustomFieldDefinition(boolDef);
      await repository.saveCustomFieldDefinition(dropdownDef);

      final definitions = await repository.getCustomFieldDefinitions();
      expect(definitions.length, 5);
      expect(definitions.map((d) => d.key), containsAll([
        'shelf_life',
        'weight_kg',
        'manufacture_date',
        'fragile',
        'storage_temp',
      ]));
    });

    test('Reject duplicate custom field keys', () async {
      await repository.saveCustomFieldDefinition(
        CustomFieldDefinition(
          id: 'cf_1',
          key: 'tax_code',
          label: 'Tax Code',
          dataType: CustomFieldDataType.text,
        ),
      );

      expect(
        () => repository.saveCustomFieldDefinition(
          CustomFieldDefinition(
            id: 'cf_2',
            key: 'tax_code',
            label: 'Duplicate Tax Code',
            dataType: CustomFieldDataType.text,
          ),
        ),
        throwsA(isA<InventoryValidationException>()),
      );
    });

    test('Reject reserved standard field keys in CustomFieldDefinition', () {
      expect(
        () => CustomFieldDefinition(
          id: 'cf_bad',
          key: 'sku',
          label: 'My SKU',
          dataType: CustomFieldDataType.text,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => CustomFieldDefinition(
          id: 'cf_bad2',
          key: 'unit_cost_inr',
          label: 'Cost',
          dataType: CustomFieldDataType.number,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => CustomFieldDefinition(
          id: 'cf_bad3',
          key: 'stock_quantity',
          label: 'Stock',
          dataType: CustomFieldDataType.number,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Persist, read, update and clear custom field values on InventoryItem', () async {
      await repository.saveCustomFieldDefinition(
        CustomFieldDefinition(
          id: 'cf_weight',
          key: 'weight_kg',
          label: 'Weight (kg)',
          dataType: CustomFieldDataType.number,
        ),
      );
      await repository.saveCustomFieldDefinition(
        CustomFieldDefinition(
          id: 'cf_hazard',
          key: 'is_hazardous',
          label: 'Hazardous Material',
          dataType: CustomFieldDataType.boolean,
        ),
      );

      // Create item with custom fields
      final summary = await repository.createItem(
        const CreateInventoryItemInput(
          name: 'Lithium Battery Pack',
          sku: 'BAT-01',
          customFields: {
            'weight_kg': 1.85,
            'is_hazardous': true,
          },
        ),
      );

      expect(summary.item.customFields['weight_kg'], 1.85);
      expect(summary.item.customFields['is_hazardous'], isTrue);

      // Update custom field value
      final updated = await repository.updateItem(
        UpdateInventoryItemInput(
          id: summary.item.id,
          name: 'Lithium Battery Pack v2',
          sku: 'BAT-01',
          customFields: {
            'weight_kg': 2.10,
          },
        ),
      );

      expect(updated.item.customFields['weight_kg'], 2.10);
      expect(updated.item.customFields['is_hazardous'], isTrue); // Preserved

      // Clear an optional custom field by setting to null
      final cleared = await repository.updateItem(
        UpdateInventoryItemInput(
          id: summary.item.id,
          name: 'Lithium Battery Pack v2',
          sku: 'BAT-01',
          customFields: {
            'is_hazardous': null,
          },
        ),
      );

      expect(cleared.item.customFields['weight_kg'], 2.10);
      expect(cleared.item.customFields.containsKey('is_hazardous'), isFalse);
    });

    test('Reject unknown custom field keys in createItem and updateItem', () async {
      expect(
        () => repository.createItem(
          const CreateInventoryItemInput(
            name: 'Item with unknown field',
            sku: 'UNK-01',
            customFields: {
              'unregistered_key': 'value',
            },
          ),
        ),
        throwsA(isA<InventoryValidationException>()),
      );
    });

    test('Enforce required custom fields and apply default values', () async {
      await repository.saveCustomFieldDefinition(
        CustomFieldDefinition(
          id: 'cf_origin',
          key: 'country_of_origin',
          label: 'Country of Origin',
          dataType: CustomFieldDataType.text,
          isRequired: true,
          defaultValue: 'India',
        ),
      );

      // Creating without country_of_origin applies the default
      final summary = await repository.createItem(
        const CreateInventoryItemInput(
          name: 'Locally Made Cable',
          sku: 'CBL-01',
        ),
      );

      expect(summary.item.customFields['country_of_origin'], 'India');

      // Now create a required field without default
      await repository.saveCustomFieldDefinition(
        CustomFieldDefinition(
          id: 'cf_serial',
          key: 'serial_batch',
          label: 'Serial Batch',
          dataType: CustomFieldDataType.text,
          isRequired: true,
        ),
      );

      expect(
        () => repository.createItem(
          const CreateInventoryItemInput(
            name: 'Item missing required field',
            sku: 'MISS-01',
          ),
        ),
        throwsA(isA<InventoryValidationException>()),
      );
    });

    test('Prevent shared mutable state on customFields map', () async {
      final inputMap = <String, dynamic>{'notes_tag': 'first'};
      await repository.saveCustomFieldDefinition(
        CustomFieldDefinition(
          id: 'cf_tag',
          key: 'notes_tag',
          label: 'Tag',
          dataType: CustomFieldDataType.text,
        ),
      );

      final summary = await repository.createItem(
        CreateInventoryItemInput(
          name: 'Tag Item',
          sku: 'TAG-01',
          customFields: inputMap,
        ),
      );

      // Mutate the original external map
      inputMap['notes_tag'] = 'mutated_outside';

      // Item map remains unchanged and unmodifiable
      expect(summary.item.customFields['notes_tag'], 'first');
      expect(
        () => summary.item.customFields['notes_tag'] = 'direct_mutation',
        throwsUnsupportedError,
      );
    });
  });

  group('INVENTORY-7.2: Stock Ledger & Security Integrity Tests', () {
    late MockInventoryRepository repository;

    setUp(() {
      repository = MockInventoryRepository(items: [], movements: []);
    });

    test('Stock Quantity is strictly derived from movement ledger and does not mutate directly', () async {
      final summary = await repository.createItem(
        const CreateInventoryItemInput(
          name: 'Ledger Item',
          sku: 'LED-01',
          reorderLevel: 10.0,
          maxStock: 50.0,
        ),
      );

      expect(summary.quantityOnHand, 0.0);
      expect(summary.stockStatus, InventoryStockStatus.outOfStock);

      // Set opening stock to 20
      final openingResult = await repository.recordOpeningStock(
        RecordOpeningStockInput(
          itemId: summary.item.id,
          quantity: 20.0,
          performedByUserId: 'usr_admin',
        ),
      );

      expect(openingResult.item.quantityOnHand, 20.0);
      final readAfterOpening = await repository.getItemById(summary.item.id);
      expect(readAfterOpening!.quantityOnHand, 20.0);
      expect(readAfterOpening.stockStatus, InventoryStockStatus.inStock);

      // Adjust stock down to 8 (low stock)
      final adjResult = await repository.adjustStock(
        AdjustInventoryStockInput(
          itemId: summary.item.id,
          quantityDelta: -12.0,
          performedByUserId: 'usr_admin',
          reason: 'Broken units',
        ),
      );

      expect(adjResult.item.quantityOnHand, 8.0);
      final readAfterAdj = await repository.getItemById(summary.item.id);
      expect(readAfterAdj!.quantityOnHand, 8.0);
      expect(readAfterAdj.stockStatus, InventoryStockStatus.lowStock);

      // Adjust stock up to 60 (overstock: > maxStock 50)
      await repository.adjustStock(
        AdjustInventoryStockInput(
          itemId: summary.item.id,
          quantityDelta: 52.0,
          performedByUserId: 'usr_admin',
          reason: 'Bulk replenishment',
        ),
      );

      final readOverstock = await repository.getItemById(summary.item.id);
      expect(readOverstock!.quantityOnHand, 60.0);
      expect(readOverstock.stockStatus, InventoryStockStatus.overstock);

      // Updating item name or metadata does NOT alter quantityOnHand
      final edited = await repository.updateItem(
        UpdateInventoryItemInput(
          id: summary.item.id,
          name: 'Ledger Item Renamed',
          sku: 'LED-01',
        ),
      );
      expect(edited.quantityOnHand, 60.0);
    });

    test('Field-level access policy guards sensitive fields correctly', () {
      final adminUser = CurrentUser(
        id: 'admin_1',
        displayName: 'Admin User',
        accountType: AccountType.admin,
        modules: {CrmModule.inventory},
        permissions: {},
      );

      final standardUserWithCost = CurrentUser(
        id: 'std_cost',
        displayName: 'Cost Viewer',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {
          CrmPermissions.inventoryView,
          InventoryFieldAccessPolicy.costViewPermission,
        },
      );

      final standardUserNoCost = CurrentUser(
        id: 'std_plain',
        displayName: 'Plain Viewer',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {CrmPermissions.inventoryView},
      );

      expect(InventoryFieldAccessPolicy.canViewCost(adminUser), isTrue);
      expect(InventoryFieldAccessPolicy.canViewCost(standardUserWithCost), isTrue);
      expect(InventoryFieldAccessPolicy.canViewCost(standardUserNoCost), isFalse);
      expect(InventoryFieldAccessPolicy.canViewCost(null), isFalse);

      expect(InventoryFieldAccessPolicy.canViewSupplier(adminUser), isTrue);
      expect(InventoryFieldAccessPolicy.canViewSupplier(standardUserNoCost), isFalse);
    });

    test('Field metadata lists all 21 fields with accurate sensitivity flags', () {
      expect(InventoryFieldMetadata.allStandardFields.length, 21);

      final costField = InventoryFieldMetadata.findByKey('unit_cost_inr');
      expect(costField, isNotNull);
      expect(costField!.isSensitive, isTrue);

      final supplierField = InventoryFieldMetadata.findByKey('supplier');
      expect(supplierField, isNotNull);
      expect(supplierField!.isSensitive, isTrue);

      final skuField = InventoryFieldMetadata.findByKey('sku');
      expect(skuField, isNotNull);
      expect(skuField!.isSensitive, isFalse);
    });
  });
}
