import 'dart:convert';
import 'dart:typed_data';

import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_file_picker.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_parser.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultInventoryImportParser', () {
    const parser = DefaultInventoryImportParser();

    test(
      'throws InventoryImportParseException for unsupported extensions',
      () async {
        final file = InventoryImportSelectedFile(
          name: 'data.pdf',
          extension: 'pdf',
          sizeBytes: 100,
          bytes: Uint8List(100),
        );

        expect(
          () => parser.parse(file),
          throwsA(
            isA<InventoryImportParseException>().having(
              (e) => e.message,
              'message',
              'Please select a CSV or XLSX file.',
            ),
          ),
        );
      },
    );

    test('parses valid CSV bytes correctly', () async {
      const csvString =
          'Name,SKU,Opening Stock\nWidget A,00123,50\nWidget B,SKU-456,';
      final bytes = Uint8List.fromList(utf8.encode(csvString));

      final file = InventoryImportSelectedFile(
        name: 'inventory.csv',
        extension: 'csv',
        sizeBytes: bytes.length,
        bytes: bytes,
      );

      final parsed = await parser.parse(file);
      expect(parsed.fileName, 'inventory.csv');
      expect(parsed.fileType, InventoryImportFileType.csv);
      expect(parsed.sheets.length, 1);
      expect(parsed.sheets.first.name, 'CSV');

      final rows = parsed.sheets.first.rows;
      expect(rows.length, 3);
      expect(rows[0], ['Name', 'SKU', 'Opening Stock']);
      expect(rows[1], [
        'Widget A',
        '00123',
        '50',
      ]); // Preserves leading zero '00123'
      expect(rows[2], ['Widget B', 'SKU-456', '']);
    });

    test('strips UTF-8 BOM from CSV content', () async {
      final bytes = Uint8List.fromList([
        0xEF, 0xBB, 0xBF, // UTF-8 BOM
        ...utf8.encode('Name,SKU\nWidget A,SKU-1'),
      ]);

      final file = InventoryImportSelectedFile(
        name: 'bom.csv',
        extension: 'csv',
        sizeBytes: bytes.length,
        bytes: bytes,
      );

      final parsed = await parser.parse(file);
      expect(parsed.sheets.first.rows[0][0], 'Name');
    });

    test(
      'throws InventoryImportParseException for corrupted CSV bytes',
      () async {
        final corruptedBytes = Uint8List.fromList([
          0xFF,
          0xFE,
          0xFD,
        ]); // Invalid UTF-8

        final file = InventoryImportSelectedFile(
          name: 'bad.csv',
          extension: 'csv',
          sizeBytes: corruptedBytes.length,
          bytes: corruptedBytes,
        );

        expect(
          () => parser.parse(file),
          throwsA(
            isA<InventoryImportParseException>().having(
              (e) => e.message,
              'message',
              'Unable to read this file.',
            ),
          ),
        );
      },
    );

    test('parses XLSX workbook with multiple sheets correctly', () async {
      final excel = Excel.createExcel();
      excel.rename('Sheet1', 'Warehouse A');
      final sheetA = excel['Warehouse A'];
      sheetA.appendRow([
        TextCellValue('Name'),
        TextCellValue('SKU'),
        TextCellValue('Stock'),
      ]);
      sheetA.appendRow([
        TextCellValue('Hammer'),
        TextCellValue('0099'),
        IntCellValue(12),
      ]);

      final sheetB = excel['Warehouse B'];
      sheetB.appendRow([TextCellValue('Name'), TextCellValue('SKU')]);
      sheetB.appendRow([TextCellValue('Nails'), TextCellValue('SKU-NAIL')]);

      final encoded = excel.encode()!;
      final bytes = Uint8List.fromList(encoded);

      final file = InventoryImportSelectedFile(
        name: 'inventory.xlsx',
        extension: 'xlsx',
        sizeBytes: bytes.length,
        bytes: bytes,
      );

      final parsed = await parser.parse(file);
      expect(parsed.fileName, 'inventory.xlsx');
      expect(parsed.fileType, InventoryImportFileType.xlsx);
      expect(parsed.sheets.length, 2);
      expect(
        parsed.sheets.map((s) => s.name),
        containsAll(['Warehouse A', 'Warehouse B']),
      );

      final warehouseA = parsed.sheets.firstWhere(
        (s) => s.name == 'Warehouse A',
      );
      expect(warehouseA.rows[0], ['Name', 'SKU', 'Stock']);
      expect(warehouseA.rows[1], ['Hammer', '0099', '12']);
    });

    test(
      'throws InventoryImportParseException for corrupted XLSX bytes',
      () async {
        final corruptedBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        final file = InventoryImportSelectedFile(
          name: 'corrupt.xlsx',
          extension: 'xlsx',
          sizeBytes: corruptedBytes.length,
          bytes: corruptedBytes,
        );

        expect(
          () => parser.parse(file),
          throwsA(
            isA<InventoryImportParseException>().having(
              (e) => e.message,
              'message',
              'Unable to read this file.',
            ),
          ),
        );
      },
    );
  });
}
