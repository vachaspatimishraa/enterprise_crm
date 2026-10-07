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

  group('PDF Text Integrity & Non-Truncation (INVENTORY-7.7)', () {
    final List<CustomFieldDefinition> customFields = [
      CustomFieldDefinition(
        key: 'qa_notes',
        label: 'QA Notes',
        id: 'cf-qa',
        dataType: CustomFieldDataType.text,
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
          customFields: customValues ?? const {},
        ),
        quantityOnHand: qty,
      );
    }

    test('Case A: Long Product Name wraps across multiple lines without truncation', () {
      const longName =
          'Enterprise Grade High Precision Ergonomic Optical Scanner With Extended Wireless Dock';
      final item = summary(name: longName, sku: 'SCAN-001');
      final bytes = serializer.convertToBytes(
        [item],
        columns: ['sku', 'product_name'],
        isLegacy: false,
      );
      final text = ascii.decode(bytes);

      // Verify full logical value is represented across generated PDF lines without ellipsis
      expect(text, isNot(contains('...')));
      expect(text, contains('Enterprise Grade'));
      expect(text, contains('Ergonomic'));
      expect(text, contains('Wireless Dock'));
    });

    test('Case B: Long continuous SKU with no spaces wraps without dropping characters', () {
      const longContinuousSku = 'SKU98765432101234567890ABCDEF1234567890XYZ';
      final item = summary(name: 'Widget', sku: longContinuousSku);
      final bytes = serializer.convertToBytes(
        [item],
        columns: ['sku', 'product_name'],
        isLegacy: false,
      );
      final text = ascii.decode(bytes);

      expect(text, isNot(contains('...')));
      // Both wrapped line chunks are present without dropping characters
      expect(text, contains('SKU98765432101234567890ABCDEF123456789'));
      expect(text, contains('0XYZ'));
    });

    test('Case C: Long custom text field survives wrapping with zero truncation', () {
      const longCustomNote =
          'Inspection confirmed unit passed stress test in ambient facility room 4B with zero faults observed';
      final item = fullSummary(
        sku: 'QA-001',
        customValues: {'qa_notes': longCustomNote},
      );
      final bytes = serializer.convertToBytes(
        [item],
        columns: ['sku', 'qa_notes'],
        customFieldDefinitions: customFields,
        isLegacy: false,
      );
      final text = ascii.decode(bytes);

      expect(text, isNot(contains('...')));
      expect(text, contains('Inspection confirmed'));
      expect(text, contains('ambient facility'));
      expect(text, contains('zero faults'));
      expect(text, contains('observed'));
    });

    test('Case D: Wide 5-10 column table wraps long cell values without truncation', () {
      const longDescription =
          'Specialized heavy duty industrial motor controller module assembly';
      final item = fullSummary(
        sku: 'WID-001',
        name: longDescription,
        category: 'Industrial Machinery Components',
      );
      final bytes = serializer.convertToBytes(
        [item],
        columns: [
          'sku',
          'product_name',
          'category',
          'brand',
          'unit_cost_inr',
          'selling_price_inr',
        ],
        isLegacy: false,
      );
      final text = ascii.decode(bytes);

      expect(text, contains('/MediaBox [0 0 842.0 595.0]'));
      // Data cells must preserve full text across lines without data-level truncation
      expect(text, contains('Specialized heavy duty industrial motor'));
      expect(text, contains('controller module assembly'));
      expect(text, contains('Industrial Machinery'));
      expect(text, contains('Components'));
      expect(text, isNot(contains('Specialized...')));
      expect(text, isNot(contains('Industrial...')));
    });

    test('Case E: >10 column record card layout preserves long field content', () {
      const longSupplier =
          'Global Unified Logistics And Distribution Consortium Private Limited';
      const longNotes =
          'Fragile optical equipment handle with extreme care during warehouse transit';
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
      final item = InventoryItemSummary(
        item: InventoryItem(
          id: 'CARD-001',
          sku: 'CARD-001',
          name: 'High Precision Sensor Unit',
          category: 'Electronics',
          brand: 'Apex',
          supplier: longSupplier,
          unitCostInr: 500,
          sellingPriceInr: 750,
          gstPercent: 18,
          notes: longNotes,
        ),
        quantityOnHand: 15,
      );
      final bytes = serializer.convertToBytes(
        [item],
        columns: allCols,
        isLegacy: false,
      );
      final text = ascii.decode(bytes);

      expect(text, isNot(contains('...')));
      expect(text, contains('Global Unified'));
      expect(text, contains('Consortium'));
      expect(text, contains('Fragile optical'));
      expect(text, contains('extreme care'));
    });

    test('Case F: Adaptive row and card heights paginate dynamically and retain repeated headers', () {
      final multiLineItems = List.generate(
        45,
        (i) => fullSummary(
          sku: 'PAGE-SKU-${i.toString().padLeft(3, '0')}',
          name: 'Multi-line product name with comprehensive detail requiring 3 lines for item $i in testing',
        ),
      );
      final tableBytes = serializer.convertToBytes(
        multiLineItems,
        columns: ['sku', 'product_name', 'unit_cost_inr'],
        isLegacy: false,
      );
      final tableText = ascii.decode(tableBytes);
      final tablePageCount = RegExp(r'/Type /Page\b').allMatches(tableText).length;

      expect(tablePageCount, greaterThan(1));
      expect(tableText, contains('Page 1 of $tablePageCount'));
      expect(tableText, contains('Page $tablePageCount of $tablePageCount'));
      final headerCount = RegExp(r'\(Product Name\) Tj').allMatches(tableText).length;
      expect(headerCount, equals(tablePageCount));

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
      final multiLineCards = List.generate(
        15,
        (i) => InventoryItemSummary(
          item: InventoryItem(
            id: 'CARD-$i',
            sku: 'CARD-$i',
            name: 'Item $i with long name spanning multiple lines in card header',
            supplier: 'Very long supplier company name $i that wraps across multiple lines in pair',
            notes: 'Extended notes field $i that expands the height of this individual record card',
          ),
          quantityOnHand: 5,
        ),
      );
      final cardBytes = serializer.convertToBytes(
        multiLineCards,
        columns: allCols,
        isLegacy: false,
      );
      final cardText = ascii.decode(cardBytes);
      final cardPageCount = RegExp(r'/Type /Page\b').allMatches(cardText).length;

      expect(cardPageCount, greaterThan(1));
      expect(cardText, contains('Page 1 of $cardPageCount'));
      expect(cardText, contains('Page $cardPageCount of $cardPageCount'));
    });
  });
}
