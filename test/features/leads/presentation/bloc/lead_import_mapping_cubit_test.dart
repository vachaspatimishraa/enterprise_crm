import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_mapping_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_parsed_file.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_structure_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportMappingCubit', () {
    const validAnalysis = LeadImportStructureAnalysis(
      fileName: 'leads.csv',
      source: LeadSource.csv,
      sheetIndex: 0,
      sheetName: 'CSV',
      headerRowIndex: 0,
      columns: [
        LeadImportDiscoveredColumn(
          index: 0,
          rawHeader: 'Customer Name',
          displayHeader: 'Customer Name',
        ),
        LeadImportDiscoveredColumn(
          index: 1,
          rawHeader: 'Mobile Phone',
          displayHeader: 'Mobile Phone',
        ),
        LeadImportDiscoveredColumn(
          index: 2,
          rawHeader: 'Email Address',
          displayHeader: 'Email Address',
        ),
      ],
      dataRowCount: 5,
      issues: [],
    );

    final parsedFile = LeadImportParsedFile(
      fileName: 'leads.csv',
      source: LeadSource.csv,
      sheets: [
        LeadImportParsedSheet(
          name: 'CSV',
          rows: [
            ['Customer Name', 'Mobile Phone', 'Email Address'],
            ['Alice', '1234567890', 'alice@test.com'],
          ],
        ),
      ],
    );

    test('initial state has all fields unmapped and canContinue false', () {
      final cubit = LeadImportMappingCubit(
        parsedFile: parsedFile,
        analysis: validAnalysis,
      );

      expect(cubit.state.mapping.nameColumnIndex, isNull);
      expect(cubit.state.mapping.phoneColumnIndex, isNull);
      expect(cubit.state.mapping.emailColumnIndex, isNull);
      expect(cubit.state.mapping.hasAnyMapping, isFalse);
      expect(cubit.state.canContinue, isFalse);

      cubit.close();
    });

    test('mapping Name to column 0 updates only name and enables Continue', () {
      final cubit = LeadImportMappingCubit(
        parsedFile: parsedFile,
        analysis: validAnalysis,
      );

      cubit.mapNameTo(0);

      expect(cubit.state.mapping.nameColumnIndex, equals(0));
      expect(cubit.state.mapping.phoneColumnIndex, isNull);
      expect(cubit.state.mapping.emailColumnIndex, isNull);
      expect(cubit.state.mapping.hasAnyMapping, isTrue);
      expect(cubit.state.canContinue, isTrue);

      cubit.close();
    });

    test('mapping Phone to column 1 updates only phone and preserves name', () {
      final cubit = LeadImportMappingCubit(
        parsedFile: parsedFile,
        analysis: validAnalysis,
      );

      cubit.mapNameTo(0);
      cubit.mapPhoneTo(1);

      expect(cubit.state.mapping.nameColumnIndex, equals(0));
      expect(cubit.state.mapping.phoneColumnIndex, equals(1));
      expect(cubit.state.mapping.emailColumnIndex, isNull);
      expect(cubit.state.canContinue, isTrue);

      cubit.close();
    });

    test('mapping Email to column 2 updates email', () {
      final cubit = LeadImportMappingCubit(
        parsedFile: parsedFile,
        analysis: validAnalysis,
      );

      cubit.mapEmailTo(2);

      expect(cubit.state.mapping.nameColumnIndex, isNull);
      expect(cubit.state.mapping.phoneColumnIndex, isNull);
      expect(cubit.state.mapping.emailColumnIndex, equals(2));
      expect(cubit.state.canContinue, isTrue);

      cubit.close();
    });

    test(
      'unmapping a field resets it to null without affecting other fields',
      () {
        final cubit = LeadImportMappingCubit(
          parsedFile: parsedFile,
          analysis: validAnalysis,
        );

        cubit.mapNameTo(0);
        cubit.mapPhoneTo(1);
        expect(cubit.state.mapping.phoneColumnIndex, equals(1));

        cubit.mapPhoneTo(null);

        expect(cubit.state.mapping.nameColumnIndex, equals(0));
        expect(cubit.state.mapping.phoneColumnIndex, isNull);
        expect(cubit.state.canContinue, isTrue);

        // Unmap remaining field -> canContinue becomes false
        cubit.mapNameTo(null);
        expect(cubit.state.mapping.hasAnyMapping, isFalse);
        expect(cubit.state.canContinue, isFalse);

        cubit.close();
      },
    );

    test(
      'conflict resolution: assigning already mapped column to another field clears previous field',
      () {
        final cubit = LeadImportMappingCubit(
          parsedFile: parsedFile,
          analysis: validAnalysis,
        );

        cubit.mapPhoneTo(1);
        expect(cubit.state.mapping.phoneColumnIndex, equals(1));
        expect(cubit.state.mapping.emailColumnIndex, isNull);

        // Map Email to column 1 -> Phone should automatically be cleared
        cubit.mapEmailTo(1);

        expect(cubit.state.mapping.phoneColumnIndex, isNull);
        expect(cubit.state.mapping.emailColumnIndex, equals(1));
        expect(cubit.state.mapping.nameColumnIndex, isNull);
        expect(cubit.state.canContinue, isTrue);

        cubit.close();
      },
    );

    test('ignores invalid column index without changing state', () {
      final cubit = LeadImportMappingCubit(
        parsedFile: parsedFile,
        analysis: validAnalysis,
      );

      cubit.mapNameTo(0);
      expect(cubit.state.mapping.nameColumnIndex, equals(0));

      // Attempt invalid indices
      cubit.mapNameTo(999);
      expect(cubit.state.mapping.nameColumnIndex, equals(0));

      cubit.mapPhoneTo(-1);
      expect(cubit.state.mapping.phoneColumnIndex, isNull);

      cubit.close();
    });

    test(
      'handles duplicate header columns by storing exact index identity',
      () {
        const duplicateAnalysis = LeadImportStructureAnalysis(
          fileName: 'dup.csv',
          source: LeadSource.csv,
          sheetIndex: 0,
          sheetName: 'CSV',
          headerRowIndex: 0,
          columns: [
            LeadImportDiscoveredColumn(
              index: 0,
              rawHeader: 'Phone',
              displayHeader: 'Phone',
            ),
            LeadImportDiscoveredColumn(
              index: 1,
              rawHeader: 'Phone',
              displayHeader: 'Phone',
            ),
          ],
          dataRowCount: 2,
          issues: [
            LeadImportStructureIssue(
              severity: LeadImportStructureIssueSeverity.warning,
              message: 'Duplicate column name: "Phone".',
            ),
          ],
        );

        final cubit = LeadImportMappingCubit(
          parsedFile: parsedFile,
          analysis: duplicateAnalysis,
        );

        cubit.mapPhoneTo(1);

        expect(cubit.state.mapping.phoneColumnIndex, equals(1));
        expect(cubit.state.canContinue, isTrue);

        cubit.close();
      },
    );

    test('allows mapping to a blank-header synthetic column', () {
      const blankHeaderAnalysis = LeadImportStructureAnalysis(
        fileName: 'blank.csv',
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
            rawHeader: '',
            displayHeader: 'Column 2',
          ),
        ],
        dataRowCount: 2,
        issues: [],
      );

      final cubit = LeadImportMappingCubit(
        parsedFile: parsedFile,
        analysis: blankHeaderAnalysis,
      );

      cubit.mapEmailTo(1);

      expect(cubit.state.mapping.emailColumnIndex, equals(1));
      expect(cubit.state.canContinue, isTrue);

      cubit.close();
    });

    test(
      'canContinue is false if analysis has blocking errors even when fields are mapped',
      () {
        const blockingAnalysis = LeadImportStructureAnalysis(
          fileName: 'error.csv',
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
          dataRowCount: 0,
          issues: [
            LeadImportStructureIssue(
              severity: LeadImportStructureIssueSeverity.error,
              message: 'No data rows were found below the selected header.',
            ),
          ],
        );

        final cubit = LeadImportMappingCubit(
          parsedFile: parsedFile,
          analysis: blockingAnalysis,
        );

        cubit.mapNameTo(0);

        expect(cubit.state.mapping.nameColumnIndex, equals(0));
        expect(cubit.state.mapping.hasAnyMapping, isTrue);
        expect(cubit.state.canContinue, isFalse);

        cubit.close();
      },
    );
  });
}
