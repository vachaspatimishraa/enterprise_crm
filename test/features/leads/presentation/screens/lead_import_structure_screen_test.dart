import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_parsed_file.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_structure_analysis.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_import_structure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportStructureScreen', () {
    final validCsvFile = LeadImportParsedFile(
      fileName: 'customers.csv',
      source: LeadSource.csv,
      sheets: [
        LeadImportParsedSheet(
          name: 'CSV',
          rows: [
            ['Name', 'Phone', 'Email'],
            ['Alice Smith', '555-0100', 'alice@test.com'],
            ['Bob Jones', '555-0200', 'bob@test.com'],
          ],
        ),
      ],
    );

    final multiSheetXlsxFile = LeadImportParsedFile(
      fileName: 'q4_enterprise.xlsx',
      source: LeadSource.excel,
      sheets: [
        LeadImportParsedSheet(
          name: 'North America',
          rows: [
            ['Account Name', 'Contact Person', 'Territory'],
            ['Acme Inc', 'John Doe', 'East'],
          ],
        ),
        LeadImportParsedSheet(
          name: 'Europe',
          rows: [
            ['Company', 'Lead Status', 'Country'],
            ['Globex Corp', 'Qualified', 'Germany'],
          ],
        ),
      ],
    );

    final emptySheetFile = LeadImportParsedFile(
      fileName: 'empty.xlsx',
      source: LeadSource.excel,
      sheets: [LeadImportParsedSheet(name: 'BlankSheet', rows: [])],
    );

    final warningFile = LeadImportParsedFile(
      fileName: 'leads_with_warnings.csv',
      source: LeadSource.csv,
      sheets: [
        LeadImportParsedSheet(
          name: 'CSV',
          rows: [
            ['Phone', '  ', 'phone'],
            ['555-1111', 'Notes', '555-2222'],
          ],
        ),
      ],
    );

    Widget buildTestWidget({
      required LeadImportParsedFile parsedFile,
      ValueChanged<LeadImportStructureAnalysis>? onContinue,
      VoidCallback? onCancel,
      ThemeMode themeMode = ThemeMode.light,
    }) {
      return MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: themeMode,
        home: LeadImportStructureScreen(
          parsedFile: parsedFile,
          onContinue: onContinue,
          onCancel: onCancel,
        ),
      );
    }

    testWidgets(
      'renders CSV structure with single sheet label, header selector, detected columns, and enabled Continue button',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(parsedFile: validCsvFile));
        await tester.pumpAndSettle();

        expect(find.text('Prepare Import'), findsOneWidget);
        expect(find.text('customers.csv'), findsOneWidget);
        expect(find.text('CSV File'), findsOneWidget);
        expect(find.text('Sheet: '), findsOneWidget);
        expect(find.text('CSV'), findsOneWidget);
        expect(
          find.byKey(const Key('lead_import_sheet_selector')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('lead_import_header_row_selector')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lead_import_detected_columns_card')),
          findsOneWidget,
        );
        expect(find.text('Detected Columns (3)'), findsOneWidget);
        expect(find.text('Data rows: 2'), findsOneWidget);
        expect(find.text('Name'), findsOneWidget);
        expect(find.text('Phone'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);

        final continueButton = tester.widget<FilledButton>(
          find.byKey(const Key('lead_import_structure_continue_button')),
        );
        expect(continueButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'renders multi-sheet XLSX with sheet selector dropdown and switches sheets cleanly',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(parsedFile: multiSheetXlsxFile),
        );
        await tester.pumpAndSettle();

        expect(find.text('q4_enterprise.xlsx'), findsOneWidget);
        expect(find.text('Excel (.xlsx)'), findsOneWidget);
        expect(
          find.byKey(const Key('lead_import_sheet_selector')),
          findsOneWidget,
        );

        // Initially Sheet 0 (North America)
        expect(find.text('North America'), findsWidgets);
        expect(find.text('Account Name'), findsOneWidget);
        expect(find.text('Contact Person'), findsOneWidget);
        expect(find.text('Territory'), findsOneWidget);

        // Tap dropdown and select Sheet 1 (Europe)
        await tester.tap(find.byKey(const Key('lead_import_sheet_selector')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Europe').last);
        await tester.pumpAndSettle();

        // Columns should update to Europe's columns
        expect(find.text('Company'), findsOneWidget);
        expect(find.text('Lead Status'), findsOneWidget);
        expect(find.text('Country'), findsOneWidget);
        expect(find.text('Account Name'), findsNothing);
      },
    );

    testWidgets('changing header row recomputes columns and data row count', (
      tester,
    ) async {
      final fileWithHeaderRow1 = LeadImportParsedFile(
        fileName: 'skip_title.csv',
        source: LeadSource.csv,
        sheets: [
          LeadImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Title: Q3 Leads', 'Confidential', 'Exported 2026'],
              ['Client Name', 'Mobile Number', 'Industry'],
              ['Globex', '555-4321', 'Technology'],
            ],
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(parsedFile: fileWithHeaderRow1));
      await tester.pumpAndSettle();

      // Row 1 (index 0) columns initially
      expect(find.text('Title: Q3 Leads'), findsOneWidget);
      expect(find.text('Data rows: 2'), findsOneWidget);

      // Change header row to Row 2
      await tester.tap(
        find.byKey(const Key('lead_import_header_row_selector')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Row 2').last);
      await tester.pumpAndSettle();

      // Now Row 2 is header
      expect(find.text('Client Name'), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Industry'), findsOneWidget);
      expect(find.text('Data rows: 1'), findsOneWidget);
    });

    testWidgets(
      'displays blocking error banner and disables Continue when sheet is empty',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(parsedFile: emptySheetFile));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('lead_import_errors_banner')),
          findsOneWidget,
        );
        expect(find.text('The selected sheet is empty.'), findsOneWidget);

        final continueButton = tester.widget<FilledButton>(
          find.byKey(const Key('lead_import_structure_continue_button')),
        );
        expect(continueButton.onPressed, isNull);
      },
    );

    testWidgets(
      'displays warning banner for duplicate or blank headers, but keeps Continue enabled',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(parsedFile: warningFile));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('lead_import_warnings_banner')),
          findsOneWidget,
        );
        expect(find.text('Duplicate column name: "Phone".'), findsOneWidget);
        expect(find.text('Blank header at column 2.'), findsOneWidget);

        // Discovered columns keep synthetic label for blank header
        expect(find.text('Column 2'), findsOneWidget);

        // Continue button remains enabled
        final continueButton = tester.widget<FilledButton>(
          find.byKey(const Key('lead_import_structure_continue_button')),
        );
        expect(continueButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'tapping Continue button invokes onContinue callback with analysis',
      (tester) async {
        LeadImportStructureAnalysis? receivedAnalysis;

        await tester.pumpWidget(
          buildTestWidget(
            parsedFile: validCsvFile,
            onContinue: (analysis) => receivedAnalysis = analysis,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_structure_continue_button')),
        );
        await tester.pumpAndSettle();

        expect(receivedAnalysis, isNotNull);
        expect(receivedAnalysis!.fileName, 'customers.csv');
        expect(receivedAnalysis!.columns.length, 3);
        expect(receivedAnalysis!.dataRowCount, 2);
        expect(receivedAnalysis!.isValid, isTrue);
      },
    );

    testWidgets('tapping back button invokes onCancel callback', (
      tester,
    ) async {
      var cancelCalled = false;

      await tester.pumpWidget(
        buildTestWidget(
          parsedFile: validCsvFile,
          onCancel: () => cancelCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('lead_import_structure_back_button')),
      );
      await tester.pumpAndSettle();

      expect(cancelCalled, isTrue);
    });

    testWidgets('renders cleanly in dark theme without exceptions', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(parsedFile: validCsvFile, themeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();

      expect(find.text('customers.csv'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
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

          await tester.pumpWidget(
            buildTestWidget(parsedFile: multiSheetXlsxFile),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('lead_import_sheet_selector')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('lead_import_header_row_selector')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('lead_import_structure_continue_button')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
