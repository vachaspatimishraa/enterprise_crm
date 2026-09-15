import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_preview.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_review.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_import_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportReviewScreen', () {
    const testMapping = LeadImportColumnMapping(
      sheetIndex: 0,
      headerRowIndex: 0,
      nameColumnIndex: 0,
      phoneColumnIndex: 1,
      emailColumnIndex: 2,
    );

    final testPreviewWithDuplicates = LeadImportPreview(
      fileName: 'customers.xlsx',
      source: LeadSource.excel,
      sheetIndex: 0,
      sheetName: 'Sheet1',
      headerRowIndex: 0,
      mapping: testMapping,
      rows: const [
        // Row 2: Alice
        LeadImportPreviewRow(
          sourceRowIndex: 1,
          name: 'Alice',
          phone: '1234567890',
          email: 'alice@example.com',
          status: LeadImportPreviewRowStatus.valid,
        ),
        // Row 3: Bob
        LeadImportPreviewRow(
          sourceRowIndex: 2,
          name: 'Bob',
          phone: '9876543210',
          email: 'bob@example.com',
          status: LeadImportPreviewRowStatus.valid,
        ),
        // Row 4: Alice (Exact duplicate of Row 2)
        LeadImportPreviewRow(
          sourceRowIndex: 3,
          name: 'Alice',
          phone: '1234567890',
          email: 'alice@example.com',
          status: LeadImportPreviewRowStatus.valid,
        ),
        // Row 5: Invalid
        LeadImportPreviewRow(
          sourceRowIndex: 4,
          name: 'Bad Email',
          phone: '555',
          email: 'not-valid-email',
          status: LeadImportPreviewRowStatus.invalid,
          issues: [
            LeadImportPreviewIssue(
              field: LeadImportTargetField.email,
              severity: LeadImportPreviewIssueSeverity.error,
              message: 'Invalid email address.',
            ),
          ],
        ),
        // Row 6: Blank
        LeadImportPreviewRow(
          sourceRowIndex: 5,
          name: '',
          phone: '',
          email: '',
          status: LeadImportPreviewRowStatus.blank,
          issues: [
            LeadImportPreviewIssue(
              field: null,
              severity: LeadImportPreviewIssueSeverity.warning,
              message: 'No mapped Lead values were found in this row.',
            ),
          ],
        ),
      ],
    );

    Widget buildTestWidget({
      LeadImportPreview? preview,
      ValueChanged<LeadImportReviewDecision>? onContinue,
      VoidCallback? onCancel,
      ThemeMode themeMode = ThemeMode.light,
    }) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: themeMode,
        home: LeadImportReviewScreen(
          preview: preview ?? testPreviewWithDuplicates,
          onContinue: onContinue,
          onCancel: onCancel,
        ),
      );
    }

    testWidgets(
      'Section 66: renders summary stats including duplicate stats when duplicates exist',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Final Import Review'), findsOneWidget);
        expect(find.text('customers.xlsx'), findsOneWidget);
        expect(find.text('Excel (.xlsx)'), findsOneWidget);
        expect(find.text('Sheet: Sheet1'), findsOneWidget);

        // Summary counters: Total: 5, Valid: 3, Invalid: 1, Blank: 1, Selected: 3
        expect(
          find.byKey(const Key('lead_import_review_stat_total_rows')),
          findsOneWidget,
        );
        expect(find.text('5'), findsOneWidget);
        expect(
          find.byKey(const Key('lead_import_review_stat_valid_rows')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lead_import_review_stat_invalid_rows')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lead_import_review_stat_blank_rows')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lead_import_review_stat_selected_rows')),
          findsOneWidget,
        );
        expect(find.text('3'), findsWidgets); // Valid: 3 and Selected: 3

        // Duplicate statistics
        expect(
          find.byKey(const Key('lead_import_review_stat_duplicate_groups')),
          findsOneWidget,
        );
        expect(
          find.text('1'),
          findsWidgets,
        ); // 1 duplicate group, 1 invalid, 1 blank
        expect(
          find.byKey(
            const Key('lead_import_review_stat_rows_in_duplicate_groups'),
          ),
          findsOneWidget,
        );
        expect(find.text('2'), findsWidgets); // 2 rows in duplicate groups
      },
    );

    testWidgets(
      'Section 67: displays exact in-file duplicate banner without claiming CRM duplication',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('lead_import_review_duplicate_banner')),
          findsOneWidget,
        );
        expect(
          find.text('Exact duplicate rows were found in this file.'),
          findsOneWidget,
        );
        expect(
          find.text(
            'They remain selected by default. Review and uncheck any rows you do not want to import.',
          ),
          findsOneWidget,
        );
        // Confirms no claim of CRM duplicates
        expect(find.textContaining('CRM'), findsNothing);
        expect(find.textContaining('already exist in CRM'), findsNothing);
      },
    );

    testWidgets(
      'Section 68: duplicate valid rows start selected and can be toggled independently',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final row2CheckboxFinder = find.byKey(
          const Key('lead_import_review_checkbox_2'),
        );
        final row4CheckboxFinder = find.byKey(
          const Key('lead_import_review_checkbox_4'),
        );

        // Scroll to Row 2 and Row 4
        await tester.scrollUntilVisible(
          row2CheckboxFinder,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        // Both duplicate rows (2 and 4) start checked
        expect(tester.widget<Checkbox>(row2CheckboxFinder).value, isTrue);

        await tester.scrollUntilVisible(
          row4CheckboxFinder,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(row4CheckboxFinder).value, isTrue);

        // Uncheck Row 4
        await tester.tap(row4CheckboxFinder);
        await tester.pumpAndSettle();

        // Row 4 is unchecked, Row 2 remains checked (independent, no linked toggle)
        await tester.scrollUntilVisible(
          row2CheckboxFinder,
          -150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(row2CheckboxFinder).value, isTrue);

        await tester.scrollUntilVisible(
          row4CheckboxFinder,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(row4CheckboxFinder).value, isFalse);

        // Selected count is updated to 2
        final selectedStatFinder = find.byKey(
          const Key('lead_import_review_stat_selected_rows'),
        );
        await tester.scrollUntilVisible(
          selectedStatFinder,
          -300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(of: selectedStatFinder, matching: find.text('2')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Section 69: invalid and blank rows are non-selectable and marked excluded',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Row 5 (Invalid)
        final row5Finder = find.byKey(const Key('lead_import_review_row_5'));
        await tester.scrollUntilVisible(
          row5Finder,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        final row5CheckboxFinder = find.byKey(
          const Key('lead_import_review_checkbox_5'),
        );
        final row5Checkbox = tester.widget<Checkbox>(row5CheckboxFinder);
        expect(row5Checkbox.value, isFalse);
        expect(row5Checkbox.onChanged, isNull); // Disabled

        // Row 6 (Blank)
        final row6Finder = find.byKey(const Key('lead_import_review_row_6'));
        await tester.scrollUntilVisible(
          row6Finder,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        final row6CheckboxFinder = find.byKey(
          const Key('lead_import_review_checkbox_6'),
        );
        final row6Checkbox = tester.widget<Checkbox>(row6CheckboxFinder);
        expect(row6Checkbox.value, isFalse);
        expect(row6Checkbox.onChanged, isNull); // Disabled
      },
    );

    testWidgets(
      'Section 70: Continue enabled with selection, disabled when empty with warning',
      (tester) async {
        LeadImportReviewDecision? recordedDecision;

        await tester.pumpWidget(
          buildTestWidget(
            onContinue: (decision) => recordedDecision = decision,
          ),
        );
        await tester.pumpAndSettle();

        final continueButtonFinder = find.byKey(
          const Key('lead_import_review_continue_button'),
        );
        await tester.scrollUntilVisible(
          continueButtonFinder,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        // Enabled initially because all 3 valid rows are selected
        expect(
          tester.widget<FilledButton>(continueButtonFinder).onPressed,
          isNotNull,
        );

        // Tap continue
        await tester.tap(continueButtonFinder);
        await tester.pumpAndSettle();

        expect(recordedDecision, isNotNull);
        expect(recordedDecision!.includedSourceRowIndices, equals({1, 2, 3}));

        // Scroll up to bulk controls and exclude all
        final excludeAllFinder = find.byKey(
          const Key('lead_import_review_exclude_all_button'),
        );
        await tester.scrollUntilVisible(
          excludeAllFinder,
          -300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(excludeAllFinder);
        await tester.pumpAndSettle();

        // Scroll back down to continue button
        await tester.scrollUntilVisible(
          continueButtonFinder,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        // Continue button is now disabled
        expect(
          tester.widget<FilledButton>(continueButtonFinder).onPressed,
          isNull,
        );
        expect(
          find.byKey(const Key('lead_import_review_no_selection_text')),
          findsOneWidget,
        );
        expect(
          find.text('Select at least one valid Lead row to continue.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'bulk selection controls: includeAllValid re-enables all valid rows',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final excludeAllFinder = find.byKey(
          const Key('lead_import_review_exclude_all_button'),
        );
        await tester.scrollUntilVisible(
          excludeAllFinder,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        // Exclude all
        await tester.tap(excludeAllFinder);
        await tester.pumpAndSettle();

        final selectedStatFinder = find.byKey(
          const Key('lead_import_review_stat_selected_rows'),
        );
        await tester.scrollUntilVisible(
          selectedStatFinder,
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(of: selectedStatFinder, matching: find.text('0')),
          findsOneWidget,
        );

        // Scroll back to include all
        final includeAllFinder = find.byKey(
          const Key('lead_import_review_include_all_button'),
        );
        await tester.scrollUntilVisible(
          includeAllFinder,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        // Include all
        await tester.tap(includeAllFinder);
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          selectedStatFinder,
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(of: selectedStatFinder, matching: find.text('3')),
          findsOneWidget,
        );
      },
    );

    testWidgets('tapping back button calls onCancel', (tester) async {
      var cancelled = false;

      await tester.pumpWidget(
        buildTestWidget(onCancel: () => cancelled = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lead_import_review_back_button')));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
    });

    testWidgets(
      'Section 71: large-list lazy rendering / scroll regression (200+ rows)',
      (tester) async {
        final largeRows = <LeadImportPreviewRow>[];
        for (var i = 1; i <= 250; i++) {
          largeRows.add(
            LeadImportPreviewRow(
              sourceRowIndex: i,
              name: 'Customer $i',
              phone: '1000$i',
              email: 'customer$i@example.com',
              status: LeadImportPreviewRowStatus.valid,
            ),
          );
        }

        final largePreview = LeadImportPreview(
          fileName: 'large.csv',
          source: LeadSource.csv,
          sheetIndex: 0,
          sheetName: 'CSV',
          headerRowIndex: 0,
          mapping: testMapping,
          rows: largeRows,
        );

        await tester.pumpWidget(buildTestWidget(preview: largePreview));
        await tester.pumpAndSettle();

        // First row (Row 2) is visible
        expect(
          find.byKey(const Key('lead_import_review_row_2')),
          findsOneWidget,
        );

        // Row 100 is far down and not yet rendered in widget tree (proving lazy rendering)
        expect(
          find.byKey(const Key('lead_import_review_row_100')),
          findsNothing,
        );

        // Scroll to Row 100
        final row100Finder = find.byKey(
          const Key('lead_import_review_row_100'),
        );
        await tester.scrollUntilVisible(
          row100Finder,
          500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(row100Finder, findsOneWidget);
        expect(find.text('Name: Customer 99'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Section 73: renders cleanly in dark theme without exceptions',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(themeMode: ThemeMode.dark));
        await tester.pumpAndSettle();

        expect(find.text('Final Import Review'), findsOneWidget);
        expect(find.text('customers.xlsx'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    final testViewports = <String, Size>{
      'mobile-320': const Size(320, 568),
      'mobile-360': const Size(360, 640),
      'tablet-768': const Size(768, 1024),
      'desktop-1200': const Size(1200, 800),
    };

    for (final entry in testViewports.entries) {
      testWidgets(
        'Section 72: renders cleanly without overflow at viewport ${entry.key} (${entry.value.width}x${entry.value.height})',
        (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(buildTestWidget());
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('lead_import_review_scroll_view')),
            findsOneWidget,
          );

          final continueButtonFinder = find.byKey(
            const Key('lead_import_review_continue_button'),
          );
          await tester.scrollUntilVisible(continueButtonFinder, 300);
          await tester.pumpAndSettle();

          expect(continueButtonFinder, findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
