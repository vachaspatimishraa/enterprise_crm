import 'dart:convert';
import 'dart:typed_data';

import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_selected_file.dart';
import 'package:enterprise_crm/features/leads/presentation/services/lead_import_parser.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultLeadImportParser', () {
    const parser = DefaultLeadImportParser();

    LeadImportSelectedFile createSelectedFile({
      required String name,
      required String extension,
      required LeadSource source,
      required Uint8List bytes,
    }) {
      return LeadImportSelectedFile(
        name: name,
        extension: extension,
        sizeBytes: bytes.length,
        source: source,
        content: InMemoryLeadImportFileContent(bytes),
      );
    }

    group('CSV Parsing', () {
      test(
        'parses basic CSV content preserving row and column order',
        () async {
          const csvContent =
              'Name,Phone,Email\n'
              'Alice,+911234567890,alice@example.com\n'
              'Bob,+919876543210,bob@example.com';

          final file = createSelectedFile(
            name: 'leads.csv',
            extension: 'csv',
            source: LeadSource.csv,
            bytes: Uint8List.fromList(utf8.encode(csvContent)),
          );

          final parsed = await parser.parse(file);

          expect(parsed.fileName, equals('leads.csv'));
          expect(parsed.source, equals(LeadSource.csv));
          expect(parsed.sheets.length, equals(1));
          expect(parsed.sheets.first.name, equals('CSV'));

          final rows = parsed.sheets.first.rows;
          expect(rows.length, equals(3));
          expect(rows[0], equals(['Name', 'Phone', 'Email']));
          expect(
            rows[1],
            equals(['Alice', '+911234567890', 'alice@example.com']),
          );
          expect(rows[2], equals(['Bob', '+919876543210', 'bob@example.com']));
        },
      );

      test('preserves commas inside quoted fields', () async {
        const csvContent =
            'Name,Notes\n'
            'Alice,"Called, no answer"';

        final file = createSelectedFile(
          name: 'quoted.csv',
          extension: 'csv',
          source: LeadSource.csv,
          bytes: Uint8List.fromList(utf8.encode(csvContent)),
        );

        final parsed = await parser.parse(file);
        final rows = parsed.sheets.first.rows;

        expect(rows.length, equals(2));
        expect(rows[1], equals(['Alice', 'Called, no answer']));
      });

      test('preserves embedded newlines inside quoted fields', () async {
        const csvContent =
            'Name,Notes\n'
            'Bob,"Line one\nLine two"';

        final file = createSelectedFile(
          name: 'multiline.csv',
          extension: 'csv',
          source: LeadSource.csv,
          bytes: Uint8List.fromList(utf8.encode(csvContent)),
        );

        final parsed = await parser.parse(file);
        final rows = parsed.sheets.first.rows;

        expect(rows.length, equals(2));
        expect(rows[1], equals(['Bob', 'Line one\nLine two']));
      });

      test('handles escaped quotation marks in CSV', () async {
        const csvContent =
            'Name,Quote\n'
            'Charlie,"He said ""Welcome"""';

        final file = createSelectedFile(
          name: 'escaped.csv',
          extension: 'csv',
          source: LeadSource.csv,
          bytes: Uint8List.fromList(utf8.encode(csvContent)),
        );

        final parsed = await parser.parse(file);
        final rows = parsed.sheets.first.rows;

        expect(rows.length, equals(2));
        expect(rows[1], equals(['Charlie', 'He said "Welcome"']));
      });

      test('handles UTF-8 BOM by stripping it from the first cell', () async {
        final bom = [0xEF, 0xBB, 0xBF];
        final text = utf8.encode('Name,Email\nAlice,alice@example.com');
        final bytes = Uint8List.fromList([...bom, ...text]);

        final file = createSelectedFile(
          name: 'bom.csv',
          extension: 'csv',
          source: LeadSource.csv,
          bytes: bytes,
        );

        final parsed = await parser.parse(file);
        final rows = parsed.sheets.first.rows;

        expect(rows[0][0], equals('Name'));
        expect(rows[0][1], equals('Email'));
      });

      test('preserves blank middle fields without shifting columns', () async {
        const csvContent =
            'Name,Phone,Email\n'
            'Alice,,alice@example.com';

        final file = createSelectedFile(
          name: 'blanks.csv',
          extension: 'csv',
          source: LeadSource.csv,
          bytes: Uint8List.fromList(utf8.encode(csvContent)),
        );

        final parsed = await parser.parse(file);
        final rows = parsed.sheets.first.rows;

        expect(rows[1].length, equals(3));
        expect(rows[1], equals(['Alice', '', 'alice@example.com']));
      });

      test('preserves numeric-looking text with leading zeros', () async {
        const csvContent =
            'ID,Phone,Code\n'
            '00123,00919876543210,007';

        final file = createSelectedFile(
          name: 'numeric_text.csv',
          extension: 'csv',
          source: LeadSource.csv,
          bytes: Uint8List.fromList(utf8.encode(csvContent)),
        );

        final parsed = await parser.parse(file);
        final rows = parsed.sheets.first.rows;

        expect(rows[1], equals(['00123', '00919876543210', '007']));
      });

      test('preserves raw blank rows in CSV', () async {
        const csvContent =
            'Name,Email\n'
            '\n'
            'Alice,alice@example.com';

        final file = createSelectedFile(
          name: 'blank_line.csv',
          extension: 'csv',
          source: LeadSource.csv,
          bytes: Uint8List.fromList(utf8.encode(csvContent)),
        );

        final parsed = await parser.parse(file);
        final rows = parsed.sheets.first.rows;

        expect(rows.length, equals(3));
        expect(rows[0], equals(['Name', 'Email']));
        expect(rows[1], equals(['']));
        expect(rows[2], equals(['Alice', 'alice@example.com']));
      });

      test(
        'throws safe LeadImportParseException on invalid UTF-8 bytes',
        () async {
          final invalidBytes = Uint8List.fromList([0xC0, 0xC1, 0xF5, 0xFF]);

          final file = createSelectedFile(
            name: 'corrupt.csv',
            extension: 'csv',
            source: LeadSource.csv,
            bytes: invalidBytes,
          );

          expect(
            () => parser.parse(file),
            throwsA(
              isA<LeadImportParseException>().having(
                (e) => e.message,
                'message',
                equals('Unable to read this CSV file.'),
              ),
            ),
          );
        },
      );
    });

    group('XLSX Parsing', () {
      test('parses basic XLSX workbook preserving rows and columns', () async {
        final excel = Excel.createExcel();
        final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
        final sheet = excel[defaultSheetName];

        sheet.updateCell(CellIndex.indexByString('A1'), TextCellValue('Name'));
        sheet.updateCell(CellIndex.indexByString('B1'), TextCellValue('Phone'));
        sheet.updateCell(CellIndex.indexByString('C1'), TextCellValue('Email'));

        sheet.updateCell(CellIndex.indexByString('A2'), TextCellValue('Alice'));
        sheet.updateCell(
          CellIndex.indexByString('B2'),
          TextCellValue('+911234567890'),
        );
        sheet.updateCell(
          CellIndex.indexByString('C2'),
          TextCellValue('alice@example.com'),
        );

        final bytes = Uint8List.fromList(excel.encode()!);

        final file = createSelectedFile(
          name: 'leads.xlsx',
          extension: 'xlsx',
          source: LeadSource.excel,
          bytes: bytes,
        );

        final parsed = await parser.parse(file);

        expect(parsed.fileName, equals('leads.xlsx'));
        expect(parsed.source, equals(LeadSource.excel));
        expect(parsed.sheets.length, equals(1));

        final rows = parsed.sheets.first.rows;
        expect(rows.length, equals(2));
        expect(rows[0], equals(['Name', 'Phone', 'Email']));
        expect(
          rows[1],
          equals(['Alice', '+911234567890', 'alice@example.com']),
        );
      });

      test(
        'parses multiple XLSX sheets and preserves names and order',
        () async {
          final excel = Excel.createExcel();
          final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';

          final sheet1 = excel[defaultSheet];
          sheet1.updateCell(
            CellIndex.indexByString('A1'),
            TextCellValue('Leads Header'),
          );

          final sheet2 = excel['Archive'];
          sheet2.updateCell(
            CellIndex.indexByString('A1'),
            TextCellValue('Archive Header'),
          );

          final bytes = Uint8List.fromList(excel.encode()!);

          final file = createSelectedFile(
            name: 'workbook.xlsx',
            extension: 'xlsx',
            source: LeadSource.excel,
            bytes: bytes,
          );

          final parsed = await parser.parse(file);

          expect(parsed.sheets.length, equals(2));
          expect(parsed.sheets[0].name, equals(defaultSheet));
          expect(parsed.sheets[0].rows[0][0], equals('Leads Header'));

          expect(parsed.sheets[1].name, equals('Archive'));
          expect(parsed.sheets[1].rows[0][0], equals('Archive Header'));
        },
      );

      test('converts typed Excel cells without crashing', () async {
        final excel = Excel.createExcel();
        final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

        sheet.updateCell(CellIndex.indexByString('A1'), TextCellValue('Text'));
        sheet.updateCell(CellIndex.indexByString('B1'), const IntCellValue(42));
        sheet.updateCell(
          CellIndex.indexByString('C1'),
          const DoubleCellValue(99.5),
        );
        sheet.updateCell(
          CellIndex.indexByString('D1'),
          const BoolCellValue(true),
        );
        sheet.updateCell(
          CellIndex.indexByString('E1'),
          const DateCellValue(year: 2026, month: 9, day: 15),
        );
        sheet.updateCell(
          CellIndex.indexByString('F1'),
          const TimeCellValue(hour: 14, minute: 30, second: 0),
        );
        sheet.updateCell(
          CellIndex.indexByString('G1'),
          const DateTimeCellValue(
            year: 2026,
            month: 9,
            day: 15,
            hour: 10,
            minute: 15,
            second: 30,
          ),
        );

        final bytes = Uint8List.fromList(excel.encode()!);

        final file = createSelectedFile(
          name: 'typed.xlsx',
          extension: 'xlsx',
          source: LeadSource.excel,
          bytes: bytes,
        );

        final parsed = await parser.parse(file);
        final row = parsed.sheets.first.rows.first;

        expect(row[0], equals('Text'));
        expect(row[1], equals('42'));
        expect(row[2], equals('99.5'));
        expect(row[3], equals('true'));
        expect(row[4], equals('2026-09-15'));
        expect(row[5], equals('14:30:00'));
        expect(row[6], equals('2026-09-15T10:15:30'));
      });

      test(
        'preserves blank middle cell in XLSX row without shifting columns',
        () async {
          final excel = Excel.createExcel();
          final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

          sheet.updateCell(
            CellIndex.indexByString('A1'),
            TextCellValue('Alice'),
          );
          // B1 is left intentionally null/blank
          sheet.updateCell(
            CellIndex.indexByString('C1'),
            TextCellValue('alice@example.com'),
          );

          final bytes = Uint8List.fromList(excel.encode()!);

          final file = createSelectedFile(
            name: 'blank_cell.xlsx',
            extension: 'xlsx',
            source: LeadSource.excel,
            bytes: bytes,
          );

          final parsed = await parser.parse(file);
          final row = parsed.sheets.first.rows.first;

          expect(row.length, equals(3));
          expect(row, equals(['Alice', '', 'alice@example.com']));
        },
      );

      test('normalizes trailing cells to sheet maxColumns', () async {
        final excel = Excel.createExcel();
        final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

        // Row 1 uses 3 columns
        sheet.updateCell(CellIndex.indexByString('A1'), TextCellValue('Col1'));
        sheet.updateCell(CellIndex.indexByString('B1'), TextCellValue('Col2'));
        sheet.updateCell(CellIndex.indexByString('C1'), TextCellValue('Col3'));

        // Row 2 uses only 2 columns
        sheet.updateCell(CellIndex.indexByString('A2'), TextCellValue('Val1'));
        sheet.updateCell(CellIndex.indexByString('B2'), TextCellValue('Val2'));

        final bytes = Uint8List.fromList(excel.encode()!);

        final file = createSelectedFile(
          name: 'trailing.xlsx',
          extension: 'xlsx',
          source: LeadSource.excel,
          bytes: bytes,
        );

        final parsed = await parser.parse(file);
        final rows = parsed.sheets.first.rows;

        expect(rows[0].length, equals(3));
        expect(rows[1].length, equals(3));
        expect(rows[1], equals(['Val1', 'Val2', '']));
      });

      test(
        'preserves formula representation without evaluating or crashing',
        () async {
          final excel = Excel.createExcel();
          final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

          sheet.updateCell(
            CellIndex.indexByString('A1'),
            const IntCellValue(10),
          );
          sheet.updateCell(
            CellIndex.indexByString('A2'),
            const IntCellValue(20),
          );
          sheet.updateCell(
            CellIndex.indexByString('A3'),
            const FormulaCellValue('=SUM(A1:A2)'),
          );

          final bytes = Uint8List.fromList(excel.encode()!);

          final file = createSelectedFile(
            name: 'formula.xlsx',
            extension: 'xlsx',
            source: LeadSource.excel,
            bytes: bytes,
          );

          final parsed = await parser.parse(file);
          final rows = parsed.sheets.first.rows;

          expect(rows[2][0], equals('=SUM(A1:A2)'));
        },
      );

      test(
        'throws safe LeadImportParseException on corrupted XLSX archive',
        () async {
          final corruptedBytes = Uint8List.fromList([
            0x50,
            0x4B,
            0x03,
            0x04,
            0x00,
            0x00,
          ]);

          final file = createSelectedFile(
            name: 'broken.xlsx',
            extension: 'xlsx',
            source: LeadSource.excel,
            bytes: corruptedBytes,
          );

          expect(
            () => parser.parse(file),
            throwsA(
              isA<LeadImportParseException>().having(
                (e) => e.message,
                'message',
                equals('Unable to read this Excel file.'),
              ),
            ),
          );
        },
      );
    });

    group('Source / Extension Mismatches & Unsupported Files', () {
      test('rejects csv extension with LeadSource.excel', () async {
        final file = createSelectedFile(
          name: 'mismatch.csv',
          extension: 'csv',
          source: LeadSource.excel,
          bytes: Uint8List(10),
        );

        expect(
          () => parser.parse(file),
          throwsA(
            isA<LeadImportParseException>().having(
              (e) => e.message,
              'message',
              equals('Unsupported or inconsistent import file.'),
            ),
          ),
        );
      });

      test('rejects xlsx extension with LeadSource.csv', () async {
        final file = createSelectedFile(
          name: 'mismatch.xlsx',
          extension: 'xlsx',
          source: LeadSource.csv,
          bytes: Uint8List(10),
        );

        expect(
          () => parser.parse(file),
          throwsA(
            isA<LeadImportParseException>().having(
              (e) => e.message,
              'message',
              equals('Unsupported or inconsistent import file.'),
            ),
          ),
        );
      });

      test('rejects unsupported extension', () async {
        final file = createSelectedFile(
          name: 'data.txt',
          extension: 'txt',
          source: LeadSource.manual,
          bytes: Uint8List(10),
        );

        expect(
          () => parser.parse(file),
          throwsA(
            isA<LeadImportParseException>().having(
              (e) => e.message,
              'message',
              equals('Unsupported file type.'),
            ),
          ),
        );
      });
    });
  });
}
