import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_preview.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_review.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_import_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LeadImportPreview createSamplePreview({
    int validCount = 10,
    int invalidCount = 2,
    int blankCount = 1,
  }) {
    final rows = <LeadImportPreviewRow>[];
    int index = 1;
    for (int i = 0; i < validCount; i++) {
      rows.add(
        LeadImportPreviewRow(
          sourceRowIndex: index++,
          name: 'Valid $i',
          status: LeadImportPreviewRowStatus.valid,
        ),
      );
    }
    for (int i = 0; i < invalidCount; i++) {
      rows.add(
        LeadImportPreviewRow(
          sourceRowIndex: index++,
          name: 'Invalid $i',
          status: LeadImportPreviewRowStatus.invalid,
        ),
      );
    }
    for (int i = 0; i < blankCount; i++) {
      rows.add(
        LeadImportPreviewRow(
          sourceRowIndex: index++,
          status: LeadImportPreviewRowStatus.blank,
        ),
      );
    }

    return LeadImportPreview(
      fileName: 'leads.csv',
      source: LeadSource.csv,
      sheetIndex: 0,
      sheetName: 'Sheet1',
      headerRowIndex: 0,
      mapping: const LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
      ),
      rows: rows,
    );
  }

  Widget createWidgetUnderTest({
    required LeadImportResult result,
    required LeadImportPreview preview,
    required LeadImportReviewDecision decision,
    required VoidCallback onDone,
    ThemeData? theme,
  }) {
    return MaterialApp(
      theme: theme ?? ThemeData.light(useMaterial3: true),
      home: LeadImportResultScreen(
        result: result,
        preview: preview,
        decision: decision,
        onDone: onDone,
      ),
    );
  }

  group('LeadImportResultScreen - Display & Distinction', () {
    testWidgets(
      'renders Importer Result and Review Summary with clearly separated counts',
      (tester) async {
        // 10 valid, 2 invalid, 1 blank
        final preview = createSamplePreview(
          validCount: 10,
          invalidCount: 2,
          blankCount: 1,
        );
        // User selected 8 out of 10 valid rows (indices 1..8)
        final decision = LeadImportReviewDecision({1, 2, 3, 4, 5, 6, 7, 8});
        // Importer reports 8 total, 8 imported, 0 skipped, 0 failed, 0 duplicate
        const result = LeadImportResult(
          totalRows: 8,
          importedRows: 8,
          skippedRows: 0,
          failedRows: 0,
          duplicateRows: 0,
        );

        await tester.pumpWidget(
          createWidgetUnderTest(
            result: result,
            preview: preview,
            decision: decision,
            onDone: () {},
          ),
        );

        // Verify Screen Title
        expect(find.text('Import Complete'), findsWidgets);
        expect(find.text('leads.csv'), findsOneWidget);

        // Verify Cards Exist
        expect(
          find.byKey(const Key('lead_import_result_importer_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lead_import_result_review_summary_card')),
          findsOneWidget,
        );

        // Importer Result metrics
        expect(find.text('Total submitted'), findsOneWidget);
        expect(find.text('Imported'), findsOneWidget);
        expect(find.text('Skipped by importer'), findsOneWidget);
        expect(find.text('Failed'), findsOneWidget);
        expect(find.text('Reported duplicates'), findsOneWidget);

        // Review Summary metrics
        expect(find.text('Valid rows'), findsOneWidget);
        expect(find.text('Selected for import'), findsOneWidget);
        expect(find.text('Excluded valid rows'), findsOneWidget);
        expect(find.text('Invalid rows'), findsOneWidget);
        expect(find.text('Blank rows'), findsOneWidget);

        // Verify that Skipped by importer shows 0, NOT 5 (review exclusions + invalid/blank)
        final importerCard = find.byKey(
          const Key('lead_import_result_importer_card'),
        );
        expect(
          find.descendant(of: importerCard, matching: find.text('0')),
          findsNWidgets(3), // skipped: 0, failed: 0, duplicate: 0
        );
        expect(
          find.descendant(of: importerCard, matching: find.text('8')),
          findsNWidgets(2), // total submitted: 8, imported: 8
        );

        // Review Summary card counts
        final reviewCard = find.byKey(
          const Key('lead_import_result_review_summary_card'),
        );
        expect(
          find.descendant(of: reviewCard, matching: find.text('10')),
          findsOneWidget,
        ); // valid: 10
        expect(
          find.descendant(of: reviewCard, matching: find.text('8')),
          findsOneWidget,
        ); // selected for import: 8
        expect(
          find.descendant(of: reviewCard, matching: find.text('2')),
          findsNWidgets(2),
        ); // excluded: 2, invalid: 2
        expect(
          find.descendant(of: reviewCard, matching: find.text('1')),
          findsOneWidget,
        ); // blank: 1
      },
    );

    testWidgets(
      'renders partial importer results safely without enforcing sum reconciliation',
      (tester) async {
        final preview = createSamplePreview(
          validCount: 8,
          invalidCount: 0,
          blankCount: 0,
        );
        final decision = LeadImportReviewDecision({1, 2, 3, 4, 5, 6, 7, 8});

        const partialResult = LeadImportResult(
          totalRows: 8,
          importedRows: 6,
          skippedRows: 1,
          failedRows: 1,
          duplicateRows: 1,
        );

        await tester.pumpWidget(
          createWidgetUnderTest(
            result: partialResult,
            preview: preview,
            decision: decision,
            onDone: () {},
          ),
        );

        // With failedRows > 0, title is "Import Finished"
        expect(find.text('Import Finished'), findsWidgets);

        final importerCard = find.byKey(
          const Key('lead_import_result_importer_card'),
        );
        expect(
          find.descendant(of: importerCard, matching: find.text('8')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: importerCard, matching: find.text('6')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: importerCard, matching: find.text('1')),
          findsNWidgets(3),
        );
      },
    );

    testWidgets('tapping Done calls onDone exactly once', (tester) async {
      int doneCalls = 0;
      final preview = createSamplePreview();
      final decision = LeadImportReviewDecision({1});
      const result = LeadImportResult(
        totalRows: 1,
        importedRows: 1,
        skippedRows: 0,
        failedRows: 0,
        duplicateRows: 0,
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          result: result,
          preview: preview,
          decision: decision,
          onDone: () => doneCalls++,
        ),
      );

      final doneButton = find.byKey(
        const Key('lead_import_result_done_button'),
      );
      expect(doneButton, findsOneWidget);

      await tester.ensureVisible(doneButton);
      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      expect(doneCalls, equals(1));
    });
  });

  group('LeadImportResultScreen - Theme and Responsiveness', () {
    testWidgets('renders cleanly in dark theme without hardcoded colors', (
      tester,
    ) async {
      final preview = createSamplePreview();
      final decision = LeadImportReviewDecision({1});
      const result = LeadImportResult(
        totalRows: 1,
        importedRows: 1,
        skippedRows: 0,
        failedRows: 0,
        duplicateRows: 0,
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          result: result,
          preview: preview,
          decision: decision,
          onDone: () {},
          theme: ThemeData.dark(useMaterial3: true),
        ),
      );

      expect(
        find.byKey(const Key('lead_import_result_done_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('lead_import_result_importer_card')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    final viewports = [
      const Size(320, 568),
      const Size(360, 640),
      const Size(768, 1024),
      const Size(1200, 800),
    ];

    for (final size in viewports) {
      testWidgets('renders without overflow at ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final preview = createSamplePreview(
          validCount: 20,
          invalidCount: 5,
          blankCount: 2,
        );
        final decision = LeadImportReviewDecision({1, 2, 3, 4, 5});
        const result = LeadImportResult(
          totalRows: 5,
          importedRows: 5,
          skippedRows: 0,
          failedRows: 0,
          duplicateRows: 0,
        );

        await tester.pumpWidget(
          createWidgetUnderTest(
            result: result,
            preview: preview,
            decision: decision,
            onDone: () {},
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('lead_import_result_importer_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lead_import_result_review_summary_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lead_import_result_done_button')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
