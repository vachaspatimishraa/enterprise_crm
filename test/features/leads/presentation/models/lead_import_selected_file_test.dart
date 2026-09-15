import 'dart:typed_data';

import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_selected_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportSelectedFile', () {
    test('formats size correctly for bytes, kilobytes, and megabytes', () {
      final small = LeadImportSelectedFile(
        name: 'test.csv',
        extension: 'csv',
        sizeBytes: 512,
        source: LeadSource.csv,
        content: InMemoryLeadImportFileContent(Uint8List(0)),
      );
      expect(small.formattedSize, '512 B');

      final kb = LeadImportSelectedFile(
        name: 'test.xlsx',
        extension: 'xlsx',
        sizeBytes: 124 * 1024,
        source: LeadSource.excel,
        content: InMemoryLeadImportFileContent(Uint8List(0)),
      );
      expect(kb.formattedSize, '124 KB');

      final smallKb = LeadImportSelectedFile(
        name: 'test.csv',
        extension: 'csv',
        sizeBytes: 1536, // 1.5 KB
        source: LeadSource.csv,
        content: InMemoryLeadImportFileContent(Uint8List(0)),
      );
      expect(smallKb.formattedSize, '1.5 KB');

      final mb = LeadImportSelectedFile(
        name: 'large.xlsx',
        extension: 'xlsx',
        sizeBytes: 14 * 1024 * 1024,
        source: LeadSource.excel,
        content: InMemoryLeadImportFileContent(Uint8List(0)),
      );
      expect(mb.formattedSize, '14 MB');

      final smallMb = LeadImportSelectedFile(
        name: 'large.xlsx',
        extension: 'xlsx',
        sizeBytes: (2.5 * 1024 * 1024).round(),
        source: LeadSource.excel,
        content: InMemoryLeadImportFileContent(Uint8List(0)),
      );
      expect(smallMb.formattedSize, '2.5 MB');
    });

    test(
      'implements value equality based on metadata, independent of content instance',
      () {
        final file1 = LeadImportSelectedFile(
          name: 'leads.csv',
          extension: 'csv',
          sizeBytes: 1000,
          source: LeadSource.csv,
          content: InMemoryLeadImportFileContent(Uint8List(10)),
        );

        final file2 = LeadImportSelectedFile(
          name: 'leads.csv',
          extension: 'csv',
          sizeBytes: 1000,
          source: LeadSource.csv,
          content: InMemoryLeadImportFileContent(
            Uint8List(20),
          ), // different content instance
        );

        expect(file1, equals(file2));
        expect(file1.hashCode, equals(file2.hashCode));
        expect(file1.toString(), contains('leads.csv'));
      },
    );

    test(
      'InMemoryLeadImportFileContent streams and reads bytes correctly',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final content = InMemoryLeadImportFileContent(bytes);

        expect(await content.readAsBytes(), equals(bytes));
        expect(await content.readAsByteStream().first, equals(bytes));
      },
    );
  });
}
