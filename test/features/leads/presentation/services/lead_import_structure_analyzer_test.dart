import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_parsed_file.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_structure_analysis.dart';
import 'package:enterprise_crm/features/leads/presentation/services/lead_import_structure_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultLeadImportStructureAnalyzer', () {
    const analyzer = DefaultLeadImportStructureAnalyzer();

    test('analyzes basic valid structure without inferring Lead mapping', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'leads.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Name', 'Phone', 'Email'],
              ['Alice', '+911234567890', 'alice@example.com'],
            ],
          ),
        ],
      );

      final analysis = analyzer.analyze(
        parsedFile: parsedFile,
        sheetIndex: 0,
        headerRowIndex: 0,
      );

      expect(analysis.fileName, equals('leads.csv'));
      expect(analysis.source, equals(LeadSource.csv));
      expect(analysis.sheetIndex, equals(0));
      expect(analysis.sheetName, equals('CSV'));
      expect(analysis.headerRowIndex, equals(0));
      expect(analysis.columns.length, equals(3));
      expect(analysis.columns[0].displayHeader, equals('Name'));
      expect(analysis.columns[0].index, equals(0));
      expect(analysis.columns[1].displayHeader, equals('Phone'));
      expect(analysis.columns[1].index, equals(1));
      expect(analysis.columns[2].displayHeader, equals('Email'));
      expect(analysis.columns[2].index, equals(2));
      expect(analysis.dataRowCount, equals(1));
      expect(analysis.issues, isEmpty);
      expect(analysis.hasBlockingErrors, isFalse);
      expect(analysis.isValid, isTrue);
    });

    test(
      'supports header on a later row and does not treat row 0 as permanent header',
      () {
        final parsedFile = LeadImportParsedFile(
          fileName: 'custom_header.xlsx',
          source: LeadSource.excel,
          sheets: [
            LeadImportParsedSheet(
              name: 'Sheet1',
              rows: [
                ['Report generated on 2026-09-15', ''],
                ['Customer Name', 'Contact Number'],
                ['Acme Corp', '9876543210'],
                ['Beta LLC', '1234567890'],
              ],
            ),
          ],
        );

        final analysis = analyzer.analyze(
          parsedFile: parsedFile,
          sheetIndex: 0,
          headerRowIndex: 1,
        );

        expect(analysis.headerRowIndex, equals(1));
        expect(analysis.columns.length, equals(2));
        expect(analysis.columns[0].displayHeader, equals('Customer Name'));
        expect(analysis.columns[1].displayHeader, equals('Contact Number'));
        expect(analysis.dataRowCount, equals(2)); // rows 2 and 3
        expect(analysis.isValid, isTrue);
      },
    );

    test('returns blocking error when parsed file contains no sheets', () {
      const parsedFile = LeadImportParsedFile(
        fileName: 'empty.xlsx',
        source: LeadSource.excel,
        sheets: [],
      );

      final analysis = analyzer.analyze(
        parsedFile: parsedFile,
        sheetIndex: 0,
        headerRowIndex: 0,
      );

      expect(analysis.sheetName, isNull);
      expect(analysis.columns, isEmpty);
      expect(analysis.dataRowCount, equals(0));
      expect(analysis.hasBlockingErrors, isTrue);
      expect(
        analysis.issues.any(
          (i) =>
              i.severity == LeadImportStructureIssueSeverity.error &&
              i.message == 'No worksheets were found in this file.',
        ),
        isTrue,
      );
    });

    test('returns blocking error when sheet index is out of bounds', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'leads.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Name'],
              ['Alice'],
            ],
          ),
        ],
      );

      final analysis = analyzer.analyze(
        parsedFile: parsedFile,
        sheetIndex: 5,
        headerRowIndex: 0,
      );

      expect(analysis.sheetName, isNull);
      expect(analysis.columns, isEmpty);
      expect(analysis.dataRowCount, equals(0));
      expect(analysis.hasBlockingErrors, isTrue);
      expect(
        analysis.issues.any(
          (i) =>
              i.severity == LeadImportStructureIssueSeverity.error &&
              i.message == 'The selected worksheet is not available.',
        ),
        isTrue,
      );

      final analysisNegative = analyzer.analyze(
        parsedFile: parsedFile,
        sheetIndex: -1,
        headerRowIndex: 0,
      );
      expect(analysisNegative.sheetName, isNull);
      expect(analysisNegative.columns, isEmpty);
      expect(analysisNegative.dataRowCount, equals(0));
      expect(analysisNegative.hasBlockingErrors, isTrue);
    });

    test('returns blocking error when selected sheet has no rows', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'empty_sheet.xlsx',
        source: LeadSource.excel,
        sheets: [const LeadImportParsedSheet(name: 'EmptySheet', rows: [])],
      );

      final analysis = analyzer.analyze(
        parsedFile: parsedFile,
        sheetIndex: 0,
        headerRowIndex: 0,
      );

      expect(analysis.hasBlockingErrors, isTrue);
      expect(
        analysis.issues.any(
          (i) =>
              i.severity == LeadImportStructureIssueSeverity.error &&
              i.message == 'The selected sheet is empty.',
        ),
        isTrue,
      );
    });

    test('returns blocking error when header row index is out of bounds', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'short.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Name', 'Email'],
              ['Alice', 'alice@example.com'],
            ],
          ),
        ],
      );

      final analysis = analyzer.analyze(
        parsedFile: parsedFile,
        sheetIndex: 0,
        headerRowIndex: 10,
      );

      expect(analysis.hasBlockingErrors, isTrue);
      expect(
        analysis.issues.any(
          (i) =>
              i.severity == LeadImportStructureIssueSeverity.error &&
              i.message == 'The selected header row is not available.',
        ),
        isTrue,
      );
    });

    test('returns blocking error when header row has no meaningful cells', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'blank_header.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['', '   ', ''],
              ['Alice', '123', 'a@example.com'],
            ],
          ),
        ],
      );

      final analysis = analyzer.analyze(
        parsedFile: parsedFile,
        sheetIndex: 0,
        headerRowIndex: 0,
      );

      expect(analysis.hasBlockingErrors, isTrue);
      expect(
        analysis.issues.any(
          (i) =>
              i.severity == LeadImportStructureIssueSeverity.error &&
              i.message == 'The selected header row is empty.',
        ),
        isTrue,
      );
    });

    test(
      'preserves blank middle header and assigns synthetic display label with warning',
      () {
        final parsedFile = LeadImportParsedFile(
          fileName: 'blank_middle.csv',
          source: LeadSource.csv,
          sheets: [
            LeadImportParsedSheet(
              name: 'CSV',
              rows: [
                ['Name', '', 'Email'],
                ['Alice', '123', 'alice@example.com'],
              ],
            ),
          ],
        );

        final analysis = analyzer.analyze(
          parsedFile: parsedFile,
          sheetIndex: 0,
          headerRowIndex: 0,
        );

        expect(analysis.columns.length, equals(3));
        expect(analysis.columns[0].displayHeader, equals('Name'));
        expect(analysis.columns[1].displayHeader, equals('Column 2'));
        expect(analysis.columns[1].isBlankHeader, isTrue);
        expect(analysis.columns[2].displayHeader, equals('Email'));

        // Blank header is a warning, not a blocking error
        expect(analysis.hasBlockingErrors, isFalse);
        expect(analysis.isValid, isTrue);
        expect(
          analysis.issues.any(
            (i) =>
                i.severity == LeadImportStructureIssueSeverity.warning &&
                i.message == 'Blank header at column 2.',
          ),
          isTrue,
        );
      },
    );

    test(
      'detects duplicate headers case-insensitively while preserving index identity',
      () {
        final parsedFile = LeadImportParsedFile(
          fileName: 'duplicates.csv',
          source: LeadSource.csv,
          sheets: [
            LeadImportParsedSheet(
              name: 'CSV',
              rows: [
                ['Phone', ' phone ', 'Email'],
                ['123', '456', 'a@example.com'],
              ],
            ),
          ],
        );

        final analysis = analyzer.analyze(
          parsedFile: parsedFile,
          sheetIndex: 0,
          headerRowIndex: 0,
        );

        expect(analysis.columns.length, equals(3));
        expect(analysis.columns[0].index, equals(0));
        expect(analysis.columns[1].index, equals(1));
        expect(analysis.columns[0].rawHeader, equals('Phone'));
        expect(analysis.columns[1].rawHeader, equals(' phone '));

        // Warning generated, but not blocking
        expect(analysis.hasBlockingErrors, isFalse);
        expect(analysis.isValid, isTrue);
        expect(
          analysis.issues.any(
            (i) =>
                i.severity == LeadImportStructureIssueSeverity.warning &&
                i.message.contains('Duplicate column name: "Phone"'),
          ),
          isTrue,
        );
      },
    );

    test('returns blocking error when there are no data rows below header', () {
      final parsedFile = LeadImportParsedFile(
        fileName: 'header_only.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Name', 'Phone'],
            ],
          ),
        ],
      );

      final analysis = analyzer.analyze(
        parsedFile: parsedFile,
        sheetIndex: 0,
        headerRowIndex: 0,
      );

      expect(analysis.dataRowCount, equals(0));
      expect(analysis.hasBlockingErrors, isTrue);
      expect(
        analysis.issues.any(
          (i) =>
              i.severity == LeadImportStructureIssueSeverity.error &&
              i.message == 'No data rows were found below the selected header.',
        ),
        isTrue,
      );
    });

    test(
      'preserves raw header without trimming or mutating original parsed string',
      () {
        final parsedFile = LeadImportParsedFile(
          fileName: 'untrimmed.csv',
          source: LeadSource.csv,
          sheets: [
            LeadImportParsedSheet(
              name: 'CSV',
              rows: [
                ['  Customer Name  ', 'Phone'],
                ['Alice', '123'],
              ],
            ),
          ],
        );

        final analysis = analyzer.analyze(
          parsedFile: parsedFile,
          sheetIndex: 0,
          headerRowIndex: 0,
        );

        expect(analysis.columns[0].rawHeader, equals('  Customer Name  '));
        expect(analysis.columns[0].displayHeader, equals('Customer Name'));
      },
    );

    test(
      'analyzes selected sheet from multiple worksheets without reparsing',
      () {
        final parsedFile = LeadImportParsedFile(
          fileName: 'workbook.xlsx',
          source: LeadSource.excel,
          sheets: [
            LeadImportParsedSheet(
              name: 'SheetA',
              rows: [
                ['ColA1', 'ColA2'],
                ['ValA1', 'ValA2'],
              ],
            ),
            LeadImportParsedSheet(
              name: 'SheetB',
              rows: [
                ['ColB1', 'ColB2', 'ColB3'],
                ['ValB1', 'ValB2', 'ValB3'],
                ['ValB4', 'ValB5', 'ValB6'],
              ],
            ),
          ],
        );

        final analysisB = analyzer.analyze(
          parsedFile: parsedFile,
          sheetIndex: 1,
          headerRowIndex: 0,
        );

        expect(analysisB.sheetIndex, equals(1));
        expect(analysisB.sheetName, equals('SheetB'));
        expect(analysisB.columns.length, equals(3));
        expect(analysisB.columns[0].displayHeader, equals('ColB1'));
        expect(analysisB.dataRowCount, equals(2));
        expect(analysisB.isValid, isTrue);
      },
    );

    test(
      'discovers columns from maximum row width when header is shorter than data rows',
      () {
        final parsedFile = LeadImportParsedFile(
          fileName: 'short_header.csv',
          source: LeadSource.csv,
          sheets: [
            LeadImportParsedSheet(
              name: 'CSV',
              rows: [
                ['Name', 'Phone'],
                ['Alice', '123', 'alice@example.com'],
              ],
            ),
          ],
        );

        final analysis = analyzer.analyze(
          parsedFile: parsedFile,
          sheetIndex: 0,
          headerRowIndex: 0,
        );

        expect(analysis.columns.length, equals(3));
        expect(analysis.columns[0].displayHeader, equals('Name'));
        expect(analysis.columns[0].index, equals(0));
        expect(analysis.columns[1].displayHeader, equals('Phone'));
        expect(analysis.columns[1].index, equals(1));
        expect(analysis.columns[2].displayHeader, equals('Column 3'));
        expect(analysis.columns[2].index, equals(2));
        expect(analysis.columns[2].rawHeader, equals(''));
        expect(analysis.columns[2].isBlankHeader, isTrue);
        expect(analysis.dataRowCount, equals(1));
        expect(analysis.hasBlockingErrors, isFalse);
        expect(analysis.isValid, isTrue);
      },
    );

    test(
      'discovers columns from maximum row width across variable-width rows',
      () {
        final parsedFile = LeadImportParsedFile(
          fileName: 'variable_widths.csv',
          source: LeadSource.csv,
          sheets: [
            LeadImportParsedSheet(
              name: 'CSV',
              rows: [
                ['A'],
                ['1', '2'],
                ['3', '4', '5'],
              ],
            ),
          ],
        );

        final analysis = analyzer.analyze(
          parsedFile: parsedFile,
          sheetIndex: 0,
          headerRowIndex: 0,
        );

        expect(analysis.columns.length, equals(3));
        expect(analysis.columns[0].displayHeader, equals('A'));
        expect(analysis.columns[0].index, equals(0));
        expect(analysis.columns[1].displayHeader, equals('Column 2'));
        expect(analysis.columns[1].index, equals(1));
        expect(analysis.columns[2].displayHeader, equals('Column 3'));
        expect(analysis.columns[2].index, equals(2));
        expect(analysis.dataRowCount, equals(2));
        expect(analysis.isValid, isTrue);
      },
    );

    test(
      'blank normalized headers are skipped by duplicate-name detection',
      () {
        final parsedFile = LeadImportParsedFile(
          fileName: 'blank_and_empty.csv',
          source: LeadSource.csv,
          sheets: [
            LeadImportParsedSheet(
              name: 'CSV',
              rows: [
                ['Name', '', '   '],
                ['Alice', 'Val1', 'Val2'],
              ],
            ),
          ],
        );

        final analysis = analyzer.analyze(
          parsedFile: parsedFile,
          sheetIndex: 0,
          headerRowIndex: 0,
        );

        final duplicateIssues = analysis.issues
            .where((i) => i.message.contains('Duplicate column name'))
            .toList();
        final blankIssues = analysis.issues
            .where((i) => i.message.contains('Blank header at column'))
            .toList();

        expect(
          duplicateIssues,
          isEmpty,
          reason: 'Blank headers must not trigger duplicate warnings',
        );
        expect(blankIssues.length, equals(2));
        expect(blankIssues[0].message, equals('Blank header at column 2.'));
        expect(blankIssues[1].message, equals('Blank header at column 3.'));
        expect(analysis.isValid, isTrue);
      },
    );

    test(
      'completely empty header row returns single blocking error and zero blank header warnings',
      () {
        final parsedFile = LeadImportParsedFile(
          fileName: 'all_blank.csv',
          source: LeadSource.csv,
          sheets: [
            LeadImportParsedSheet(
              name: 'CSV',
              rows: [
                ['', '', ''],
                ['Alice', '123', 'a@example.com'],
              ],
            ),
          ],
        );

        final analysis = analyzer.analyze(
          parsedFile: parsedFile,
          sheetIndex: 0,
          headerRowIndex: 0,
        );

        expect(analysis.hasBlockingErrors, isTrue);
        expect(analysis.columns, isEmpty);
        expect(analysis.issues.length, equals(1));
        expect(
          analysis.issues.single.message,
          equals('The selected header row is empty.'),
        );
        expect(
          analysis.issues.single.severity,
          equals(LeadImportStructureIssueSeverity.error),
        );
      },
    );
  });
}
