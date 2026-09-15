import 'dart:typed_data';

import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_selected_file.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_import_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/services/lead_import_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLeadImportFilePicker implements LeadImportFilePicker {
  LeadImportSelectedFile? fileToReturn;
  Exception? exceptionToThrow;

  @override
  Future<LeadImportSelectedFile?> pickFile() async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return fileToReturn;
  }
}

void main() {
  group('LeadImportScreen', () {
    late FakeLeadImportFilePicker fakePicker;

    setUp(() {
      fakePicker = FakeLeadImportFilePicker();
    });

    Widget buildTestWidget({
      LeadImportCubit? cubit,
      ValueChanged<LeadImportSelectedFile>? onContinue,
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
        home: LeadImportScreen(
          filePicker: fakePicker,
          cubit: cubit,
          onContinue: onContinue,
          onCancel: onCancel,
        ),
      );
    }

    final testCsvFile = LeadImportSelectedFile(
      name: 'annual_leads.csv',
      extension: 'csv',
      sizeBytes: 1536,
      source: LeadSource.csv,
      content: InMemoryLeadImportFileContent(Uint8List(0)),
    );

    final testXlsxFile = LeadImportSelectedFile(
      name: 'q4_enterprise.xlsx',
      extension: 'xlsx',
      sizeBytes: 124 * 1024,
      source: LeadSource.excel,
      content: InMemoryLeadImportFileContent(Uint8List(0)),
    );

    testWidgets(
      'initial state displays title, supported format guidance, and Choose File button',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Import Leads'), findsOneWidget);
        expect(find.text('Upload file'), findsOneWidget);
        expect(find.text('CSV or Excel (.xlsx)'), findsOneWidget);
        expect(
          find.byKey(const Key('lead_import_choose_file_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lead_import_continue_button')),
          findsOneWidget,
        );

        // Continue button must be disabled initially
        final continueButton = tester.widget<FilledButton>(
          find.byKey(const Key('lead_import_continue_button')),
        );
        expect(continueButton.onPressed, isNull);
      },
    );

    testWidgets(
      'tapping Choose File selects a valid CSV file and displays metadata',
      (tester) async {
        fakePicker.fileToReturn = testCsvFile;

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_choose_file_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('lead_import_selected_file_card')),
          findsOneWidget,
        );
        expect(find.text('annual_leads.csv'), findsOneWidget);
        expect(find.text('CSV File'), findsOneWidget);
        expect(find.text('1.5 KB'), findsOneWidget);
        expect(
          find.byKey(const Key('lead_import_change_file_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lead_import_remove_file_button')),
          findsOneWidget,
        );

        // Continue button must be enabled now
        final continueButton = tester.widget<FilledButton>(
          find.byKey(const Key('lead_import_continue_button')),
        );
        expect(continueButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'tapping Choose File selects XLSX file and displays Excel File badge',
      (tester) async {
        fakePicker.fileToReturn = testXlsxFile;

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_choose_file_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('q4_enterprise.xlsx'), findsOneWidget);
        expect(find.text('Excel File'), findsOneWidget);
        expect(find.text('124 KB'), findsOneWidget);
      },
    );

    testWidgets(
      'Change File replaces current selected file with new selection',
      (tester) async {
        fakePicker.fileToReturn = testCsvFile;

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_choose_file_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('annual_leads.csv'), findsOneWidget);

        // Change file to XLSX
        fakePicker.fileToReturn = testXlsxFile;
        await tester.tap(
          find.byKey(const Key('lead_import_change_file_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('annual_leads.csv'), findsNothing);
        expect(find.text('q4_enterprise.xlsx'), findsOneWidget);
        expect(find.text('Excel File'), findsOneWidget);
      },
    );

    testWidgets('Remove File resets selection back to initial drop-zone', (
      tester,
    ) async {
      fakePicker.fileToReturn = testCsvFile;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lead_import_choose_file_button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('lead_import_selected_file_card')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('lead_import_remove_file_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('lead_import_selected_file_card')),
        findsNothing,
      );
      expect(find.byKey(const Key('lead_import_upload_card')), findsOneWidget);

      final continueButton = tester.widget<FilledButton>(
        find.byKey(const Key('lead_import_continue_button')),
      );
      expect(continueButton.onPressed, isNull);
    });

    testWidgets(
      'Continue button fires onContinue callback with selected file and no import execution occurs',
      (tester) async {
        fakePicker.fileToReturn = testCsvFile;
        LeadImportSelectedFile? continuedFile;

        await tester.pumpWidget(
          buildTestWidget(
            onContinue: (file) {
              continuedFile = file;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_choose_file_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_import_continue_button')));
        await tester.pumpAndSettle();

        expect(continuedFile, isNotNull);
        expect(continuedFile?.name, equals('annual_leads.csv'));
        expect(continuedFile?.source, equals(LeadSource.csv));
      },
    );

    testWidgets('Back button invokes onCancel callback', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(
        buildTestWidget(
          onCancel: () {
            cancelled = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lead_import_back_button')));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
    });

    testWidgets(
      'displays error banner on failure and allows dismissing error',
      (tester) async {
        fakePicker.exceptionToThrow = Exception('File read error');

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_choose_file_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('lead_import_error_banner')),
          findsOneWidget,
        );
        expect(find.text('Unable to read the selected file.'), findsOneWidget);

        // Dismiss error
        await tester.tap(
          find.byKey(const Key('lead_import_error_dismiss_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('lead_import_error_banner')), findsNothing);
      },
    );

    testWidgets('renders long file name without RenderFlex overflow', (
      tester,
    ) async {
      final longNamedFile = LeadImportSelectedFile(
        name:
            'enterprise_customer_leads_september_2026_final_version_very_long_title.xlsx',
        extension: 'xlsx',
        sizeBytes: 450000,
        source: LeadSource.excel,
        content: InMemoryLeadImportFileContent(Uint8List(0)),
      );
      fakePicker.fileToReturn = longNamedFile;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lead_import_choose_file_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('lead_import_selected_file_card')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly in dark theme', (tester) async {
      fakePicker.fileToReturn = testXlsxFile;

      await tester.pumpWidget(buildTestWidget(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lead_import_choose_file_button')));
      await tester.pumpAndSettle();

      expect(find.text('q4_enterprise.xlsx'), findsOneWidget);
      expect(find.text('Excel File'), findsOneWidget);
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

          fakePicker.fileToReturn = testCsvFile;

          await tester.pumpWidget(buildTestWidget());
          await tester.pumpAndSettle();

          // Initial state
          expect(
            find.byKey(const Key('lead_import_upload_card')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          // Select file
          await tester.tap(
            find.byKey(const Key('lead_import_choose_file_button')),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('lead_import_selected_file_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('lead_import_continue_button')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
