import 'package:enterprise_crm/features/inventory/domain/entities/custom_field_definition.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_fields.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_csv_serializer.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_data_loader.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_xlsx_serializer.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InventoryXlsxSerializer serializer;

  setUp(() {
    serializer = InventoryXlsxSerializer();
  });

  InventoryItemSummary createSummary({
    String id = 'item-1',
    String name = 'Test Item',
    String sku = 'SKU-001',
    double quantityOnHand = 10.0,
  }) {
    return InventoryItemSummary(
      item: InventoryItem(id: id, name: name, sku: sku),
      quantityOnHand: quantityOnHand,
    );
  }

  group('InventoryXlsxSerializer Unit Tests', () {
    test('produces nonempty Uint8List bytes', () {
      final bytes = serializer.convertToBytes([createSummary()]);
      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
    });

    test('can decode generated workbook and has single Inventory sheet', () {
      final bytes = serializer.convertToBytes([createSummary()]);
      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys, contains('Inventory'));
      expect(excel.tables.containsKey('Sheet1'), isFalse);
    });

    test('writes correct header row (3 columns)', () {
      final bytes = serializer.convertToBytes([]);
      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables['Inventory']!;

      expect(table.maxRows, equals(1));
      final headerRow = table.rows[0];
      expect(headerRow.length, equals(3));
      expect(headerRow[0]?.value, isA<TextCellValue>());
      expect(
        (headerRow[0]?.value as TextCellValue).value.toString(),
        equals('Item Name'),
      );
      expect(headerRow[1]?.value, isA<TextCellValue>());
      expect(
        (headerRow[1]?.value as TextCellValue).value.toString(),
        equals('SKU'),
      );
      expect(headerRow[2]?.value, isA<TextCellValue>());
      expect(
        (headerRow[2]?.value as TextCellValue).value.toString(),
        equals('Current Quantity'),
      );
    });

    test('header-only empty export for empty dataset', () {
      final bytes = serializer.convertToBytes([]);
      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables['Inventory']!;
      expect(table.maxRows, equals(1));
    });

    test('single item produces exactly one data row', () {
      final bytes = serializer.convertToBytes([createSummary()]);
      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables['Inventory']!;
      expect(table.maxRows, equals(2));
    });

    test('multiple items produce correct row count and order', () {
      final items = [
        createSummary(id: '1', name: 'Alpha', sku: 'SKU-A', quantityOnHand: 5),
        createSummary(
          id: '2',
          name: 'Beta',
          sku: 'SKU-B',
          quantityOnHand: 15.5,
        ),
        createSummary(id: '3', name: 'Gamma', sku: 'SKU-C', quantityOnHand: 0),
      ];
      final bytes = serializer.convertToBytes(items);
      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables['Inventory']!;
      expect(table.maxRows, equals(4));

      expect(
        (table.rows[1][0]?.value as TextCellValue).value.toString(),
        equals('Alpha'),
      );
      expect(
        (table.rows[2][0]?.value as TextCellValue).value.toString(),
        equals('Beta'),
      );
      expect(
        (table.rows[3][0]?.value as TextCellValue).value.toString(),
        equals('Gamma'),
      );
    });

    test('preserves numeric-looking SKU with leading zeros as text', () {
      final items = [createSummary(sku: '000123')];
      final bytes = serializer.convertToBytes(items);
      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables['Inventory']!;
      final skuCell = table.rows[1][1]?.value;

      expect(skuCell, isA<TextCellValue>());
      expect((skuCell as TextCellValue).value.toString(), equals('000123'));
    });

    test('preserves zero and fractional quantities as numeric cells', () {
      final items = [
        createSummary(id: '1', quantityOnHand: 0),
        createSummary(id: '2', quantityOnHand: 12.5),
        createSummary(id: '3', quantityOnHand: 0.125),
      ];
      final bytes = serializer.convertToBytes(items);
      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables['Inventory']!;

      final val1 = table.rows[1][2]?.value;
      final val2 = table.rows[2][2]?.value;
      final val3 = table.rows[3][2]?.value;

      expect(val1, isA<IntCellValue>());
      expect((val1 as IntCellValue).value, equals(0));

      expect(val2, isA<DoubleCellValue>());
      expect((val2 as DoubleCellValue).value, equals(12.5));

      expect(val3, isA<DoubleCellValue>());
      expect((val3 as DoubleCellValue).value, equals(0.125));
    });

    test('preserves Unicode names and embedded punctuation', () {
      final items = [
        createSummary(name: 'Item "Widget", Accent éà, Hindi हिंदी, Emoji 📦'),
        createSummary(sku: 'SKU-001,002'),
      ];
      final bytes = serializer.convertToBytes(items);
      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables['Inventory']!;

      expect(
        (table.rows[1][0]?.value as TextCellValue).value.toString(),
        equals('Item "Widget", Accent éà, Hindi हिंदी, Emoji 📦'),
      );
      expect(
        (table.rows[2][1]?.value as TextCellValue).value.toString(),
        equals('SKU-001,002'),
      );
    });

    test('formula-like strings remain safe text cells', () {
      final items = [
        createSummary(name: '=1+1', sku: '@SUM(A1:A2)'),
        createSummary(name: '  =1+1', sku: '-1+2'),
        createSummary(name: '+SUM(1,2)', sku: '+100'),
      ];
      final bytes = serializer.convertToBytes(items);
      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables['Inventory']!;

      expect(table.rows[1][0]?.value, isA<TextCellValue>());
      expect(table.rows[1][1]?.value, isA<TextCellValue>());
      expect(
        (table.rows[1][0]?.value as TextCellValue).value.toString(),
        equals('=1+1'),
      );
      expect(
        (table.rows[1][1]?.value as TextCellValue).value.toString(),
        equals('@SUM(A1:A2)'),
      );
      expect(
        (table.rows[2][0]?.value as TextCellValue).value.toString(),
        equals('  =1+1'),
      );
    });

    test('rejects NaN quantity', () {
      final items = [createSummary(quantityOnHand: double.nan)];
      expect(
        () => serializer.convertToBytes(items),
        throwsA(isA<InventoryXlsxSerializerException>()),
      );
    });

    test('rejects positive infinity quantity', () {
      final items = [createSummary(quantityOnHand: double.infinity)];
      expect(
        () => serializer.convertToBytes(items),
        throwsA(isA<InventoryXlsxSerializerException>()),
      );
    });

    test('rejects negative infinity quantity', () {
      final items = [createSummary(quantityOnHand: double.negativeInfinity)];
      expect(
        () => serializer.convertToBytes(items),
        throwsA(isA<InventoryXlsxSerializerException>()),
      );
    });

    test('original source records remain unchanged', () {
      final original = [
        createSummary(name: 'Item A', sku: 'SKU-01', quantityOnHand: 10),
      ];
      final nameBefore = original[0].item.name;
      final skuBefore = original[0].item.sku;
      final qtyBefore = original[0].quantityOnHand;

      serializer.convertToBytes(original);

      expect(original[0].item.name, equals(nameBefore));
      expect(original[0].item.sku, equals(skuBefore));
      expect(original[0].quantityOnHand, equals(qtyBefore));
    });
  });

  group('CSV/XLSX Consistency Integration Tests', () {
    late MockInventoryRepository mockRepo;
    late InventoryExportDataLoader loader;

    setUp(() {
      mockRepo = MockInventoryRepository();
      loader = InventoryExportDataLoader(mockRepo);
    });

    test(
      'CSV and XLSX serializers output identical business dataset from shared loader',
      () async {
        final items = await loader.loadAllItems();

        final csvBytes = InventoryCsvSerializer().convertToBytes(items);
        final csvString = String.fromCharCodes(csvBytes);
        final xlsxBytes = serializer.convertToBytes(items);

        final excel = Excel.decodeBytes(xlsxBytes);
        final table = excel.tables['Inventory']!;

        expect(items.isNotEmpty, isTrue);
        expect(table.maxRows, equals(items.length + 1)); // header + item rows

        // Compare first item in CSV and XLSX
        final firstSummary = items.first;
        expect(
          (table.rows[1][0]?.value as TextCellValue).value.toString(),
          equals(firstSummary.item.name),
        );
        expect(
          (table.rows[1][1]?.value as TextCellValue).value.toString(),
          equals(firstSummary.item.sku),
        );

        final csvLines = csvString.split('\r\n');
        expect(csvLines[1], contains(firstSummary.item.name));
        expect(csvLines[1], contains(firstSummary.item.sku));
      },
    );
    group('Customizable XLSX Export Tests (INVENTORY-7.5)', () {
      test('exports selected columns in exact requested order', () {
        final item = InventoryItem(
          id: 'item-1',
          name: 'Super Gadget',
          sku: 'SKU-001',
          category: 'Electronics',
        );
        final summary = InventoryItemSummary(item: item, quantityOnHand: 42.0);

        final columns = ['category', 'product_name', 'current_quantity', 'sku'];
        final bytes = serializer.convertToBytes([summary], columns: columns);

        final excel = Excel.decodeBytes(bytes);
        final table = excel.tables['Inventory']!;

        expect(table.maxRows, equals(2));
        final headerRow = table.rows[0];
        expect(
          (headerRow[0]?.value as TextCellValue).value.toString(),
          equals('Category'),
        );
        expect(
          (headerRow[1]?.value as TextCellValue).value.toString(),
          equals('Product Name'),
        );
        expect(
          (headerRow[2]?.value as TextCellValue).value.toString(),
          equals('Current Quantity'),
        );
        expect(
          (headerRow[3]?.value as TextCellValue).value.toString(),
          equals('SKU'),
        );

        final dataRow = table.rows[1];
        expect(
          (dataRow[0]?.value as TextCellValue).value.toString(),
          equals('Electronics'),
        );
        expect(
          (dataRow[1]?.value as TextCellValue).value.toString(),
          equals('Super Gadget'),
        );
        expect((dataRow[2]?.value as IntCellValue).value, equals(42));
        expect(
          (dataRow[3]?.value as TextCellValue).value.toString(),
          equals('SKU-001'),
        );
      });

      test('preserves leading zeroes in SKU and barcode as TextCellValue', () {
        final item = InventoryItem(
          id: 'item-1',
          name: 'Zero Item',
          sku: '00054321',
          barcode: '000999888',
        );
        final summary = InventoryItemSummary(item: item, quantityOnHand: 1.0);

        final columns = ['sku', 'barcode'];
        final bytes = serializer.convertToBytes([summary], columns: columns);

        final excel = Excel.decodeBytes(bytes);
        final table = excel.tables['Inventory']!;
        final dataRow = table.rows[1];

        expect(dataRow[0]?.value, isA<TextCellValue>());
        expect(
          (dataRow[0]?.value as TextCellValue).value.toString(),
          equals('00054321'),
        );

        expect(dataRow[1]?.value, isA<TextCellValue>());
        expect(
          (dataRow[1]?.value as TextCellValue).value.toString(),
          equals('000999888'),
        );
      });

      test('stores quantities, prices, and percentages as numeric cells', () {
        final item = InventoryItem(
          id: 'item-1',
          name: 'Priced Item',
          sku: 'SKU-PRICED',
          unitCostInr: 99.50,
          sellingPriceInr: 150.00,
          gstPercent: 18.0,
        );
        final summary = InventoryItemSummary(item: item, quantityOnHand: 10.5);

        final columns = [
          'current_quantity',
          'unit_cost_inr',
          'selling_price_inr',
          'gst_percent',
        ];
        final bytes = serializer.convertToBytes([summary], columns: columns);

        final excel = Excel.decodeBytes(bytes);
        final table = excel.tables['Inventory']!;
        final dataRow = table.rows[1];

        expect(dataRow[0]?.value, isA<DoubleCellValue>());
        expect((dataRow[0]?.value as DoubleCellValue).value, equals(10.5));

        expect(dataRow[1]?.value, isA<DoubleCellValue>());
        expect((dataRow[1]?.value as DoubleCellValue).value, equals(99.50));

        expect(dataRow[2]?.value, isA<IntCellValue>());
        expect((dataRow[2]?.value as IntCellValue).value, equals(150));

        expect(dataRow[3]?.value, isA<IntCellValue>());
        expect((dataRow[3]?.value as IntCellValue).value, equals(18));
      });

      test('stores dates as DateCellValue and booleans as BoolCellValue', () {
        final item = InventoryItem(
          id: 'item-1',
          name: 'Dated Item',
          sku: 'SKU-DATE',
          expiryDate: DateTime(2028, 12, 31),
          isActive: true,
        );
        final summary = InventoryItemSummary(item: item, quantityOnHand: 0.0);

        final columns = ['expiry_date', 'is_active'];
        final bytes = serializer.convertToBytes([summary], columns: columns);

        final excel = Excel.decodeBytes(bytes);
        final table = excel.tables['Inventory']!;
        final dataRow = table.rows[1];

        expect(dataRow[0]?.value, isA<DateCellValue>());
        final dateCell = dataRow[0]?.value as DateCellValue;
        expect(dateCell.year, equals(2028));
        expect(dateCell.month, equals(12));
        expect(dateCell.day, equals(31));

        expect(dataRow[1]?.value, isA<BoolCellValue>());
        expect((dataRow[1]?.value as BoolCellValue).value, isTrue);
      });

      test('exports registered custom fields with appropriate cell types', () {
        final item = InventoryItem(
          id: 'item-1',
          name: 'Custom Item',
          sku: 'SKU-CUST',
          customFields: {
            'cf_text': 'Heavy Duty',
            'cf_num': 100,
            'cf_bool': false,
          },
        );
        final summary = InventoryItemSummary(item: item, quantityOnHand: 5.0);

        final customDefs = [
          CustomFieldDefinition(
            id: '1',
            key: 'cf_text',
            label: 'Material',
            dataType: CustomFieldDataType.text,
          ),
          CustomFieldDefinition(
            id: '2',
            key: 'cf_num',
            label: 'Rating',
            dataType: CustomFieldDataType.number,
          ),
          CustomFieldDefinition(
            id: '3',
            key: 'cf_bool',
            label: 'Recyclable',
            dataType: CustomFieldDataType.boolean,
          ),
        ];

        final columns = ['cf_text', 'cf_num', 'cf_bool'];
        final bytes = serializer.convertToBytes(
          [summary],
          columns: columns,
          customFieldDefinitions: customDefs,
        );

        final excel = Excel.decodeBytes(bytes);
        final table = excel.tables['Inventory']!;

        final headerRow = table.rows[0];
        expect(
          (headerRow[0]?.value as TextCellValue).value.toString(),
          equals('Material'),
        );
        expect(
          (headerRow[1]?.value as TextCellValue).value.toString(),
          equals('Rating'),
        );
        expect(
          (headerRow[2]?.value as TextCellValue).value.toString(),
          equals('Recyclable'),
        );

        final dataRow = table.rows[1];
        expect(
          (dataRow[0]?.value as TextCellValue).value.toString(),
          equals('Heavy Duty'),
        );
        expect((dataRow[1]?.value as IntCellValue).value, equals(100));
        expect((dataRow[2]?.value as BoolCellValue).value, isFalse);
      });

      test('handles null values gracefully as null cells', () {
        final item = InventoryItem(
          id: 'item-1',
          name: 'Null Item',
          sku: 'SKU-NULL',
          brand: null,
          binLocation: null,
        );
        final summary = InventoryItemSummary(item: item, quantityOnHand: 1.0);

        final columns = ['product_name', 'brand', 'bin_location'];
        final bytes = serializer.convertToBytes([summary], columns: columns);

        final excel = Excel.decodeBytes(bytes);
        final table = excel.tables['Inventory']!;
        final dataRow = table.rows[1];

        expect(dataRow[0]?.value, isA<TextCellValue>());
        expect(dataRow[1]?.value, isNull);
        expect(dataRow[2]?.value, isNull);
      });

      test(
        'all 21 standard fields export with correct canonical headers in XLSX',
        () {
          final item = InventoryItem(
            id: 'item-1',
            name: 'Standard Item',
            sku: 'SKU-STD',
          );
          final summary = InventoryItemSummary(item: item, quantityOnHand: 1.0);

          final columns = InventoryExportFields.standardFieldKeys;
          final bytes = serializer.convertToBytes([summary], columns: columns);

          final excel = Excel.decodeBytes(bytes);
          final table = excel.tables['Inventory']!;
          final headerRow = table.rows[0];

          expect(headerRow.length, equals(21));
          expect(
            (headerRow[0]?.value as TextCellValue).value.toString(),
            equals('SKU'),
          );
          expect(
            (headerRow[1]?.value as TextCellValue).value.toString(),
            equals('Product Name'),
          );
          expect(
            (headerRow[9]?.value as TextCellValue).value.toString(),
            equals('Unit Cost (INR)'),
          );
          expect(
            (headerRow[10]?.value as TextCellValue).value.toString(),
            equals('Selling Price (INR)'),
          );
          expect(
            (headerRow[11]?.value as TextCellValue).value.toString(),
            equals('Current Quantity'),
          );
          expect(
            (headerRow[14]?.value as TextCellValue).value.toString(),
            equals('GST (%)'),
          );
          expect(
            (headerRow[19]?.value as TextCellValue).value.toString(),
            equals('Stock Status'),
          );
        },
      );

      test('worksheet dimension includes every exported row and column', () {
        final summaries = [
          InventoryItemSummary(
            item: InventoryItem(id: '1', name: 'One', sku: 'SKU-1'),
            quantityOnHand: 1,
          ),
          InventoryItemSummary(
            item: InventoryItem(id: '2', name: 'Two', sku: 'SKU-2'),
            quantityOnHand: 2,
          ),
        ];
        final bytes = serializer.convertToBytes(
          summaries,
          columns: InventoryExportFields.standardFieldKeys,
        );
        final worksheet = ZipDecoder()
            .decodeBytes(bytes)
            .findFile('xl/worksheets/sheet1.xml')!;
        worksheet.decompress();
        expect(
          utf8.decode(worksheet.content as List<int>),
          contains('<dimension ref="A1:U3"/>'),
        );
      });
    });
  });
}
