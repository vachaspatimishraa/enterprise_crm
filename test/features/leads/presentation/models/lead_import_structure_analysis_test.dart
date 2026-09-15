import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_structure_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportStructureAnalysis & Models', () {
    test('LeadImportDiscoveredColumn equality and isBlankHeader', () {
      const col1 = LeadImportDiscoveredColumn(
        index: 0,
        rawHeader: 'Name',
        displayHeader: 'Name',
      );
      const col2 = LeadImportDiscoveredColumn(
        index: 0,
        rawHeader: 'Name',
        displayHeader: 'Name',
      );
      const blankCol = LeadImportDiscoveredColumn(
        index: 1,
        rawHeader: '   ',
        displayHeader: 'Column 2',
      );

      expect(col1, equals(col2));
      expect(col1.hashCode, equals(col2.hashCode));
      expect(col1.isBlankHeader, isFalse);
      expect(blankCol.isBlankHeader, isTrue);
      expect(col1.toString(), contains('Name'));
    });

    test('LeadImportStructureIssue equality and severity', () {
      const issue1 = LeadImportStructureIssue(
        severity: LeadImportStructureIssueSeverity.warning,
        message: 'Duplicate header',
      );
      const issue2 = LeadImportStructureIssue(
        severity: LeadImportStructureIssueSeverity.warning,
        message: 'Duplicate header',
      );
      const errorIssue = LeadImportStructureIssue(
        severity: LeadImportStructureIssueSeverity.error,
        message: 'Sheet empty',
      );

      expect(issue1, equals(issue2));
      expect(issue1.hashCode, equals(issue2.hashCode));
      expect(issue1, isNot(equals(errorIssue)));
      expect(issue1.toString(), contains('warning'));
    });

    test(
      'LeadImportStructureAnalysis calculates isValid and hasBlockingErrors correctly',
      () {
        const validAnalysis = LeadImportStructureAnalysis(
          fileName: 'leads.csv',
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
          ],
          dataRowCount: 10,
          issues: [
            LeadImportStructureIssue(
              severity: LeadImportStructureIssueSeverity.warning,
              message: 'Duplicate header',
            ),
          ],
        );

        expect(validAnalysis.hasBlockingErrors, isFalse);
        expect(validAnalysis.isValid, isTrue);

        const invalidAnalysis = LeadImportStructureAnalysis(
          fileName: 'leads.csv',
          source: LeadSource.csv,
          sheetIndex: 0,
          sheetName: 'CSV',
          headerRowIndex: 0,
          columns: [],
          dataRowCount: 0,
          issues: [
            LeadImportStructureIssue(
              severity: LeadImportStructureIssueSeverity.error,
              message: 'No data rows',
            ),
          ],
        );

        expect(invalidAnalysis.hasBlockingErrors, isTrue);
        expect(invalidAnalysis.isValid, isFalse);
      },
    );
  });
}
