import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_parsed_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportParsedSheet & LeadImportParsedFile', () {
    test('LeadImportParsedSheet equality and string representation', () {
      final sheet1 = LeadImportParsedSheet(
        name: 'Leads',
        rows: [
          ['Name', 'Email'],
          ['Alice', 'alice@example.com'],
        ],
      );

      final sheet2 = LeadImportParsedSheet(
        name: 'Leads',
        rows: [
          ['Name', 'Email'],
          ['Alice', 'alice@example.com'],
        ],
      );

      final sheetDiff = LeadImportParsedSheet(
        name: 'Leads',
        rows: [
          ['Name', 'Email'],
          ['Bob', 'bob@example.com'],
        ],
      );

      expect(sheet1, equals(sheet2));
      expect(sheet1.hashCode, equals(sheet2.hashCode));
      expect(sheet1, isNot(equals(sheetDiff)));
      expect(sheet1.toString(), contains('Leads'));
    });

    test('LeadImportParsedFile equality and properties', () {
      final sheet = LeadImportParsedSheet(
        name: 'Sheet1',
        rows: [
          ['Col1', 'Col2'],
        ],
      );

      final file1 = LeadImportParsedFile(
        fileName: 'data.xlsx',
        source: LeadSource.excel,
        sheets: [sheet],
      );

      final file2 = LeadImportParsedFile(
        fileName: 'data.xlsx',
        source: LeadSource.excel,
        sheets: [sheet],
      );

      final fileDiff = LeadImportParsedFile(
        fileName: 'other.xlsx',
        source: LeadSource.excel,
        sheets: [sheet],
      );

      expect(file1, equals(file2));
      expect(file1.hashCode, equals(file2.hashCode));
      expect(file1, isNot(equals(fileDiff)));
      expect(file1.toString(), contains('data.xlsx'));
    });
  });
}
