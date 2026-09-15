import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_preview_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_preview_state.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_parsed_file.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_preview.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_structure_analysis.dart';
import 'package:enterprise_crm/features/leads/presentation/services/lead_import_preview_builder.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFailingBuilder implements LeadImportPreviewBuilder {
  const _FakeFailingBuilder({this.exception});

  final Object? exception;

  @override
  LeadImportPreview build({
    required LeadImportParsedFile parsedFile,
    required LeadImportStructureAnalysis analysis,
    required LeadImportColumnMapping mapping,
  }) {
    if (exception != null) {
      throw exception!;
    }
    throw const LeadImportPreviewException('Custom preview error.');
  }
}

void main() {
  group('LeadImportPreviewCubit', () {
    final parsedFile = LeadImportParsedFile(
      fileName: 'leads.csv',
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

    const analysis = LeadImportStructureAnalysis(
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
        LeadImportDiscoveredColumn(
          index: 1,
          rawHeader: 'Email',
          displayHeader: 'Email',
        ),
      ],
      issues: [],
      dataRowCount: 1,
    );

    const mapping = LeadImportColumnMapping(
      sheetIndex: 0,
      headerRowIndex: 0,
      nameColumnIndex: 0,
      emailColumnIndex: 1,
    );

    test(
      'synchronously emits LeadImportPreviewReady upon creation with valid artifacts',
      () {
        final cubit = LeadImportPreviewCubit(
          parsedFile: parsedFile,
          analysis: analysis,
          mapping: mapping,
        );

        expect(cubit.state, isA<LeadImportPreviewReady>());
        final readyState = cubit.state as LeadImportPreviewReady;
        expect(readyState.preview.fileName, equals('leads.csv'));
        expect(readyState.preview.validRowCount, equals(1));
        expect(readyState.preview.totalRowCount, equals(1));
      },
    );

    test(
      'emits LeadImportPreviewFailure when builder throws LeadImportPreviewException',
      () {
        final cubit = LeadImportPreviewCubit(
          parsedFile: parsedFile,
          analysis: analysis,
          mapping: mapping,
          builder: const _FakeFailingBuilder(),
        );

        expect(cubit.state, isA<LeadImportPreviewFailure>());
        final failureState = cubit.state as LeadImportPreviewFailure;
        expect(failureState.message, equals('Custom preview error.'));
      },
    );

    test(
      'emits generic LeadImportPreviewFailure when builder throws unexpected exception',
      () {
        final cubit = LeadImportPreviewCubit(
          parsedFile: parsedFile,
          analysis: analysis,
          mapping: mapping,
          builder: _FakeFailingBuilder(
            exception: StateError('Unexpected error'),
          ),
        );

        expect(cubit.state, isA<LeadImportPreviewFailure>());
        final failureState = cubit.state as LeadImportPreviewFailure;
        expect(
          failureState.message,
          equals('Unable to prepare this import preview.'),
        );
      },
    );

    test('buildPreview re-evaluates and updates state', () {
      final cubit = LeadImportPreviewCubit(
        parsedFile: parsedFile,
        analysis: analysis,
        mapping: mapping,
      );

      expect(cubit.state, isA<LeadImportPreviewReady>());

      // Calling buildPreview with mismatched analysis
      const badAnalysis = LeadImportStructureAnalysis(
        fileName: 'other.csv',
        source: LeadSource.csv,
        sheetIndex: 0,
        sheetName: 'CSV',
        headerRowIndex: 0,
        columns: [],
        issues: [],
        dataRowCount: 0,
      );

      cubit.buildPreview(
        parsedFile: parsedFile,
        analysis: badAnalysis,
        mapping: mapping,
      );

      expect(cubit.state, isA<LeadImportPreviewFailure>());
    });
  });
}
