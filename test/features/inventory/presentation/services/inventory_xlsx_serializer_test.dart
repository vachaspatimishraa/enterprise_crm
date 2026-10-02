import 'dart:typed_data';

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
      expect((headerRow[0]?.value as TextCellValue).value.toString(), equals('Item Name'));
      expect(headerRow[1]?.value, isA<TextCellValue>());
      expect((headerRow[1]?.value as TextCellValue).value.toString(), equals('SKU'));
      expect(headerRow[2]?.value, isA<TextCellValue>());
      expect((headerRow[2]?.value as TextCellValue).value.toString(), equals('Current Quantity'));
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
        createSummary(id: '2', name: 'Beta', sku: 'SKU-B', quantityOnHand: 15.5),
        createSummary(id: '3', name: 'Gamma', sku: 'SKU-C', quantityOnHand: 0),
      ];
      final bytes = serializer.convertToBytes(items);
      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables['Inventory']!;
      expect(table.maxRows, equals(4));

      expect((table.rows[1][0]?.value as TextCellValue).value.toString(), equals('Alpha'));
      expect((table.rows[2][0]?.value as TextCellValue).value.toString(), equals('Beta'));
      expect((table.rows[3][0]?.value as TextCellValue).value.toString(), equals('Gamma'));
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
      expect((table.rows[1][0]?.value as TextCellValue).value.toString(), equals('=1+1'));
      expect((table.rows[1][1]?.value as TextCellValue).value.toString(), equals('@SUM(A1:A2)'));
      expect((table.rows[2][0]?.value as TextCellValue).value.toString(), equals('  =1+1'));
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
      final original = [createSummary(name: 'Item A', sku: 'SKU-01', quantityOnHand: 10)];
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

    test('CSV and XLSX serializers output identical business dataset from shared loader', () async {
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
      expect((table.rows[1][0]?.value as TextCellValue).value.toString(), equals(firstSummary.item.name));
      expect((table.rows[1][1]?.value as TextCellValue).value.toString(), equals(firstSummary.item.sku));

      final csvLines = csvString.split('\r\n');
      expect(csvLines[1], contains(firstSummary.item.name));
      expect(csvLines[1], contains(firstSummary.item.sku));
    });
  });
}
