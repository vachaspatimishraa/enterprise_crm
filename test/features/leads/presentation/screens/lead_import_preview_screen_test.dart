import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_parsed_file.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_preview.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_structure_analysis.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_import_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportPreviewScreen', () {
    const testAnalysis = LeadImportStructureAnalysis(
      fileName: 'customers.xlsx',
      source: LeadSource.excel,
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
          rawHeader: 'Phone',
          displayHeader: 'Phone',
        ),
        LeadImportDiscoveredColumn(
          index: 2,
          rawHeader: 'Email',
          displayHeader: 'Email',
        ),
      ],
      issues: [],
      dataRowCount: 3,
    );

    final testParsedFile = LeadImportParsedFile(
      fileName: 'customers.xlsx',
      source: LeadSource.excel,
      sheets: [
        LeadImportParsedSheet(
          name: 'Sheet1',
          rows: [
            ['Name', 'Phone', 'Email'],
            ['Alice', '1234567890', 'alice@example.com'],
            ['Bob', '', 'invalid-email'],
            ['', '', ''],
          ],
        ),
      ],
    );

    const testMapping = LeadImportColumnMapping(
      sheetIndex: 0,
      headerRowIndex: 0,
      nameColumnIndex: 0,
      phoneColumnIndex: 1,
      emailColumnIndex: 2,
    );

    Widget buildTestWidget({
      LeadImportParsedFile? parsedFile,
      LeadImportStructureAnalysis? analysis,
      LeadImportColumnMapping? mapping,
      ValueChanged<LeadImportPreview>? onContinue,
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
        home: LeadImportPreviewScreen(
          parsedFile: parsedFile ?? testParsedFile,
          analysis: analysis ?? testAnalysis,
          mapping: mapping ?? testMapping,
          onContinue: onContinue,
          onCancel: onCancel,
        ),
      );
    }

    testWidgets('renders file information and header row correctly', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Import Preview'), findsOneWidget);
      expect(find.text('customers.xlsx'), findsOneWidget);
      expect(find.text('Excel (.xlsx)'), findsOneWidget);
      expect(find.text('Sheet: Sheet1'), findsOneWidget);
      expect(find.text('Header: Row 1'), findsOneWidget);
    });

    testWidgets('renders summary statistic counters correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Total: 3, Valid: 1, Invalid: 1, Blank: 1
      expect(
        find.byKey(const Key('lead_import_stat_total_rows')),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget); // Total
      expect(
        find.byKey(const Key('lead_import_stat_valid_rows')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('lead_import_stat_invalid_rows')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('lead_import_stat_blank_rows')),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders preview row cards with correct status badges and issues',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Row 2 (sourceRowIndex 1): Valid
        final row2Finder = find.byKey(const Key('lead_import_preview_row_2'));
        expect(row2Finder, findsOneWidget);
        expect(
          find.descendant(of: row2Finder, matching: find.text('Row 2')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row2Finder, matching: find.text('Valid')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row2Finder, matching: find.text('Name: Alice')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row2Finder,
            matching: find.text('Phone: 1234567890'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row2Finder,
            matching: find.text('Email: alice@example.com'),
          ),
          findsOneWidget,
        );

        // Row 3 (sourceRowIndex 2): Invalid
        final row3Finder = find.byKey(const Key('lead_import_preview_row_3'));
        expect(row3Finder, findsOneWidget);
        expect(
          find.descendant(of: row3Finder, matching: find.text('Row 3')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row3Finder, matching: find.text('Invalid')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row3Finder, matching: find.text('Name: Bob')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row3Finder, matching: find.text('Phone: —')),
          findsOneWidget,
        ); // Mapped but empty cell
        expect(
          find.descendant(
            of: row3Finder,
            matching: find.text('Email: invalid-email'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row3Finder,
            matching: find.text('• Invalid email address.'),
          ),
          findsOneWidget,
        );

        // Row 4 (sourceRowIndex 3): Blank
        final row4Finder = find.byKey(const Key('lead_import_preview_row_4'));
        await tester.scrollUntilVisible(row4Finder, 150);
        await tester.pumpAndSettle();
        expect(row4Finder, findsOneWidget);
        expect(
          find.descendant(of: row4Finder, matching: find.text('Row 4')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row4Finder, matching: find.text('Blank')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row4Finder,
            matching: find.text(
              '• No mapped Lead values were found in this row.',
            ),
          ),
          findsOneWidget,
        );

        // Warning note
        expect(
          find.text('Blank or invalid rows will be reviewed in the next step.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('distinguishes unmapped fields from mapped empty fields', (
      tester,
    ) async {
      // Mapping with Name mapped, Phone unmapped, Email mapped
      const partialMapping = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
        phoneColumnIndex: null, // Unmapped!
        emailColumnIndex: 2,
      );

      await tester.pumpWidget(buildTestWidget(mapping: partialMapping));
      await tester.pumpAndSettle();

      // Row 2: Name and Email mapped, Phone unmapped
      expect(find.text('Name: Alice'), findsOneWidget);
      expect(find.text('Email: alice@example.com'), findsOneWidget);
      expect(find.textContaining('Phone:'), findsNothing);
    });

    testWidgets(
      'enables Continue button when validRowCount > 0 and invokes callback',
      (tester) async {
        LeadImportPreview? continuedPreview;

        await tester.pumpWidget(
          buildTestWidget(onContinue: (preview) => continuedPreview = preview),
        );
        await tester.pumpAndSettle();

        final continueButtonFinder = find.byKey(
          const Key('lead_import_preview_continue_button'),
        );
        await tester.scrollUntilVisible(continueButtonFinder, 300);
        await tester.pumpAndSettle();

        expect(continueButtonFinder, findsOneWidget);

        final button = tester.widget<FilledButton>(continueButtonFinder);
        expect(button.onPressed, isNotNull);

        await tester.tap(continueButtonFinder);
        await tester.pumpAndSettle();

        expect(continuedPreview, isNotNull);
        expect(continuedPreview!.validRowCount, equals(1));
      },
    );

    testWidgets(
      'disables Continue button when validRowCount == 0 and shows warning message',
      (tester) async {
        final allInvalidFile = LeadImportParsedFile(
          fileName: 'customers.xlsx',
          source: LeadSource.excel,
          sheets: [
            LeadImportParsedSheet(
              name: 'Sheet1',
              rows: [
                ['Name', 'Phone', 'Email'],
                ['', '', 'invalid-email'],
                ['', '', ''],
              ],
            ),
          ],
        );

        await tester.pumpWidget(buildTestWidget(parsedFile: allInvalidFile));
        await tester.pumpAndSettle();

        final warningTextFinder = find.byKey(
          const Key('lead_import_preview_no_valid_rows_text'),
        );
        await tester.scrollUntilVisible(warningTextFinder, 300);
        await tester.pumpAndSettle();

        expect(warningTextFinder, findsOneWidget);
        expect(
          find.text('No valid Lead rows are available to continue.'),
          findsOneWidget,
        );

        final continueButtonFinder = find.byKey(
          const Key('lead_import_preview_continue_button'),
        );
        expect(continueButtonFinder, findsOneWidget);
        final button = tester.widget<FilledButton>(continueButtonFinder);
        expect(button.onPressed, isNull);
      },
    );

    testWidgets('tapping back button calls onCancel', (tester) async {
      var cancelled = false;

      await tester.pumpWidget(
        buildTestWidget(onCancel: () => cancelled = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('lead_import_preview_back_button')),
      );
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
    });

    testWidgets(
      'renders failure card when workflow configuration is stale or invalid',
      (tester) async {
        // Inconsistent analysis (wrong filename)
        const staleAnalysis = LeadImportStructureAnalysis(
          fileName: 'different.xlsx',
          source: LeadSource.excel,
          sheetIndex: 0,
          sheetName: 'Sheet1',
          headerRowIndex: 0,
          columns: [
            LeadImportDiscoveredColumn(
              index: 0,
              rawHeader: 'Name',
              displayHeader: 'Name',
            ),
          ],
          issues: [],
          dataRowCount: 1,
        );

        var cancelled = false;
        await tester.pumpWidget(
          buildTestWidget(
            analysis: staleAnalysis,
            onCancel: () => cancelled = true,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('lead_import_preview_failure_card')),
          findsOneWidget,
        );
        expect(
          find.text('The import configuration is no longer valid.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lead_import_preview_continue_button')),
          findsNothing,
        );

        // Back button on failure card works
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(cancelled, isTrue);
      },
    );

    testWidgets('large-list lazy rendering / scroll regression (200 rows)', (
      tester,
    ) async {
      final largeRows = <List<String>>[
        ['Name', 'Phone', 'Email'],
      ];
      for (var i = 1; i <= 200; i++) {
        largeRows.add(['Customer $i', '1234500$i', 'customer$i@example.com']);
      }

      final largeParsedFile = LeadImportParsedFile(
        fileName: 'large.csv',
        source: LeadSource.csv,
        sheets: [LeadImportParsedSheet(name: 'CSV', rows: largeRows)],
      );

      const largeAnalysis = LeadImportStructureAnalysis(
        fileName: 'large.csv',
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
          LeadImportDiscoveredColumn(
            index: 2,
            rawHeader: 'Email',
            displayHeader: 'Email',
          ),
        ],
        issues: [],
        dataRowCount: 200,
      );

      const largeMapping = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
        phoneColumnIndex: 1,
        emailColumnIndex: 2,
      );

      await tester.pumpWidget(
        buildTestWidget(
          parsedFile: largeParsedFile,
          analysis: largeAnalysis,
          mapping: largeMapping,
        ),
      );
      await tester.pumpAndSettle();

      // First row (Row 2) is visible
      expect(
        find.byKey(const Key('lead_import_preview_row_2')),
        findsOneWidget,
      );

      // Row 200 is far down and not yet rendered (proving true lazy sliver rendering!)
      expect(
        find.byKey(const Key('lead_import_preview_row_200')),
        findsNothing,
      );

      // Scroll to Row 200
      await tester.scrollUntilVisible(
        find.byKey(const Key('lead_import_preview_row_200')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Row 200 is now visible
      expect(
        find.byKey(const Key('lead_import_preview_row_200')),
        findsOneWidget,
      );
      expect(find.text('Name: Customer 199'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly in dark theme without exceptions', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(find.text('Import Preview'), findsOneWidget);
      expect(find.text('customers.xlsx'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    final testViewports = <String, Size>{
      'mobile-320': const Size(320, 568),
      'mobile-360': const Size(360, 640),
      'tablet-768': const Size(768, 1024),
      'desktop-1200': const Size(1200, 800),
    };

    for (final entry in testViewports.entries) {
      testWidgets(
        'renders cleanly without overflow at viewport ${entry.key} (${entry.value.width}x${entry.value.height})',
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
            find.byKey(const Key('lead_import_preview_scroll_view')),
            findsOneWidget,
          );
          final continueButtonFinder = find.byKey(
            const Key('lead_import_preview_continue_button'),
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
