import 'dart:typed_data';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_workflow_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_workflow_state.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_parsed_file.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_preview.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_review.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_selected_file.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_structure_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportWorkflowCubit', () {
    late LeadImportWorkflowCubit cubit;

    final testFile1 = LeadImportSelectedFile(
      name: 'leads.csv',
      extension: 'csv',
      sizeBytes: 120,
      source: LeadSource.csv,
      content: InMemoryLeadImportFileContent(Uint8List.fromList([1, 2, 3])),
    );

    final testFileSameName = LeadImportSelectedFile(
      name: 'leads.csv',
      extension: 'csv',
      sizeBytes: 250,
      source: LeadSource.csv,
      content: InMemoryLeadImportFileContent(Uint8List.fromList([4, 5, 6])),
    );

    const testParsed1 = LeadImportParsedFile(
      fileName: 'leads.csv',
      source: LeadSource.csv,
      sheets: [
        LeadImportParsedSheet(
          name: 'Sheet1',
          rows: [
            ['Name', 'Email'],
            ['Alice', 'alice@example.com'],
          ],
        ),
      ],
    );

    const testAnalysis1 = LeadImportStructureAnalysis(
      fileName: 'leads.csv',
      source: LeadSource.csv,
      sheetIndex: 0,
      sheetName: 'Sheet1',
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
      dataRowCount: 1,
      issues: [],
    );

    const testAnalysisDifferent = LeadImportStructureAnalysis(
      fileName: 'leads.csv',
      source: LeadSource.csv,
      sheetIndex: 0,
      sheetName: 'Sheet1',
      headerRowIndex: 1,
      columns: [
        LeadImportDiscoveredColumn(
          index: 0,
          rawHeader: 'Alice',
          displayHeader: 'Alice',
        ),
      ],
      dataRowCount: 0,
      issues: [],
    );

    const testMapping1 = LeadImportColumnMapping(
      sheetIndex: 0,
      headerRowIndex: 0,
      nameColumnIndex: 0,
      emailColumnIndex: 1,
    );

    const testMappingDifferent = LeadImportColumnMapping(
      sheetIndex: 0,
      headerRowIndex: 0,
      nameColumnIndex: 0,
      phoneColumnIndex: 1,
    );

    const testPreview1 = LeadImportPreview(
      fileName: 'leads.csv',
      source: LeadSource.csv,
      sheetIndex: 0,
      sheetName: 'Sheet1',
      headerRowIndex: 0,
      mapping: testMapping1,
      rows: [
        LeadImportPreviewRow(
          sourceRowIndex: 1,
          name: 'Alice',
          email: 'alice@example.com',
          status: LeadImportPreviewRowStatus.valid,
        ),
      ],
    );

    const testPreviewDifferent = LeadImportPreview(
      fileName: 'leads.csv',
      source: LeadSource.csv,
      sheetIndex: 0,
      sheetName: 'Sheet1',
      headerRowIndex: 0,
      mapping: testMappingDifferent,
      rows: [
        LeadImportPreviewRow(
          sourceRowIndex: 1,
          name: 'Alice',
          phone: '123',
          status: LeadImportPreviewRowStatus.valid,
        ),
      ],
    );

    final testDecision1 = LeadImportReviewDecision({1});

    setUp(() {
      cubit = LeadImportWorkflowCubit();
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state defaults to selectFile step with null artifacts', () {
      expect(cubit.state.step, LeadImportWorkflowStep.selectFile);
      expect(cubit.state.selectedFile, isNull);
      expect(cubit.state.parsedFile, isNull);
      expect(cubit.state.structureAnalysis, isNull);
      expect(cubit.state.columnMapping, isNull);
      expect(cubit.state.preview, isNull);
      expect(cubit.state.reviewDecision, isNull);
      expect(cubit.state.parseErrorMessage, isNull);
    });

    test(
      'selectFileAndParse advances to parsing and clears all downstream state',
      () {
        // Pre-populate downstream state
        final populated = LeadImportWorkflowState(
          step: LeadImportWorkflowStep.review,
          selectedFile: testFile1,
          parsedFile: testParsed1,
          structureAnalysis: testAnalysis1,
          columnMapping: testMapping1,
          preview: testPreview1,
          reviewDecision: testDecision1,
          parseErrorMessage: 'Old error',
        );
        cubit = LeadImportWorkflowCubit(initialState: populated);

        cubit.selectFileAndParse(testFileSameName);

        expect(cubit.state.step, LeadImportWorkflowStep.parsing);
        expect(cubit.state.selectedFile, testFileSameName);
        expect(cubit.state.parsedFile, isNull);
        expect(cubit.state.structureAnalysis, isNull);
        expect(cubit.state.columnMapping, isNull);
        expect(cubit.state.preview, isNull);
        expect(cubit.state.reviewDecision, isNull);
        expect(cubit.state.parseErrorMessage, isNull);
      },
    );

    test(
      'retryParsing preserves selectedFile and clears parseErrorMessage',
      () {
        final failedState = LeadImportWorkflowState(
          step: LeadImportWorkflowStep.parsing,
          selectedFile: testFile1,
          parseErrorMessage: 'Failed to parse',
        );
        cubit = LeadImportWorkflowCubit(initialState: failedState);

        cubit.retryParsing();

        expect(cubit.state.step, LeadImportWorkflowStep.parsing);
        expect(cubit.state.selectedFile, testFile1);
        expect(cubit.state.parseErrorMessage, isNull);
      },
    );

    test(
      'onParseSuccess advances to structure and clears downstream artifacts',
      () {
        cubit.selectFileAndParse(testFile1);
        cubit.onParseSuccess(testParsed1);

        expect(cubit.state.step, LeadImportWorkflowStep.structure);
        expect(cubit.state.parsedFile, testParsed1);
        expect(cubit.state.structureAnalysis, isNull);
        expect(cubit.state.columnMapping, isNull);
        expect(cubit.state.preview, isNull);
        expect(cubit.state.reviewDecision, isNull);
        expect(cubit.state.parseErrorMessage, isNull);
      },
    );

    test('onParseFailure retains step as parsing and sets error message', () {
      cubit.selectFileAndParse(testFile1);
      cubit.onParseFailure('Corrupt CSV format');

      expect(cubit.state.step, LeadImportWorkflowStep.parsing);
      expect(cubit.state.selectedFile, testFile1);
      expect(cubit.state.parseErrorMessage, 'Corrupt CSV format');
    });

    test(
      'onStructureConfirmed advances to mapping and invalidates downstream only if changed',
      () {
        cubit.selectFileAndParse(testFile1);
        cubit.onParseSuccess(testParsed1);

        // First confirmation
        cubit.onStructureConfirmed(testAnalysis1);
        expect(cubit.state.step, LeadImportWorkflowStep.mapping);
        expect(cubit.state.structureAnalysis, testAnalysis1);

        // Advance to review
        cubit.onMappingConfirmed(testMapping1);
        cubit.onPreviewConfirmed(testPreview1);
        cubit.onReviewConfirmed(testDecision1);

        // Return to structure and reconfirm same analysis
        cubit.backToStructure();
        cubit.onStructureConfirmed(testAnalysis1);
        expect(cubit.state.columnMapping, testMapping1);
        expect(cubit.state.preview, testPreview1);
        expect(cubit.state.reviewDecision, testDecision1);

        // Confirm DIFFERENT analysis
        cubit.onStructureConfirmed(testAnalysisDifferent);
        expect(cubit.state.structureAnalysis, testAnalysisDifferent);
        expect(cubit.state.columnMapping, isNull);
        expect(cubit.state.preview, isNull);
        expect(cubit.state.reviewDecision, isNull);
      },
    );

    test(
      'onMappingConfirmed advances to preview and invalidates downstream only if changed',
      () {
        cubit.selectFileAndParse(testFile1);
        cubit.onParseSuccess(testParsed1);
        cubit.onStructureConfirmed(testAnalysis1);

        // First mapping
        cubit.onMappingConfirmed(testMapping1);
        expect(cubit.state.step, LeadImportWorkflowStep.preview);
        expect(cubit.state.columnMapping, testMapping1);

        cubit.onPreviewConfirmed(testPreview1);
        cubit.onReviewConfirmed(testDecision1);

        // Reconfirm same mapping
        cubit.backToMapping();
        cubit.onMappingConfirmed(testMapping1);
        expect(cubit.state.preview, testPreview1);
        expect(cubit.state.reviewDecision, testDecision1);

        // Confirm DIFFERENT mapping
        cubit.onMappingConfirmed(testMappingDifferent);
        expect(cubit.state.columnMapping, testMappingDifferent);
        expect(cubit.state.preview, isNull);
        expect(cubit.state.reviewDecision, isNull);
      },
    );

    test(
      'onPreviewConfirmed advances to review and invalidates decision only if changed',
      () {
        cubit.selectFileAndParse(testFile1);
        cubit.onParseSuccess(testParsed1);
        cubit.onStructureConfirmed(testAnalysis1);
        cubit.onMappingConfirmed(testMapping1);

        // First preview
        cubit.onPreviewConfirmed(testPreview1);
        expect(cubit.state.step, LeadImportWorkflowStep.review);
        expect(cubit.state.preview, testPreview1);

        cubit.onReviewConfirmed(testDecision1);

        // Reconfirm same preview
        cubit.backToPreview();
        cubit.onPreviewConfirmed(testPreview1);
        expect(cubit.state.reviewDecision, testDecision1);

        // Confirm DIFFERENT preview
        cubit.onPreviewConfirmed(testPreviewDifferent);
        expect(cubit.state.preview, testPreviewDifferent);
        expect(cubit.state.reviewDecision, isNull);
      },
    );

    test('onReviewConfirmed advances to execution step', () {
      cubit.selectFileAndParse(testFile1);
      cubit.onParseSuccess(testParsed1);
      cubit.onStructureConfirmed(testAnalysis1);
      cubit.onMappingConfirmed(testMapping1);
      cubit.onPreviewConfirmed(testPreview1);

      cubit.onReviewConfirmed(testDecision1);
      expect(cubit.state.step, LeadImportWorkflowStep.execution);
      expect(cubit.state.reviewDecision, testDecision1);
    });

    test('back navigation retains valid upstream artifacts', () {
      cubit.selectFileAndParse(testFile1);
      cubit.onParseSuccess(testParsed1);
      cubit.onStructureConfirmed(testAnalysis1);
      cubit.onMappingConfirmed(testMapping1);
      cubit.onPreviewConfirmed(testPreview1);
      cubit.onReviewConfirmed(testDecision1);

      expect(cubit.state.step, LeadImportWorkflowStep.execution);

      cubit.backToReview();
      expect(cubit.state.step, LeadImportWorkflowStep.review);
      expect(cubit.state.preview, testPreview1);

      cubit.backToPreview();
      expect(cubit.state.step, LeadImportWorkflowStep.preview);
      expect(cubit.state.columnMapping, testMapping1);

      cubit.backToMapping();
      expect(cubit.state.step, LeadImportWorkflowStep.mapping);
      expect(cubit.state.structureAnalysis, testAnalysis1);

      cubit.backToStructure();
      expect(cubit.state.step, LeadImportWorkflowStep.structure);
      expect(cubit.state.parsedFile, testParsed1);

      cubit.backToFileSelection();
      expect(cubit.state.step, LeadImportWorkflowStep.selectFile);
      expect(cubit.state.selectedFile, testFile1);
    });

    test(
      'back navigation safely falls back if upstream artifact unexpectedly missing',
      () {
        // Mapping without structureAnalysis
        final stateNoStructure = const LeadImportWorkflowState(
          step: LeadImportWorkflowStep.mapping,
        );
        cubit = LeadImportWorkflowCubit(initialState: stateNoStructure);
        cubit.backToMapping();
        expect(cubit.state.step, LeadImportWorkflowStep.selectFile);
      },
    );

    test('reset clears entire workflow state to defaults', () {
      cubit.selectFileAndParse(testFile1);
      cubit.onParseSuccess(testParsed1);
      cubit.reset();

      expect(cubit.state.step, LeadImportWorkflowStep.selectFile);
      expect(cubit.state.selectedFile, isNull);
      expect(cubit.state.parsedFile, isNull);
    });

    test('copyWith explicit clear flags set nullable fields to null', () {
      final initial = LeadImportWorkflowState(
        step: LeadImportWorkflowStep.review,
        selectedFile: testFile1,
        parsedFile: testParsed1,
        structureAnalysis: testAnalysis1,
        columnMapping: testMapping1,
        preview: testPreview1,
        reviewDecision: testDecision1,
        parseErrorMessage: 'error',
      );

      final cleared = initial.copyWith(
        clearSelectedFile: true,
        clearParsedFile: true,
        clearStructureAnalysis: true,
        clearColumnMapping: true,
        clearPreview: true,
        clearReviewDecision: true,
        clearParseErrorMessage: true,
      );

      expect(cleared.selectedFile, isNull);
      expect(cleared.parsedFile, isNull);
      expect(cleared.structureAnalysis, isNull);
      expect(cleared.columnMapping, isNull);
      expect(cleared.preview, isNull);
      expect(cleared.reviewDecision, isNull);
      expect(cleared.parseErrorMessage, isNull);
    });
  });
}
