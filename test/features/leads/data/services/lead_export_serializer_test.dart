import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:enterprise_crm/features/leads/data/services/lead_export_serializer.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const serializer = DefaultLeadExportSerializer();

  // Helper to extract text from a CellValue
  String cellToString(CellValue? cellValue) {
    if (cellValue == null) return '';
    switch (cellValue) {
      case TextCellValue(:final value):
        return value.toString();
      case IntCellValue(:final value):
        return value.toString();
      case DoubleCellValue(:final value):
        return value.toString();
      case DateCellValue(:final year, :final month, :final day):
        return '$year-$month-$day';
      case DateTimeCellValue(:final year, :final month, :final day):
        return '$year-$month-$day';
      case BoolCellValue(:final value):
        return value.toString();
      case FormulaCellValue(:final formula):
        return formula;
      default:
        return cellValue.toString();
    }
  }

  // Helper to decode CSV bytes to List<List<String>>
  List<List<String>> decodeCsv(Uint8List bytes) {
    final csvString = utf8.decode(bytes);
    const decoder = CsvDecoder(
      dynamicTyping: false,
      parseHeaders: false,
      skipEmptyLines: false,
    );
    final rawRows = decoder.convert(csvString);
    return rawRows
        .map((row) => row.map((cell) => cell?.toString() ?? '').toList())
        .toList();
  }

  // Helper to decode XLSX bytes and extract sheet rows as List<List<String>>
  List<List<String>> decodeXlsx(Uint8List bytes, {String sheetName = 'Leads'}) {
    final excel = Excel.decodeBytes(bytes);
    expect(
      excel.tables.containsKey(sheetName),
      isTrue,
      reason: 'Expected sheet "$sheetName" to exist in workbook',
    );
    final sheet = excel.tables[sheetName]!;
    final rows = <List<String>>[];
    for (final rawRow in sheet.rows) {
      rows.add(rawRow.map((cell) => cellToString(cell?.value)).toList());
    }
    return rows;
  }

  group('DefaultLeadExportSerializer - Column Policy & Metadata', () {
    test('defines exact frozen L7A headers in specified order', () {
      expect(DefaultLeadExportSerializer.exportHeaders, [
        'Name',
        'Phone',
        'Email',
        'Status',
        'Source',
        'Assigned To',
        'Created At',
        'Updated At',
      ]);
    });

    test('returns correct MIME type and file extension for CSV', () {
      final content = serializer.serialize(
        leads: const [],
        format: LeadExportFormat.csv,
      );

      expect(content.extension, 'csv');
      expect(content.mimeType, 'text/csv');
    });

    test('returns correct MIME type and file extension for Excel', () {
      final content = serializer.serialize(
        leads: const [],
        format: LeadExportFormat.excel,
      );

      expect(content.extension, 'xlsx');
      expect(
        content.mimeType,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    });

    test(
      'serializes empty lead list to headers-only output for both formats',
      () {
        final csvContent = serializer.serialize(
          leads: const [],
          format: LeadExportFormat.csv,
        );
        final csvRows = decodeCsv(csvContent.bytes);
        expect(csvRows.length, 1);
        expect(csvRows.first, DefaultLeadExportSerializer.exportHeaders);

        final xlsxContent = serializer.serialize(
          leads: const [],
          format: LeadExportFormat.excel,
        );
        final xlsxRows = decodeXlsx(xlsxContent.bytes);
        expect(xlsxRows.length, 1);
        expect(xlsxRows.first, DefaultLeadExportSerializer.exportHeaders);
      },
    );
  });

  group('DefaultLeadExportSerializer - CSV Export', () {
    test(
      'exports complete lead with exact column order, formatting, and values',
      () {
        final lead = Lead(
          id: 'internal-lead-id-12345',
          name: 'Alice Johnson',
          phone: '+919876543210',
          email: 'alice@example.com',
          status: const LeadStatus('custom-in-progress'),
          source: LeadSource.manual,
          assignedUserId: 'internal-user-999',
          assignedUserName: 'Bob Agent',
          createdAt: DateTime.utc(2026, 3, 15, 10, 30, 0),
          updatedAt: DateTime.utc(2026, 3, 16, 14, 45, 0),
        );

        final content = serializer.serialize(
          leads: [lead],
          format: LeadExportFormat.csv,
        );
        final rows = decodeCsv(content.bytes);

        expect(rows.length, 2);
        expect(rows[0], DefaultLeadExportSerializer.exportHeaders);
        expect(rows[1], [
          'Alice Johnson',
          '+919876543210',
          'alice@example.com',
          'custom-in-progress',
          'manual',
          'Bob Agent',
          '2026-03-15T10:30:00.000Z',
          '2026-03-16T14:45:00.000Z',
        ]);
      },
    );

    test(
      'preserves phone numbers with leading zeroes and special characters',
      () {
        final leads = [
          const Lead(id: '1', phone: '0012345678'),
          const Lead(id: '2', phone: '+1 (555) 234-5678'),
          const Lead(id: '3', phone: '0123 456 789'),
        ];

        final content = serializer.serialize(
          leads: leads,
          format: LeadExportFormat.csv,
        );
        final rows = decodeCsv(content.bytes);

        expect(rows[1][1], '0012345678');
        expect(rows[2][1], '+1 (555) 234-5678');
        expect(rows[3][1], '0123 456 789');
      },
    );

    test(
      'serializes null and unassigned fields as empty cells, never literal null/N/A',
      () {
        const lead = Lead(
          id: 'sparse-1',
          name: null,
          phone: null,
          email: null,
          status: null,
          source: LeadSource.csv,
          assignedUserId: null,
          assignedUserName: null,
          createdAt: null,
          updatedAt: null,
        );

        final content = serializer.serialize(
          leads: const [lead],
          format: LeadExportFormat.csv,
        );
        final rows = decodeCsv(content.bytes);

        expect(rows.length, 2);
        expect(rows[1], [
          '', // Name
          '', // Phone
          '', // Email
          '', // Status
          'csv', // Source
          '', // Assigned To
          '', // Created At
          '', // Updated At
        ]);
        // Verify no literal 'null', 'N/A', or '-' was serialized
        for (final cell in rows[1]) {
          expect(cell, isNot(contains('null')));
          expect(cell, isNot(contains('N/A')));
        }
      },
    );

    test(
      'properly escapes commas, quotes, newlines, and preserves Unicode characters',
      () {
        final lead = Lead(
          id: 'complex-1',
          name: 'Smith, "The Agent"\nConsultant',
          phone: '+44 20 7946 0919',
          email: 'agent"smith"@test.com, alternate@test.com',
          status: const LeadStatus('En révision / 待处理 🚀'),
          source: LeadSource.excel,
          assignedUserName: 'Dr. René François Müller',
          createdAt: DateTime.utc(2026, 9, 19, 8, 0, 0),
        );

        final content = serializer.serialize(
          leads: [lead],
          format: LeadExportFormat.csv,
        );
        final rows = decodeCsv(content.bytes);

        expect(rows.length, 2);
        expect(rows[1][0], 'Smith, "The Agent"\nConsultant');
        expect(rows[1][2], 'agent"smith"@test.com, alternate@test.com');
        expect(rows[1][3], 'En révision / 待处理 🚀');
        expect(rows[1][4], 'excel');
        expect(rows[1][5], 'Dr. René François Müller');
      },
    );

    test('preserves input row ordering deterministically without sorting', () {
      final leads = [
        const Lead(id: 'z-3', name: 'Zack'),
        const Lead(id: 'a-1', name: 'Aaron'),
        const Lead(id: 'm-2', name: 'Mary'),
      ];

      final content = serializer.serialize(
        leads: leads,
        format: LeadExportFormat.csv,
      );
      final rows = decodeCsv(content.bytes);

      expect(rows[1][0], 'Zack');
      expect(rows[2][0], 'Aaron');
      expect(rows[3][0], 'Mary');
    });
  });

  group('DefaultLeadExportSerializer - XLSX Export', () {
    test('exports complete lead to XLSX sheet "Leads" with correct cells', () {
      final lead = Lead(
        id: 'internal-id-456',
        name: 'Bob Builder',
        phone: '+447911123456',
        email: 'bob@builder.org',
        status: const LeadStatus('contract-sent'),
        source: LeadSource.excel,
        assignedUserId: 'user-77',
        assignedUserName: 'Sarah Connor',
        createdAt: DateTime.utc(2026, 1, 10, 12, 0, 0),
        updatedAt: DateTime.utc(2026, 1, 12, 16, 30, 0),
      );

      final content = serializer.serialize(
        leads: [lead],
        format: LeadExportFormat.excel,
      );
      final rows = decodeXlsx(content.bytes);

      expect(rows.length, 2);
      expect(rows[0], DefaultLeadExportSerializer.exportHeaders);
      expect(rows[1], [
        'Bob Builder',
        '+447911123456',
        'bob@builder.org',
        'contract-sent',
        'excel',
        'Sarah Connor',
        '2026-01-10T12:00:00.000Z',
        '2026-01-12T16:30:00.000Z',
      ]);
    });

    test('preserves phone leading zeroes and + sign in XLSX cells', () {
      final leads = [
        const Lead(id: '1', phone: '00491234567'),
        const Lead(id: '2', phone: '+18005550199'),
      ];

      final content = serializer.serialize(
        leads: leads,
        format: LeadExportFormat.excel,
      );
      final rows = decodeXlsx(content.bytes);

      expect(rows[1][1], '00491234567');
      expect(rows[2][1], '+18005550199');
    });

    test('serializes null lead fields as empty cells in XLSX', () {
      const lead = Lead(
        id: 'null-fields-lead',
        name: null,
        phone: null,
        email: null,
        status: null,
        source: LeadSource.manual,
        assignedUserId: null,
        assignedUserName: null,
        createdAt: null,
        updatedAt: null,
      );

      final content = serializer.serialize(
        leads: const [lead],
        format: LeadExportFormat.excel,
      );
      final rows = decodeXlsx(content.bytes);

      expect(rows.length, 2);
      expect(rows[1], ['', '', '', '', 'manual', '', '', '']);
      for (final cell in rows[1]) {
        expect(cell, isNot(contains('null')));
        expect(cell, isNot(contains('N/A')));
      }
    });

    test('preserves Unicode and special characters in XLSX', () {
      final lead = Lead(
        id: 'unicode-xlsx',
        name: '山田 太郎 / José García',
        phone: '+81 3 1234 5678',
        email: 'taro@example.jp',
        status: const LeadStatus('商談中 (In Negotiation) 💼'),
        source: LeadSource.csv,
        assignedUserName: 'María Hernández',
      );

      final content = serializer.serialize(
        leads: [lead],
        format: LeadExportFormat.excel,
      );
      final rows = decodeXlsx(content.bytes);

      expect(rows[1][0], '山田 太郎 / José García');
      expect(rows[1][1], '+81 3 1234 5678');
      expect(rows[1][3], '商談中 (In Negotiation) 💼');
      expect(rows[1][4], 'csv');
      expect(rows[1][5], 'María Hernández');
    });

    test('preserves input row ordering in XLSX without sorting', () {
      final leads = [
        const Lead(id: '3', name: 'Gamma'),
        const Lead(id: '1', name: 'Alpha'),
        const Lead(id: '2', name: 'Beta'),
      ];

      final content = serializer.serialize(
        leads: leads,
        format: LeadExportFormat.excel,
      );
      final rows = decodeXlsx(content.bytes);

      expect(rows[1][0], 'Gamma');
      expect(rows[2][0], 'Alpha');
      expect(rows[3][0], 'Beta');
    });
  });

  group(
    'DefaultLeadExportSerializer - Cross-Format Consistency & Exclusion of Internal IDs',
    () {
      test(
        'produces semantically identical rows across CSV and XLSX for the same input',
        () {
          final leads = [
            Lead(
              id: 'lead-secret-uuid-1',
              name: 'Jane Doe',
              phone: '+14155552671',
              email: 'jane@enterprise.test',
              status: const LeadStatus('verified-qualified'),
              source: LeadSource.manual,
              assignedUserId: 'agent-secret-id-42',
              assignedUserName: 'Alex Agent',
              createdAt: DateTime.utc(2026, 4, 1, 9, 0, 0),
              updatedAt: DateTime.utc(2026, 4, 2, 11, 30, 0),
            ),
            const Lead(
              id: 'lead-secret-uuid-2',
              name: 'Sparse Lead',
              source: LeadSource.csv,
            ),
          ];

          final csvContent = serializer.serialize(
            leads: leads,
            format: LeadExportFormat.csv,
          );
          final xlsxContent = serializer.serialize(
            leads: leads,
            format: LeadExportFormat.excel,
          );

          final csvRows = decodeCsv(csvContent.bytes);
          final xlsxRows = decodeXlsx(xlsxContent.bytes);

          expect(csvRows.length, xlsxRows.length);
          for (var r = 0; r < csvRows.length; r++) {
            expect(
              csvRows[r],
              xlsxRows[r],
              reason: 'Row $r should match across CSV and XLSX',
            );
          }
        },
      );

      test(
        'strictly excludes lead.id and assignedUserId from headers and row values in both formats',
        () {
          final lead = Lead(
            id: 'TOP-SECRET-LEAD-ID-999',
            name: 'Exclusion Test',
            phone: '12345',
            assignedUserId: 'TOP-SECRET-USER-ID-888',
            assignedUserName: 'Public Agent Name',
          );

          final csvContent = serializer.serialize(
            leads: [lead],
            format: LeadExportFormat.csv,
          );
          final xlsxContent = serializer.serialize(
            leads: [lead],
            format: LeadExportFormat.excel,
          );

          final csvText = utf8.decode(csvContent.bytes);
          expect(csvText, isNot(contains('TOP-SECRET-LEAD-ID-999')));
          expect(csvText, isNot(contains('TOP-SECRET-USER-ID-888')));
          expect(csvText, isNot(contains('id')));
          expect(csvText, isNot(contains('assignedUserId')));

          final xlsxRows = decodeXlsx(xlsxContent.bytes);
          for (final row in xlsxRows) {
            for (final cell in row) {
              expect(cell, isNot(contains('TOP-SECRET-LEAD-ID-999')));
              expect(cell, isNot(contains('TOP-SECRET-USER-ID-888')));
            }
          }
        },
      );
    },
  );
}
