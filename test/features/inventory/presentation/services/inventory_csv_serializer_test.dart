import 'package:enterprise_crm/features/inventory/domain/entities/custom_field_definition.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_fields.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_csv_serializer.dart';

void main() {
  late InventoryCsvSerializer serializer;

  setUp(() {
    serializer = const InventoryCsvSerializer();
  });

  group('InventoryCsvSerializer Unit & Security Tests', () {
    test('produces valid header row when items list is empty', () {
      final csvString = serializer.convertToString([]);
      expect(csvString.trim(), equals('Item Name,SKU,Current Quantity'));

      final bytes = serializer.convertToBytes([]);
      final decoded = utf8.decode(bytes).trim();
      expect(decoded, equals('Item Name,SKU,Current Quantity'));
    });

    test('serializes single item with 3 columns and correct quantity formatting', () {
      final item = InventoryItem(id: '1', name: 'Wireless Mouse', sku: 'INV-001');
      final summary = InventoryItemSummary(item: item, quantityOnHand: 75.0);

      final csvString = serializer.convertToString([summary]);
      expect(csvString, contains('Item Name,SKU,Current Quantity'));
      expect(csvString, contains('Wireless Mouse,INV-001,75'));
    });

    test('preserves fractional quantities accurately without arbitrary rounding', () {
      final item = InventoryItem(id: '1', name: 'Cable', sku: 'CBL-01');
      final summary = InventoryItemSummary(item: item, quantityOnHand: 12.375);

      final csvString = serializer.convertToString([summary]);
      expect(csvString, contains('Cable,CBL-01,12.375'));
    });

    test('escapes commas, quotes, and newlines standardly', () {
      final item1 = InventoryItem(id: '1', name: 'Mouse, Wireless', sku: 'SKU,1');
      final item2 = InventoryItem(id: '2', name: '12" Monitor', sku: 'MON-"12"');
      final item3 = InventoryItem(id: '3', name: 'Keyboard\nMechanical', sku: 'KBD\n01');

      final list = [
        InventoryItemSummary(item: item1, quantityOnHand: 10.0),
        InventoryItemSummary(item: item2, quantityOnHand: 5.0),
        InventoryItemSummary(item: item3, quantityOnHand: 2.0),
      ];

      final csvString = serializer.convertToString(list);

      const decoder = CsvDecoder(fieldDelimiter: ',');
      final parsed = decoder.convert(csvString);

      expect(parsed.length, equals(4)); // Header + 3 rows
      expect(parsed[1][0], equals('Mouse, Wireless'));
      expect(parsed[1][1], equals('SKU,1'));
      expect(parsed[2][0], equals('12" Monitor'));
      expect(parsed[2][1], equals('MON-"12"'));
      expect(parsed[3][0], equals('Keyboard\nMechanical'));
      expect(parsed[3][1], equals('KBD\n01'));
    });

    test('preserves Unicode text without corruption', () {
      final item1 = InventoryItem(id: '1', name: 'Café Mouse', sku: 'SKU-É');
      final item2 = InventoryItem(id: '2', name: 'माउस हिन्दी', sku: 'SKU-IN');

      final list = [
        InventoryItemSummary(item: item1, quantityOnHand: 1.0),
        InventoryItemSummary(item: item2, quantityOnHand: 2.0),
      ];

      final bytes = serializer.convertToBytes(list);
      final decoded = utf8.decode(bytes);

      expect(decoded, contains('Café Mouse'));
      expect(decoded, contains('माउस हिन्दी'));
    });

    test('neutralizes formula triggers (=, +, -, @) by prefixing single quote', () {
      final item1 = InventoryItem(id: '1', name: '=1+1', sku: '=SUM(A1:A2)');
      final item2 = InventoryItem(id: '2', name: '+SUM(1,2)', sku: '+10');
      final item3 = InventoryItem(id: '3', name: '-1+2', sku: '-CMD');
      final item4 = InventoryItem(id: '4', name: '@SUM(B1:B2)', sku: '@ADMIN');
      final item5 = InventoryItem(id: '5', name: '  =1+1', sku: '  +5');

      final list = [
        InventoryItemSummary(item: item1, quantityOnHand: 1.0),
        InventoryItemSummary(item: item2, quantityOnHand: 1.0),
        InventoryItemSummary(item: item3, quantityOnHand: 1.0),
        InventoryItemSummary(item: item4, quantityOnHand: 1.0),
        InventoryItemSummary(item: item5, quantityOnHand: 1.0),
      ];

      final csvString = serializer.convertToString(list);

      const decoder = CsvDecoder(fieldDelimiter: ',');
      final parsed = decoder.convert(csvString);

      expect(parsed[1][0], equals("'=1+1"));
      expect(parsed[1][1], equals("'=SUM(A1:A2)"));
      expect(parsed[2][0], equals("'+SUM(1,2)"));
      expect(parsed[3][0], equals("'-1+2"));
      expect(parsed[4][0], equals("'@SUM(B1:B2)"));
      expect(parsed[5][0], equals("'  =1+1"));
    });

    test('throws InventoryCsvSerializerException for non-finite quantities', () {
      final item = InventoryItem(id: '1', name: 'Item', sku: 'SKU');
      final summaryNaN = InventoryItemSummary(item: item, quantityOnHand: double.nan);
      final summaryInf = InventoryItemSummary(item: item, quantityOnHand: double.infinity);

      expect(
        () => serializer.convertToString([summaryNaN]),
        throwsA(isA<InventoryCsvSerializerException>()),
      );
      expect(
        () => serializer.convertToString([summaryInf]),
        throwsA(isA<InventoryCsvSerializerException>()),
      );
    });

    test('does not mutate original domain objects', () {
      final item = InventoryItem(id: '1', name: '=Formula', sku: 'SKU-01');
      final summary = InventoryItemSummary(item: item, quantityOnHand: 10.0);

      serializer.convertToString([summary]);

      expect(summary.item.name, equals('=Formula'));
      expect(summary.item.sku, equals('SKU-01'));
      expect(summary.quantityOnHand, equals(10.0));
    });
     group('Customizable CSV Export Tests (INVENTORY-7.5)', () {
      test('exports selected columns in exact requested order', () {
        final item = InventoryItem(
          id: 'item-1',
          name: 'Super Gadget',
          sku: 'SKU-001',
          category: 'Electronics',
          warehouse: 'Main WH',
        );
        final summary = InventoryItemSummary(item: item, quantityOnHand: 42.0);

        final columns = ['category', 'product_name', 'current_quantity', 'sku'];
        final csv = serializer.convertToString([summary], columns: columns);
        final lines = csv.trim().split('\r\n');

        expect(lines.length, equals(2));
        expect(lines[0], equals('Category,Product Name,Current Quantity,SKU'));
        expect(lines[1], equals('Electronics,Super Gadget,42,SKU-001'));
      });

      test('exports leading zeroes in SKU and barcode without truncation', () {
        final item = InventoryItem(
          id: 'item-1',
          name: 'Leading Zero Item',
          sku: '00012345',
          barcode: '000987654321',
        );
        final summary = InventoryItemSummary(item: item, quantityOnHand: 5.0);

        final columns = ['sku', 'barcode', 'product_name'];
        final csv = serializer.convertToString([summary], columns: columns);
        final lines = csv.trim().split('\r\n');

        expect(lines[1], contains('00012345'));
        expect(lines[1], contains('000987654321'));
      });

      test('neutralizes formula injection in custom text and notes fields', () {
        final item = InventoryItem(
          id: 'item-1',
          name: 'Normal Item',
          sku: 'SKU-NORM',
          notes: '=SUM(A1:A10)',
          customFields: {'cf_risk': '+cmd|/C calc'},
        );
        final summary = InventoryItemSummary(item: item, quantityOnHand: 1.0);

        final customDef = CustomFieldDefinition(
          id: 'cf-1',
          key: 'cf_risk',
          label: 'Risk Level',
          dataType: CustomFieldDataType.text,
        );

        final columns = ['notes', 'cf_risk'];
        final csv = serializer.convertToString(
          [summary],
          columns: columns,
          customFieldDefinitions: [customDef],
        );

        final lines = csv.trim().split('\r\n');
        expect(lines[0], equals('Notes,Risk Level'));
        expect(lines[1], contains("'=SUM(A1:A10)"));
        expect(lines[1], contains("'+cmd|/C calc"));
      });

      test('formats dates, booleans, quantities, percentages, and prices correctly', () {
        final item = InventoryItem(
          id: 'item-1',
          name: 'Complete Item',
          sku: 'SKU-FULL',
          unitCostInr: 100.50,
          sellingPriceInr: 199.99,
          gstPercent: 18.0,
          expiryDate: DateTime(2027, 6, 15),
          isActive: true,
        );
        final summary = InventoryItemSummary(item: item, quantityOnHand: 250.0);

        final columns = [
          'product_name',
          'unit_cost_inr',
          'selling_price_inr',
          'gst_percent',
          'expiry_date',
          'is_active',
          'current_quantity',
        ];
        final csv = serializer.convertToString([summary], columns: columns);
        final lines = csv.trim().split('\r\n');

        expect(lines[1], equals('Complete Item,100.5,199.99,18,2027-06-15,true,250'));
      });

      test('handles null values as empty CSV cells', () {
        final item = InventoryItem(
          id: 'item-1',
          name: 'Null Fields Item',
          sku: 'SKU-NULL',
          brand: null,
          binLocation: null,
        );
        final summary = InventoryItemSummary(item: item, quantityOnHand: 0.0);

        final columns = ['product_name', 'brand', 'bin_location', 'current_quantity'];
        final csv = serializer.convertToString([summary], columns: columns);
        final lines = csv.trim().split('\r\n');

        expect(lines[0], equals('Product Name,Brand,Bin Location,Current Quantity'));
        expect(lines[1], equals('Null Fields Item,,,0'));
      });

      test('all 21 standard fields export with correct canonical headers', () {
        final item = InventoryItem(
          id: 'item-1',
          name: 'All Standard Fields Item',
          sku: 'SKU-ALL',
        );
        final summary = InventoryItemSummary(item: item, quantityOnHand: 10.0);

        final columns = InventoryExportFields.standardFieldKeys;
        expect(columns.length, equals(21));

        final csv = serializer.convertToString([summary], columns: columns);
        final headerLine = csv.trim().split('\r\n')[0];
        final headers = headerLine.split(',');

        expect(headers.length, equals(21));
        expect(headers[0], equals('SKU'));
        expect(headers[1], equals('Product Name'));
        expect(headers[9], equals('Unit Cost (INR)'));
        expect(headers[10], equals('Selling Price (INR)'));
        expect(headers[11], equals('Current Quantity'));
        expect(headers[14], equals('GST (%)'));
        expect(headers[19], equals('Stock Status'));
      });
    });
  });
}