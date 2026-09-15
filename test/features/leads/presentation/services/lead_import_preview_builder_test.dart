import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_parsed_file.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_preview.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_structure_analysis.dart';
import 'package:enterprise_crm/features/leads/presentation/services/lead_import_preview_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultLeadImportPreviewBuilder', () {
    const builder = DefaultLeadImportPreviewBuilder();

    const baseColumns = [
      LeadImportDiscoveredColumn(
        index: 0,
        rawHeader: 'Name',
        displayHeader: 'Name',
      ),
      LeadImportDiscoveredColumn(
        index: 1,
        rawHeader: 'Phone',
        displayHeader: 'Phone',
      ),
      LeadImportDiscoveredColumn(
        index: 2,
        rawHeader: 'Email',
        displayHeader: 'Email',
      ),
    ];

    test('builds valid preview rows with mapped fields', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'leads.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Name', 'Phone', 'Email'],
              ['Alice', '1234567890', 'alice@example.com'],
              ['Bob', '9876543210', 'bob@example.com'],
            ],
          ),
        ],
      );

      const analysis = LeadImportStructureAnalysis(
        fileName: 'leads.csv',
        source: LeadSource.csv,
        sheetIndex: 0,
        sheetName: 'CSV',
        headerRowIndex: 0,
        columns: baseColumns,
        dataRowCount: 2,
        issues: [],
      );

      const mapping = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
        phoneColumnIndex: 1,
        emailColumnIndex: 2,
      );

      final preview = builder.build(
        parsedFile: parsedFile,
        analysis: analysis,
        mapping: mapping,
      );

      expect(preview.totalRowCount, equals(2));
      expect(preview.validRowCount, equals(2));
      expect(preview.invalidRowCount, equals(0));
      expect(preview.blankRowCount, equals(0));

      expect(preview.rows[0].sourceRowIndex, equals(1));
      expect(preview.rows[0].displayRowNumber, equals(2));
      expect(preview.rows[0].name, equals('Alice'));
      expect(preview.rows[0].phone, equals('1234567890'));
      expect(preview.rows[0].email, equals('alice@example.com'));
      expect(preview.rows[0].status, equals(LeadImportPreviewRowStatus.valid));

      expect(preview.rows[1].sourceRowIndex, equals(2));
      expect(preview.rows[1].displayRowNumber, equals(3));
      expect(preview.rows[1].name, equals('Bob'));
      expect(preview.rows[1].status, equals(LeadImportPreviewRowStatus.valid));
    });

    test(
      'respects headerRowIndex offset and does not process header or preceding rows',
      () {
        final parsedFile = LeadImportParsedFile(
          fileName: 'report.xlsx',
          source: LeadSource.excel,
          sheets: [
            LeadImportParsedSheet(
              name: 'Sheet1',
              rows: [
                ['Report generated on 2026-09-15'],
                ['Name', 'Phone'],
                ['Alice', '123'],
                ['Bob', '456'],
              ],
            ),
          ],
        );

        const analysis = LeadImportStructureAnalysis(
          fileName: 'report.xlsx',
          source: LeadSource.excel,
          sheetIndex: 0,
          sheetName: 'Sheet1',
          headerRowIndex: 1, // Header is row 1
          columns: [
            LeadImportDiscoveredColumn(
              index: 0,
              rawHeader: 'Name',
              displayHeader: 'Name',
            ),
            LeadImportDiscoveredColumn(
              index: 1,
              rawHeader: 'Phone',
              displayHeader: 'Phone',
            ),
          ],
          dataRowCount: 2,
          issues: [],
        );

        const mapping = LeadImportColumnMapping(
          sheetIndex: 0,
          headerRowIndex: 1,
          nameColumnIndex: 0,
          phoneColumnIndex: 1,
        );

        final preview = builder.build(
          parsedFile: parsedFile,
          analysis: analysis,
          mapping: mapping,
        );

        expect(preview.totalRowCount, equals(2));
        expect(preview.rows[0].sourceRowIndex, equals(2));
        expect(preview.rows[0].displayRowNumber, equals(3));
        expect(preview.rows[0].name, equals('Alice'));

        expect(preview.rows[1].sourceRowIndex, equals(3));
        expect(preview.rows[1].displayRowNumber, equals(4));
        expect(preview.rows[1].name, equals('Bob'));
      },
    );

    test(
      'trims mapped values while preserving original parsed data without mutation',
      () {
        final parsedFile = LeadImportParsedFile(
          fileName: 'leads.csv',
          source: LeadSource.csv,
          sheets: [
            LeadImportParsedSheet(
              name: 'CSV',
              rows: [
                ['Name', 'Phone', 'Email'],
                ['  Alice  ', '  123  ', '  alice@example.com  '],
              ],
            ),
          ],
        );

        const analysis = LeadImportStructureAnalysis(
          fileName: 'leads.csv',
          source: LeadSource.csv,
          sheetIndex: 0,
          sheetName: 'CSV',
          headerRowIndex: 0,
          columns: baseColumns,
          dataRowCount: 1,
          issues: [],
        );

        const mapping = LeadImportColumnMapping(
          sheetIndex: 0,
          headerRowIndex: 0,
          nameColumnIndex: 0,
          phoneColumnIndex: 1,
          emailColumnIndex: 2,
        );

        final preview = builder.build(
          parsedFile: parsedFile,
          analysis: analysis,
          mapping: mapping,
        );

        // Normalized in preview
        expect(preview.rows[0].name, equals('Alice'));
        expect(preview.rows[0].phone, equals('123'));
        expect(preview.rows[0].email, equals('alice@example.com'));

        // Original parsed file remains unmutated
        expect(parsedFile.sheets[0].rows[1][0], equals('  Alice  '));
        expect(parsedFile.sheets[0].rows[1][1], equals('  123  '));
        expect(
          parsedFile.sheets[0].rows[1][2],
          equals('  alice@example.com  '),
        );
      },
    );

    test('handles short data rows safely without RangeError', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'short.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Name', 'Phone', 'Email'],
              ['Alice'], // Missing phone and email columns
            ],
          ),
        ],
      );

      const analysis = LeadImportStructureAnalysis(
        fileName: 'short.csv',
        source: LeadSource.csv,
        sheetIndex: 0,
        sheetName: 'CSV',
        headerRowIndex: 0,
        columns: baseColumns,
        dataRowCount: 1,
        issues: [],
      );

      const mapping = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
        phoneColumnIndex: 1,
        emailColumnIndex: 2,
      );

      final preview = builder.build(
        parsedFile: parsedFile,
        analysis: analysis,
        mapping: mapping,
      );

      expect(preview.rows[0].name, equals('Alice'));
      expect(preview.rows[0].phone, equals(''));
      expect(preview.rows[0].email, equals(''));
      expect(preview.rows[0].status, equals(LeadImportPreviewRowStatus.valid));
    });

    test('preserves mapped-empty vs unmapped distinction', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'leads.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Name', 'Phone', 'Email'],
              ['Alice', '', 'alice@example.com'],
            ],
          ),
        ],
      );

      const analysis = LeadImportStructureAnalysis(
        fileName: 'leads.csv',
        source: LeadSource.csv,
        sheetIndex: 0,
        sheetName: 'CSV',
        headerRowIndex: 0,
        columns: baseColumns,
        dataRowCount: 1,
        issues: [],
      );

      // Mapping without Phone
      const mapping = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
        phoneColumnIndex: null, // Unmapped!
        emailColumnIndex: 2, // Mapped!
      );

      final preview = builder.build(
        parsedFile: parsedFile,
        analysis: analysis,
        mapping: mapping,
      );

      expect(preview.rows[0].name, equals('Alice'));
      expect(preview.rows[0].phone, isNull); // unmapped target is null
      expect(preview.rows[0].email, equals('alice@example.com'));
    });

    test('single-field mappings are valid without requiring other fields', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'single.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Name', 'Phone', 'Email'],
              ['Alice', '', ''],
              ['', '12345', ''],
              ['', '', 'alice@test.com'],
            ],
          ),
        ],
      );

      const analysis = LeadImportStructureAnalysis(
        fileName: 'single.csv',
        source: LeadSource.csv,
        sheetIndex: 0,
        sheetName: 'CSV',
        headerRowIndex: 0,
        columns: baseColumns,
        dataRowCount: 3,
        issues: [],
      );

      const mapping = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
        phoneColumnIndex: 1,
        emailColumnIndex: 2,
      );

      final preview = builder.build(
        parsedFile: parsedFile,
        analysis: analysis,
        mapping: mapping,
      );

      // Row 1: only name -> valid
      expect(preview.rows[0].status, equals(LeadImportPreviewRowStatus.valid));
      // Row 2: only phone -> valid
      expect(preview.rows[1].status, equals(LeadImportPreviewRowStatus.valid));
      // Row 3: only email -> valid
      expect(preview.rows[2].status, equals(LeadImportPreviewRowStatus.valid));
      expect(preview.validRowCount, equals(3));
    });

    test('invalid email marks row as invalid with field issue', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'invalid_email.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Name', 'Phone', 'Email'],
              ['Alice', '123', 'not-an-email'],
            ],
          ),
        ],
      );

      const analysis = LeadImportStructureAnalysis(
        fileName: 'invalid_email.csv',
        source: LeadSource.csv,
        sheetIndex: 0,
        sheetName: 'CSV',
        headerRowIndex: 0,
        columns: baseColumns,
        dataRowCount: 1,
        issues: [],
      );

      const mapping = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
        phoneColumnIndex: 1,
        emailColumnIndex: 2,
      );

      final preview = builder.build(
        parsedFile: parsedFile,
        analysis: analysis,
        mapping: mapping,
      );

      expect(
        preview.rows[0].status,
        equals(LeadImportPreviewRowStatus.invalid),
      );
      expect(preview.invalidRowCount, equals(1));
      expect(preview.validRowCount, equals(0));
      expect(preview.rows[0].issues.length, equals(1));
      expect(
        preview.rows[0].issues[0].field,
        equals(LeadImportTargetField.email),
      );
      expect(
        preview.rows[0].issues[0].severity,
        equals(LeadImportPreviewIssueSeverity.error),
      );
      expect(
        preview.rows[0].issues[0].message,
        equals('Invalid email address.'),
      );
    });

    test('blank row detection runs before email validation', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'blank_email.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Email'],
              ['   '],
            ],
          ),
        ],
      );

      const analysis = LeadImportStructureAnalysis(
        fileName: 'blank_email.csv',
        source: LeadSource.csv,
        sheetIndex: 0,
        sheetName: 'CSV',
        headerRowIndex: 0,
        columns: [
          LeadImportDiscoveredColumn(
            index: 0,
            rawHeader: 'Email',
            displayHeader: 'Email',
          ),
        ],
        dataRowCount: 1,
        issues: [],
      );

      const mapping = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        emailColumnIndex: 0,
      );

      final preview = builder.build(
        parsedFile: parsedFile,
        analysis: analysis,
        mapping: mapping,
      );

      // Must be blank, NOT invalid
      expect(preview.rows[0].status, equals(LeadImportPreviewRowStatus.blank));
      expect(preview.blankRowCount, equals(1));
      expect(preview.invalidRowCount, equals(0));
      expect(
        preview.rows[0].issues[0].message,
        contains('No mapped Lead values'),
      );
    });

    test('unmapped columns do not make an otherwise blank row valid', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'unmapped.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['UnmappedCol', 'Phone'],
              [
                'Some Business Name',
                '   ',
              ], // Column 0 has data, but only Phone (col 1) is mapped!
            ],
          ),
        ],
      );

      const analysis = LeadImportStructureAnalysis(
        fileName: 'unmapped.csv',
        source: LeadSource.csv,
        sheetIndex: 0,
        sheetName: 'CSV',
        headerRowIndex: 0,
        columns: [
          LeadImportDiscoveredColumn(
            index: 0,
            rawHeader: 'UnmappedCol',
            displayHeader: 'UnmappedCol',
          ),
          LeadImportDiscoveredColumn(
            index: 1,
            rawHeader: 'Phone',
            displayHeader: 'Phone',
          ),
        ],
        dataRowCount: 1,
        issues: [],
      );

      const mapping = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        phoneColumnIndex: 1,
      );

      final preview = builder.build(
        parsedFile: parsedFile,
        analysis: analysis,
        mapping: mapping,
      );

      // Must be blank because only mapped field (phone) has no content
      expect(preview.rows[0].status, equals(LeadImportPreviewRowStatus.blank));
      expect(preview.blankRowCount, equals(1));
      expect(preview.validRowCount, equals(0));
    });

    test('does NOT perform duplicate detection across rows', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'dups.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Name', 'Phone'],
              ['Alice', '123'],
              ['Alice', '123'],
            ],
          ),
        ],
      );

      const analysis = LeadImportStructureAnalysis(
        fileName: 'dups.csv',
        source: LeadSource.csv,
        sheetIndex: 0,
        sheetName: 'CSV',
        headerRowIndex: 0,
        columns: [
          LeadImportDiscoveredColumn(
            index: 0,
            rawHeader: 'Name',
            displayHeader: 'Name',
          ),
          LeadImportDiscoveredColumn(
            index: 1,
            rawHeader: 'Phone',
            displayHeader: 'Phone',
          ),
        ],
        dataRowCount: 2,
        issues: [],
      );

      const mapping = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
        phoneColumnIndex: 1,
      );

      final preview = builder.build(
        parsedFile: parsedFile,
        analysis: analysis,
        mapping: mapping,
      );

      expect(preview.validRowCount, equals(2));
      expect(preview.rows[0].status, equals(LeadImportPreviewRowStatus.valid));
      expect(preview.rows[1].status, equals(LeadImportPreviewRowStatus.valid));
    });

    test('reconciles summary counts across mixed rows', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'mixed.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Name', 'Email'],
              ['Alice', 'alice@test.com'], // valid
              ['Bob', 'bob@test.com'], // valid
              ['InvalidGuy', 'bad-email'], // invalid
              ['', '   '], // blank
              ['', ''], // blank
            ],
          ),
        ],
      );

      const analysis = LeadImportStructureAnalysis(
        fileName: 'mixed.csv',
        source: LeadSource.csv,
        sheetIndex: 0,
        sheetName: 'CSV',
        headerRowIndex: 0,
        columns: [
          LeadImportDiscoveredColumn(
            index: 0,
            rawHeader: 'Name',
            displayHeader: 'Name',
          ),
          LeadImportDiscoveredColumn(
            index: 1,
            rawHeader: 'Email',
            displayHeader: 'Email',
          ),
        ],
        dataRowCount: 5,
        issues: [],
      );

      const mapping = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
        emailColumnIndex: 1,
      );

      final preview = builder.build(
        parsedFile: parsedFile,
        analysis: analysis,
        mapping: mapping,
      );

      expect(preview.totalRowCount, equals(5));
      expect(preview.validRowCount, equals(2));
      expect(preview.invalidRowCount, equals(1));
      expect(preview.blankRowCount, equals(2));
      expect(
        preview.validRowCount + preview.invalidRowCount + preview.blankRowCount,
        equals(preview.totalRowCount),
      );
    });

    group('defensive workflow validation / staleness checks', () {
      final validParsed = LeadImportParsedFile(
        fileName: 'leads.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'SheetA',
            rows: [
              ['Name'],
              ['Alice'],
            ],
          ),
        ],
      );

      const validAnalysis = LeadImportStructureAnalysis(
        fileName: 'leads.csv',
        source: LeadSource.csv,
        sheetIndex: 0,
        sheetName: 'SheetA',
        headerRowIndex: 0,
        columns: [
          LeadImportDiscoveredColumn(
            index: 0,
            rawHeader: 'Name',
            displayHeader: 'Name',
          ),
        ],
        dataRowCount: 1,
        issues: [],
      );

      const validMapping = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
      );

      test('rejects fileName mismatch', () {
        expect(
          () => builder.build(
            parsedFile: validParsed,
            analysis: const LeadImportStructureAnalysis(
              fileName: 'different.csv',
              source: LeadSource.csv,
              sheetIndex: 0,
              sheetName: 'SheetA',
              headerRowIndex: 0,
              columns: [],
              dataRowCount: 0,
              issues: [],
            ),
            mapping: validMapping,
          ),
          throwsA(isA<LeadImportPreviewException>()),
        );
      });

      test('rejects source mismatch', () {
        expect(
          () => builder.build(
            parsedFile: validParsed,
            analysis: const LeadImportStructureAnalysis(
              fileName: 'leads.csv',
              source: LeadSource.excel, // Mismatch!
              sheetIndex: 0,
              sheetName: 'SheetA',
              headerRowIndex: 0,
              columns: [],
              dataRowCount: 0,
              issues: [],
            ),
            mapping: validMapping,
          ),
          throwsA(isA<LeadImportPreviewException>()),
        );
      });

      test('rejects blocking errors in analysis', () {
        expect(
          () => builder.build(
            parsedFile: validParsed,
            analysis: const LeadImportStructureAnalysis(
              fileName: 'leads.csv',
              source: LeadSource.csv,
              sheetIndex: 0,
              sheetName: 'SheetA',
              headerRowIndex: 0,
              columns: [],
              dataRowCount: 0,
              issues: [
                LeadImportStructureIssue(
                  severity: LeadImportStructureIssueSeverity.error,
                  message: 'Blocking error',
                ),
              ],
            ),
            mapping: validMapping,
          ),
          throwsA(isA<LeadImportPreviewException>()),
        );
      });

      test('rejects sheetIndex out of bounds', () {
        expect(
          () => builder.build(
            parsedFile: validParsed,
            analysis: validAnalysis,
            mapping: const LeadImportColumnMapping(
              sheetIndex: 99,
              headerRowIndex: 0,
              nameColumnIndex: 0,
            ),
          ),
          throwsA(isA<LeadImportPreviewException>()),
        );
      });

      test('rejects sheetName mismatch against actual parsed sheet', () {
        expect(
          () => builder.build(
            parsedFile: validParsed,
            analysis: const LeadImportStructureAnalysis(
              fileName: 'leads.csv',
              source: LeadSource.csv,
              sheetIndex: 0,
              sheetName: 'MismatchedSheetName',
              headerRowIndex: 0,
              columns: [
                LeadImportDiscoveredColumn(
                  index: 0,
                  rawHeader: 'Name',
                  displayHeader: 'Name',
                ),
              ],
              dataRowCount: 1,
              issues: [],
            ),
            mapping: validMapping,
          ),
          throwsA(isA<LeadImportPreviewException>()),
        );
      });

      test('rejects null sheetName in analysis', () {
        expect(
          () => builder.build(
            parsedFile: validParsed,
            analysis: const LeadImportStructureAnalysis(
              fileName: 'leads.csv',
              source: LeadSource.csv,
              sheetIndex: 0,
              sheetName: null,
              headerRowIndex: 0,
              columns: [],
              dataRowCount: 0,
              issues: [],
            ),
            mapping: validMapping,
          ),
          throwsA(isA<LeadImportPreviewException>()),
        );
      });

      test('rejects headerRowIndex outside actual sheet rows', () {
        expect(
          () => builder.build(
            parsedFile: validParsed,
            analysis: const LeadImportStructureAnalysis(
              fileName: 'leads.csv',
              source: LeadSource.csv,
              sheetIndex: 0,
              sheetName: 'SheetA',
              headerRowIndex: 999, // Impossible row index
              columns: [],
              dataRowCount: 0,
              issues: [],
            ),
            mapping: const LeadImportColumnMapping(
              sheetIndex: 0,
              headerRowIndex: 999,
              nameColumnIndex: 0,
            ),
          ),
          throwsA(isA<LeadImportPreviewException>()),
        );
      });

      test('rejects analysis column index outside actual sheet width', () {
        expect(
          () => builder.build(
            parsedFile: validParsed,
            analysis: const LeadImportStructureAnalysis(
              fileName: 'leads.csv',
              source: LeadSource.csv,
              sheetIndex: 0,
              sheetName: 'SheetA',
              headerRowIndex: 0,
              columns: [
                LeadImportDiscoveredColumn(
                  index: 999, // Outside actual width (which is 1)
                  rawHeader: 'Name',
                  displayHeader: 'Name',
                ),
              ],
              dataRowCount: 1,
              issues: [],
            ),
            mapping: const LeadImportColumnMapping(
              sheetIndex: 0,
              headerRowIndex: 0,
              nameColumnIndex: 999,
            ),
          ),
          throwsA(isA<LeadImportPreviewException>()),
        );
      });

      test('rejects duplicate source column mappings in mapping object', () {
        expect(
          () => builder.build(
            parsedFile: validParsed,
            analysis: validAnalysis,
            mapping: const LeadImportColumnMapping(
              sheetIndex: 0,
              headerRowIndex: 0,
              nameColumnIndex: 0,
              phoneColumnIndex: 0, // Duplicate source column 0!
            ),
          ),
          throwsA(isA<LeadImportPreviewException>()),
        );
      });
    });
  });
}
