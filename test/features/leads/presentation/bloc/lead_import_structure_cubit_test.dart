import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_structure_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_parsed_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportStructureCubit', () {
    late LeadImportParsedFile parsedFile;
    late LeadImportStructureCubit cubit;

    setUp(() {
      parsedFile = LeadImportParsedFile(
        fileName: 'import.xlsx',
        source: LeadSource.excel,
        sheets: [
          LeadImportParsedSheet(
            name: 'Sheet1',
            rows: [
              ['Title row'],
              ['Name', 'Email'],
              ['Alice', 'alice@example.com'],
              ['Bob', 'bob@example.com'],
            ],
          ),
          LeadImportParsedSheet(
            name: 'Sheet2',
            rows: [
              ['Col1', 'Col2', 'Col3'],
              ['A', 'B', 'C'],
            ],
          ),
        ],
      );

      cubit = LeadImportStructureCubit(parsedFile: parsedFile);
    });

    tearDown(() {
      cubit.close();
    });

    test('initializes with sheetIndex 0 and headerRowIndex 0', () {
      expect(cubit.state.selectedSheetIndex, equals(0));
      expect(cubit.state.selectedHeaderRowIndex, equals(0));
      expect(cubit.state.analysis.sheetName, equals('Sheet1'));
      expect(cubit.state.analysis.columns.length, equals(1));
      expect(
        cubit.state.analysis.columns.first.displayHeader,
        equals('Title row'),
      );
      expect(cubit.state.analysis.dataRowCount, equals(3));
    });

    test('selectHeaderRow re-analyzes using the chosen row index', () {
      cubit.selectHeaderRow(1);

      expect(cubit.state.selectedHeaderRowIndex, equals(1));
      expect(cubit.state.analysis.columns.length, equals(2));
      expect(cubit.state.analysis.columns[0].displayHeader, equals('Name'));
      expect(cubit.state.analysis.columns[1].displayHeader, equals('Email'));
      expect(cubit.state.analysis.dataRowCount, equals(2));
      expect(cubit.state.isValid, isTrue);
    });

    test(
      'selectSheet resets headerRowIndex to 0 and re-analyzes new sheet',
      () {
        // First select header row 1 on sheet 0
        cubit.selectHeaderRow(1);
        expect(cubit.state.selectedHeaderRowIndex, equals(1));

        // Switch to sheet 1
        cubit.selectSheet(1);

        expect(cubit.state.selectedSheetIndex, equals(1));
        expect(cubit.state.selectedHeaderRowIndex, equals(0)); // Reset to 0
        expect(cubit.state.analysis.sheetName, equals('Sheet2'));
        expect(cubit.state.analysis.columns.length, equals(3));
        expect(cubit.state.analysis.columns[0].displayHeader, equals('Col1'));
        expect(cubit.state.analysis.dataRowCount, equals(1));
      },
    );

    test('selectSheet ignores invalid sheet index', () {
      cubit.selectSheet(99);

      expect(cubit.state.selectedSheetIndex, equals(0));
    });

    test(
      'correctly reflects blocking errors when invalid structure is selected',
      () {
        final invalidFile = LeadImportParsedFile(
          fileName: 'empty.csv',
          source: LeadSource.csv,
          sheets: [const LeadImportParsedSheet(name: 'CSV', rows: [])],
        );

        final invalidCubit = LeadImportStructureCubit(parsedFile: invalidFile);

        expect(invalidCubit.state.hasBlockingErrors, isTrue);
        expect(invalidCubit.state.isValid, isFalse);

        invalidCubit.close();
      },
    );
  });
}
