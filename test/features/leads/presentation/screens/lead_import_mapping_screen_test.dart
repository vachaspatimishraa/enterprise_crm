import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_parsed_file.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_structure_analysis.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_import_mapping_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportMappingScreen', () {
    const testAnalysis = LeadImportStructureAnalysis(
      fileName: 'customers.xlsx',
      source: LeadSource.excel,
      sheetIndex: 0,
      sheetName: 'Sheet1',
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
      dataRowCount: 10,
      issues: [],
    );

    final testParsedFile = LeadImportParsedFile(
      fileName: 'customers.xlsx',
      source: LeadSource.excel,
      sheets: [
        LeadImportParsedSheet(
          name: 'Sheet1',
          rows: [
            ['Customer Name', 'Mobile Phone', 'Email Address'],
            ['Alice', '1234567890', 'alice@test.com'],
          ],
        ),
      ],
    );

    Widget buildTestWidget({
      LeadImportStructureAnalysis analysis = testAnalysis,
      LeadImportParsedFile? parsedFile,
      ValueChanged<LeadImportColumnMapping>? onContinue,
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
        home: LeadImportMappingScreen(
          parsedFile: parsedFile ?? testParsedFile,
          analysis: analysis,
          onContinue: onContinue,
          onCancel: onCancel,
        ),
      );
    }

    testWidgets(
      'renders screen title, file metadata, guidance, 3 dropdowns set to Not mapped, and disabled Continue',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Map Lead Fields'), findsOneWidget);
        expect(find.text('customers.xlsx'), findsOneWidget);
        expect(find.text('Excel (.xlsx)'), findsOneWidget);
        expect(find.text('Sheet: Sheet1'), findsOneWidget);
        expect(find.text('Header: Row 1'), findsOneWidget);
        expect(
          find.text(
            'Choose which spreadsheet column should fill each Lead field.',
          ),
          findsOneWidget,
        );

        // Three field labels
        expect(find.text('Lead Name'), findsOneWidget);
        expect(find.text('Phone'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);

        // All 3 dropdowns exist and show 'Not mapped'
        expect(find.text('Not mapped'), findsNWidgets(3));

        // Validation reminder
        expect(
          find.byKey(const Key('lead_import_mapping_validation_text')),
          findsOneWidget,
        );

        // Continue button is disabled
        final continueButton = tester.widget<FilledButton>(
          find.byKey(const Key('lead_import_mapping_continue_button')),
        );
        expect(continueButton.onPressed, isNull);
      },
    );

    testWidgets(
      'selecting a column enables Continue and clears validation text',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Tap Name dropdown
        await tester.tap(
          find.byKey(const Key('lead_import_field_name_dropdown')),
        );
        await tester.pumpAndSettle();

        // Select 'Column 1 — Customer Name'
        await tester.tap(find.text('Column 1 — Customer Name').last);
        await tester.pumpAndSettle();

        // Continue is now enabled
        final continueButton = tester.widget<FilledButton>(
          find.byKey(const Key('lead_import_mapping_continue_button')),
        );
        expect(continueButton.onPressed, isNotNull);

        // Validation text is hidden
        expect(
          find.byKey(const Key('lead_import_mapping_validation_text')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'conflict resolution: selecting same column for Email automatically clears Phone',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // 1. Map Phone to Column 2 — Mobile Phone
        await tester.tap(
          find.byKey(const Key('lead_import_field_phone_dropdown')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Column 2 — Mobile Phone').last);
        await tester.pumpAndSettle();

        expect(find.text('Column 2 — Mobile Phone'), findsOneWidget);

        // 2. Map Email to Column 2 — Mobile Phone
        await tester.tap(
          find.byKey(const Key('lead_import_field_email_dropdown')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Column 2 — Mobile Phone').last);
        await tester.pumpAndSettle();

        // Phone is automatically reset to 'Not mapped', Email is now Column 2
        expect(find.text('Column 2 — Mobile Phone'), findsOneWidget);
        expect(find.text('Not mapped'), findsNWidgets(2)); // Name and Phone
      },
    );

    testWidgets('unmapping field sets it back to Not mapped', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Map Name
      await tester.tap(
        find.byKey(const Key('lead_import_field_name_dropdown')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Column 1 — Customer Name').last);
      await tester.pumpAndSettle();

      expect(find.text('Column 1 — Customer Name'), findsOneWidget);

      // Unmap Name
      await tester.tap(
        find.byKey(const Key('lead_import_field_name_dropdown')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not mapped').last);
      await tester.pumpAndSettle();

      // Continue is disabled again
      final continueButton = tester.widget<FilledButton>(
        find.byKey(const Key('lead_import_mapping_continue_button')),
      );
      expect(continueButton.onPressed, isNull);
    });

    testWidgets(
      'distinguishes duplicate headers with distinct column number labels',
      (tester) async {
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

        await tester.pumpWidget(buildTestWidget(analysis: duplicateAnalysis));
        await tester.pumpAndSettle();

        // Warning banner shown
        expect(
          find.byKey(const Key('lead_import_mapping_warnings_banner')),
          findsOneWidget,
        );

        // Tap Phone dropdown
        await tester.tap(
          find.byKey(const Key('lead_import_field_phone_dropdown')),
        );
        await tester.pumpAndSettle();

        // Both options exist distinctly
        expect(find.text('Column 1 — Phone'), findsWidgets);
        expect(find.text('Column 2 — Phone'), findsWidgets);

        // Select Column 2
        await tester.tap(find.text('Column 2 — Phone').last);
        await tester.pumpAndSettle();

        expect(find.text('Column 2 — Phone'), findsOneWidget);
      },
    );

    testWidgets('allows selecting blank-header synthetic column', (
      tester,
    ) async {
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

      await tester.pumpWidget(buildTestWidget(analysis: blankHeaderAnalysis));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('lead_import_field_email_dropdown')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Column 2 — Column 2'), findsWidgets);

      await tester.tap(find.text('Column 2 — Column 2').last);
      await tester.pumpAndSettle();

      expect(find.text('Column 2 — Column 2'), findsOneWidget);
    });

    testWidgets(
      'shows error banner and disables Continue when analysis has blocking errors',
      (tester) async {
        const errorAnalysis = LeadImportStructureAnalysis(
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

        await tester.pumpWidget(buildTestWidget(analysis: errorAnalysis));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('lead_import_mapping_errors_banner')),
          findsOneWidget,
        );
        expect(
          find.text('No data rows were found below the selected header.'),
          findsOneWidget,
        );

        final continueButton = tester.widget<FilledButton>(
          find.byKey(const Key('lead_import_mapping_continue_button')),
        );
        expect(continueButton.onPressed, isNull);
      },
    );

    testWidgets('tapping Continue invokes onContinue callback with mapping', (
      tester,
    ) async {
      LeadImportColumnMapping? receivedMapping;

      await tester.pumpWidget(
        buildTestWidget(onContinue: (mapping) => receivedMapping = mapping),
      );
      await tester.pumpAndSettle();

      // Map Name to 0 and Email to 2
      await tester.tap(
        find.byKey(const Key('lead_import_field_name_dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Column 1 — Customer Name').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('lead_import_field_email_dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Column 3 — Email Address').last);
      await tester.pumpAndSettle();

      // Tap Continue
      await tester.tap(
        find.byKey(const Key('lead_import_mapping_continue_button')),
      );
      await tester.pumpAndSettle();

      expect(receivedMapping, isNotNull);
      expect(receivedMapping!.nameColumnIndex, equals(0));
      expect(receivedMapping!.phoneColumnIndex, isNull);
      expect(receivedMapping!.emailColumnIndex, equals(2));
      expect(receivedMapping!.sheetIndex, equals(0));
      expect(receivedMapping!.headerRowIndex, equals(0));
    });

    testWidgets('tapping Back button invokes onCancel callback', (
      tester,
    ) async {
      var cancelled = false;

      await tester.pumpWidget(
        buildTestWidget(onCancel: () => cancelled = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('lead_import_mapping_back_button')),
      );
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
    });

    testWidgets('renders cleanly in dark theme without exceptions', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(find.text('Map Lead Fields'), findsOneWidget);
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

          // Long headers test
          const longHeaderAnalysis = LeadImportStructureAnalysis(
            fileName: 'long_headers_very_long_file_name_2026.csv',
            source: LeadSource.csv,
            sheetIndex: 0,
            sheetName: 'Primary Export Sheet With Long Label',
            headerRowIndex: 0,
            columns: [
              LeadImportDiscoveredColumn(
                index: 0,
                rawHeader: 'Primary Customer Contact Full Name Label',
                displayHeader: 'Primary Customer Contact Full Name Label',
              ),
              LeadImportDiscoveredColumn(
                index: 1,
                rawHeader: 'Mobile Phone Direct Cellular Telephone Number',
                displayHeader: 'Mobile Phone Direct Cellular Telephone Number',
              ),
            ],
            dataRowCount: 10,
            issues: [],
          );

          await tester.pumpWidget(
            buildTestWidget(analysis: longHeaderAnalysis),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('lead_import_field_name_dropdown')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('lead_import_field_phone_dropdown')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('lead_import_mapping_continue_button')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
