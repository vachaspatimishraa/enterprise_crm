import 'dart:convert';

import 'package:enterprise_crm/features/inventory/domain/entities/custom_field_definition.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_artifact.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_pdf_serializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const serializer = InventoryPdfSerializer();

  InventoryItemSummary summary({
    String name = 'Wireless Mouse',
    String sku = 'ELE-0002',
    double quantity = 19,
  }) {
    return InventoryItemSummary(
      item: InventoryItem(id: sku, name: name, sku: sku),
      quantityOnHand: quantity,
    );
  }

  group('InventoryPdfSerializer', () {
    test('creates a valid PDF with the frozen three-column schema', () {
      final bytes = serializer.convertToBytes([
        summary(),
        summary(name: 'Cable (2m)', sku: r'SKU\\01', quantity: 2.5),
      ]);
      final text = ascii.decode(bytes);

      expect(text, startsWith('%PDF-1.4'));
      expect(text, contains('/Type /Catalog'));
      expect(text, contains('/Type /Page'));
      expect(text, contains('Item Name'));
      expect(text, contains('Current Quantity'));
      expect(text, contains('Wireless Mouse'));
      expect(text, contains('2.5'));
      expect(text, endsWith('%%EOF\n'));
    });

    test('empty export still contains the header row', () {
      final text = ascii.decode(serializer.convertToBytes(const []));

      expect(text, contains('Inventory Export'));
      expect(text, contains('Item Name'));
      expect(text, contains('SKU'));
      expect(text, contains('Current Quantity'));
    });

    test('rejects non-finite quantities', () {
      expect(
        () => serializer.convertToBytes([
          summary(quantity: double.infinity),
        ]),
        throwsA(isA<InventoryPdfSerializerException>()),
      );
    });

    test('sanitizes unsupported characters and escapes PDF delimiters', () {
      final text = ascii.decode(
        serializer.convertToBytes([
          summary(name: 'Café (Blue)', sku: 'SKU-हिन्दी'),
        ]),
      );

      expect(text, contains(r'Caf? \(Blue\)'));
      expect(text, contains('SKU-??????'));
    });

    test('splits large inventories across pages', () {
      final items = List.generate(41, (index) => summary(sku: 'SKU-$index'));
      final text = ascii.decode(serializer.convertToBytes(items));

      expect(RegExp(r'/Type /Page\b').allMatches(text).length, 2);
      expect(text, contains('SKU-40'));
    });
  });

    group('Customizable PDF Export (INVENTORY-7.6)', () {
      final List<CustomFieldDefinition> customFields = [
        CustomFieldDefinition(
          key: 'rack_zone',
          label: 'Rack Zone',
          id: 'cf-rack', dataType: CustomFieldDataType.text,
        ),
      ];

      InventoryItemSummary fullSummary({
        String sku = 'SKU-001',
        String name = 'Test Product',
        double qty = 50.0,
        double cost = 120.50,
        double price = 199.99,
        double gst = 18.0,
        String category = 'Hardware',
        Map<String, dynamic>? customValues,
      }) {
        return InventoryItemSummary(
          item: InventoryItem(
            id: sku,
            sku: sku,
            name: name,
            category: category,
            brand: 'Apex',
            unitCostInr: cost,
            sellingPriceInr: price,
            gstPercent: gst,
            customFields: customValues ?? {'rack_zone': 'Zone-B'},
          ),
          quantityOnHand: qty,
        );
      }

      test('creates a valid custom PDF with requested standard and custom fields', () {
        final bytes = serializer.convertToBytes(
          [fullSummary()],
          columns: ['sku', 'product_name', 'unit_cost_inr', 'rack_zone'],
          customFieldDefinitions: customFields,
          isLegacy: false,
          scope: InventoryExportScope.all,
        );
        final text = ascii.decode(bytes);

        expect(text, startsWith('%PDF-1.4'));
        expect(text, contains('/Type /Catalog'));
        expect(text, contains('SKU'));
        expect(text, contains('Product Name'));
        expect(text, contains(r'Unit Cost \(INR\)'));
        expect(text, contains('Rack Zone'));
        expect(text, contains('SKU-001'));
        expect(text, contains('Test Product'));
        expect(text, contains('INR 120.50'));
        expect(text, contains('Zone-B'));
        expect(text, contains('Page 1 of 1'));
      });

      test('preserves user-selected column reordering in custom PDF table', () {
        final bytes = serializer.convertToBytes(
          [fullSummary()],
          columns: ['rack_zone', 'unit_cost_inr', 'sku'],
          customFieldDefinitions: customFields,
          isLegacy: false,
        );
        final text = ascii.decode(bytes);

        final rackIdx = text.indexOf('Rack Zone');
        final costIdx = text.indexOf(r'Unit Cost \(INR\)');
        final skuIdx = text.indexOf('SKU');

        expect(rackIdx, isNonNegative);
        expect(costIdx, isNonNegative);
        expect(skuIdx, isNonNegative);
        expect(rackIdx, lessThan(costIdx));
        expect(costIdx, lessThan(skuIdx));
      });

      test('uses Portrait orientation for <= 4 columns in Auto mode', () {
        final bytes = serializer.convertToBytes(
          [fullSummary()],
          columns: ['sku', 'product_name', 'current_quantity'],
          isLegacy: false,
        );
        final text = ascii.decode(bytes);

        // Portrait MediaBox: [0 0 595.0 842.0]
        expect(text, contains('/MediaBox [0 0 595.0 842.0]'));
      });

      test('uses Landscape orientation for 5-10 columns in Auto mode', () {
        final bytes = serializer.convertToBytes(
          [fullSummary()],
          columns: [
            'sku',
            'product_name',
            'category',
            'current_quantity',
            'unit_cost_inr',
            'selling_price_inr',
          ],
          isLegacy: false,
        );
        final text = ascii.decode(bytes);

        // Landscape MediaBox: [0 0 842.0 595.0]
        expect(text, contains('/MediaBox [0 0 842.0 595.0]'));
      });

      test('respects explicit orientation overrides', () {
        final bytesLandscape = serializer.convertToBytes(
          [fullSummary()],
          columns: ['sku', 'product_name'],
          isLegacy: false,
          orientation: PdfLayoutOrientation.landscape,
        );
        expect(ascii.decode(bytesLandscape), contains('/MediaBox [0 0 842.0 595.0]'));

        final bytesPortrait = serializer.convertToBytes(
          [fullSummary()],
          columns: ['sku', 'product_name', 'category', 'brand', 'unit_cost_inr', 'selling_price_inr'],
          isLegacy: false,
          orientation: PdfLayoutOrientation.portrait,
        );
        expect(ascii.decode(bytesPortrait), contains('/MediaBox [0 0 595.0 842.0]'));
      });

      test('uses Record Card layout when > 10 columns are requested', () {
        final allCols = [
          'sku',
          'product_name',
          'category',
          'brand',
          'supplier',
          'unit_cost_inr',
          'selling_price_inr',
          'gst_percent',
          'current_quantity',
          'reorder_level',
          'max_stock',
          'notes',
        ];
        final bytes = serializer.convertToBytes(
          [fullSummary()],
          columns: allCols,
          isLegacy: false,
        );
        final text = ascii.decode(bytes);

        // Card layout uses portrait and formats as Item #1: ... with key-value pairs
        expect(text, contains('/MediaBox [0 0 595.0 842.0]'));
        expect(text, contains('Item #1: Test Product'));
        expect(text, contains('SKU: SKU-001'));
        expect(text, contains(r'GST \(%\):'));
        expect(text, contains('18%'));
      });

      test('renders enterprise report header with title, scope, and timestamp', () {
        final timestamp = DateTime(2026, 10, 5, 14, 30);
        final bytes = serializer.convertToBytes(
          [fullSummary()],
          columns: ['sku', 'product_name'],
          isLegacy: false,
          scope: InventoryExportScope.filtered,
          generatedAt: timestamp,
          title: 'Custom Inventory Report',
        );
        final text = ascii.decode(bytes);

        expect(text, contains('Custom Inventory Report'));
        expect(text, contains(r'Scope: Filtered Results \(1 items\)'));
        expect(text, contains('Generated: 2026-10-05 14:30'));
      });

      test('repeats table headers on every page for multi-page exports', () {
        final items = List.generate(
          80,
          (i) => fullSummary(sku: 'SKU-${i.toString().padLeft(3, '0')}'),
        );
        final bytes = serializer.convertToBytes(
          items,
          columns: ['sku', 'product_name', 'current_quantity'],
          isLegacy: false,
        );
        final text = ascii.decode(bytes);

        // Header text occurs on every page
        final pageCount = RegExp(r'/Type /Page /').allMatches(text).length;
        expect(pageCount, greaterThan(1));
        final headerMatches = RegExp(r'\(Product Name\) Tj').allMatches(text).length;
        expect(headerMatches, equals(pageCount));
        expect(text, contains('Page 1 of $pageCount'));
        expect(text, contains('Page 2 of $pageCount'));
      });

      test('formats currency, percentages, quantities, and dates correctly', () {
        final date = DateTime(2027, 5, 15);
        final item = InventoryItemSummary(
          item: InventoryItem(
            id: 'FMT-1',
            sku: 'FMT-1',
            name: 'Formatted Item',
            unitCostInr: 1500.5,
            sellingPriceInr: 2200.0,
            gstPercent: 12.0,
            expiryDate: date,
            isActive: true,
          ),
          quantityOnHand: 42.5,
        );
        final bytes = serializer.convertToBytes(
          [item],
          columns: [
            'sku',
            'unit_cost_inr',
            'selling_price_inr',
            'gst_percent',
            'current_quantity',
            'expiry_date',
            'is_active',
          ],
          isLegacy: false,
        );
        final text = ascii.decode(bytes);

        expect(text, contains('INR 1500.50'));
        expect(text, contains('INR 2200.00'));
        expect(text, contains('12%'));
        expect(text, contains('42.5'));
        expect(text, contains('2027-05-15'));
        expect(text, contains('Yes'));
      });

      test('rejects empty column list in custom mode', () {
        expect(
          () => serializer.convertToBytes(
            [fullSummary()],
            columns: const [],
            isLegacy: false,
          ),
          throwsA(
            isA<InventoryPdfSerializerException>().having(
              (e) => e.message,
              'message',
              contains('No export columns selected'),
            ),
          ),
        );
      });

      test('rejects duplicate column keys in custom mode', () {
        expect(
          () => serializer.convertToBytes(
            [fullSummary()],
            columns: ['sku', 'product_name', 'sku'],
            isLegacy: false,
          ),
          throwsA(
            isA<InventoryPdfSerializerException>().having(
              (e) => e.message,
              'message',
              contains('Duplicate export columns'),
            ),
          ),
        );
      });

      test('rejects unknown column keys in custom mode', () {
        expect(
          () => serializer.convertToBytes(
            [fullSummary()],
            columns: ['sku', 'unknown_field_123'],
            isLegacy: false,
          ),
          throwsA(
            isA<InventoryPdfSerializerException>().having(
              (e) => e.message,
              'message',
              contains('Unknown export column'),
            ),
          ),
        );
      });

      test('rejects non-finite values in custom columns', () {
        final invalidItem = InventoryItemSummary(
          item: InventoryItem(
            id: 'INV-1',
            sku: 'INV-1',
            name: 'Invalid Cost',
            unitCostInr: double.nan,
          ),
          quantityOnHand: 10,
        );
        expect(
          () => serializer.convertToBytes(
            [invalidItem],
            columns: ['sku', 'unit_cost_inr'],
            isLegacy: false,
          ),
          throwsA(
            isA<InventoryPdfSerializerException>().having(
              (e) => e.message,
              'message',
              contains('Invalid non-finite value'),
            ),
          ),
        );
      });

      test('empty dataset renders custom header and empty message', () {
        final bytes = serializer.convertToBytes(
          const [],
          columns: ['sku', 'product_name'],
          isLegacy: false,
          scope: InventoryExportScope.all,
        );
        final text = ascii.decode(bytes);

        expect(text, contains('Inventory Export Report'));
        expect(text, contains(r'Scope: All Records \(0 items\)'));
        expect(text, contains('No inventory items found matching the selected scope.'));
        expect(text, contains('Page 1 of 1'));
      });
    });

}
