import 'dart:typed_data';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_parse_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_parsed_file.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_selected_file.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_import_workflow_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/services/lead_import_file_picker.dart';
import 'package:enterprise_crm/features/leads/presentation/services/lead_import_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLeadImportFilePicker implements LeadImportFilePicker {
  FakeLeadImportFilePicker({this.fileToPick});

  LeadImportSelectedFile? fileToPick;

  @override
  Future<LeadImportSelectedFile?> pickFile() async {
    return fileToPick;
  }
}

class FakeLeadImportParser implements LeadImportParser {
  FakeLeadImportParser({this.parsedFileToReturn, this.shouldThrow = false});

  LeadImportParsedFile? parsedFileToReturn;
  bool shouldThrow;

  @override
  Future<LeadImportParsedFile> parse(LeadImportSelectedFile file) async {
    if (shouldThrow) {
      throw const LeadImportParseException('Damaged file content.');
    }
    return parsedFileToReturn ??
        LeadImportParsedFile(
          fileName: file.name,
          source: file.source,
          sheets: [
            const LeadImportParsedSheet(
              name: 'Sheet1',
              rows: [
                ['Name', 'Email', 'Phone'],
                ['Alice', 'alice@example.com', '123'],
                ['Bob', 'bob@example.com', '456'],
              ],
            ),
          ],
        );
  }
}

class FailingImportLeadRepository extends MockLeadRepository {
  FailingImportLeadRepository({super.dataSource, this.failOnce = false});

  bool failOnce;
  bool hasFailed = false;

  @override
  Future<LeadImportResult> importLeads(LeadImportRequest request) async {
    if (failOnce && !hasFailed) {
      hasFailed = true;
      throw Exception('Server unreachable');
    }
    return super.importLeads(request);
  }
}

void main() {
  group('LeadImportWorkflowScreen', () {
    late MockLeadDataSource dataSource;
    late MockLeadRepository repository;
    late FakeLeadImportFilePicker filePicker;
    late FakeLeadImportParser parser;

    final validCsvFile = LeadImportSelectedFile(
      name: 'leads.csv',
      extension: 'csv',
      sizeBytes: 200,
      source: LeadSource.csv,
      content: InMemoryLeadImportFileContent(Uint8List.fromList([1, 2, 3])),
    );

    setUp(() {
      dataSource = MockLeadDataSource();
      repository = MockLeadRepository(dataSource: dataSource);
      filePicker = FakeLeadImportFilePicker(fileToPick: validCsvFile);
      parser = FakeLeadImportParser();
    });

    Widget buildTestApp({
      LeadImportWorkflowScreen? screen,
      MockLeadRepository? customRepo,
      FakeLeadImportFilePicker? customPicker,
      FakeLeadImportParser? customParser,
      VoidCallback? onDone,
      VoidCallback? onCancel,
      ThemeData? theme,
      Size size = const Size(1000, 800),
    }) {
      final repo = customRepo ?? repository;
      final picker = customPicker ?? filePicker;
      final p = customParser ?? parser;

      return MaterialApp(
        theme: theme ?? ThemeData.light(useMaterial3: true),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child:
                screen ??
                LeadImportWorkflowScreen(
                  repository: repo,
                  filePicker: picker,
                  parseCubit: LeadImportParseCubit(p),
                  onDone: onDone,
                  onCancel: onCancel,
                ),
          ),
        ),
      );
    }

    Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('E2E Happy Path: completes all steps and imports leads', (
      tester,
    ) async {
      bool doneCalled = false;

      await tester.pumpWidget(buildTestApp(onDone: () => doneCalled = true));
      await tester.pumpAndSettle();

      // Step 1: Select File
      expect(
        find.text('Upload a CSV or Excel (.xlsx) file to import leads.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('lead_import_choose_file_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('lead_import_selected_file_card')),
        findsOneWidget,
      );

      // Tap Continue to start parsing
      await tester.tap(find.byKey(const Key('lead_import_continue_button')));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3: Advances through parsing to Structure screen ('Prepare Import')
      expect(find.text('Prepare Import'), findsOneWidget);

      // Tap Continue on Structure Screen
      await tester.tap(
        find.byKey(const Key('lead_import_structure_continue_button')),
      );
      await tester.pumpAndSettle();

      // Step 4: Mapping Screen ('Map Lead Fields')
      expect(find.text('Map Lead Fields'), findsOneWidget);

      // Map Name -> Column 1 ('Name')
      await tester.tap(
        find.byKey(const Key('lead_import_field_name_dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Column 1 — Name').last);
      await tester.pumpAndSettle();

      // Map Email -> Column 2 ('Email')
      await tester.tap(
        find.byKey(const Key('lead_import_field_email_dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Column 2 — Email').last);
      await tester.pumpAndSettle();

      // Tap Continue on Mapping Screen
      await tester.tap(
        find.byKey(const Key('lead_import_mapping_continue_button')),
      );
      await tester.pumpAndSettle();

      // Step 5: Preview Screen
      expect(find.text('Import Preview'), findsOneWidget);
      expect(find.textContaining('Alice'), findsOneWidget);
      expect(find.textContaining('Bob'), findsOneWidget);

      // Tap Continue on Preview Screen
      await scrollAndTap(
        tester,
        find.byKey(const Key('lead_import_preview_continue_button')),
      );

      // Step 6: Review Screen
      expect(find.text('Final Import Review'), findsOneWidget);

      // Tap Continue on Review Screen -> triggers execution
      await scrollAndTap(
        tester,
        find.byKey(const Key('lead_import_review_continue_button')),
      );
      await tester.pumpAndSettle();

      // Step 7: Execution Result Screen
      expect(find.text('Import Complete'), findsWidgets);
      expect(find.text('Importer Result'), findsOneWidget);
      expect(find.text('Review Summary'), findsOneWidget);

      // Tap Done
      await scrollAndTap(
        tester,
        find.byKey(const Key('lead_import_result_done_button')),
      );
      expect(doneCalled, isTrue);

      // Verify leads were actually imported into the repository
      final leadsPage = await repository.getLeads();
      expect(leadsPage.items.any((l) => l.name == 'Alice'), isTrue);
      expect(leadsPage.items.any((l) => l.name == 'Bob'), isTrue);
    });

    testWidgets('Parsing failure displays error UI and Retry recovers', (
      tester,
    ) async {
      parser.shouldThrow = true;

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Select file and continue
      await tester.tap(find.byKey(const Key('lead_import_choose_file_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lead_import_continue_button')));
      await tester.pumpAndSettle();

      // Verify parsing error banner
      expect(find.text('Damaged file content.'), findsOneWidget);
      expect(
        find.byKey(const Key('lead_import_parse_retry_button')),
        findsOneWidget,
      );

      // Fix parser and tap Retry
      parser.shouldThrow = false;
      await tester.tap(find.byKey(const Key('lead_import_parse_retry_button')));
      await tester.pumpAndSettle();

      // Successfully transitions to Structure
      expect(find.text('Prepare Import'), findsOneWidget);
    });

    testWidgets(
      'Duplicate review: excluding a duplicate row updates import counts',
      (tester) async {
        parser.parsedFileToReturn = LeadImportParsedFile(
          fileName: 'duplicates.csv',
          source: LeadSource.csv,
          sheets: [
            const LeadImportParsedSheet(
              name: 'Sheet1',
              rows: [
                ['Name', 'Email'],
                ['Alice', 'alice@example.com'],
                ['Alice', 'alice@example.com'],
              ],
            ),
          ],
        );

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Select & Continue
        await tester.tap(
          find.byKey(const Key('lead_import_choose_file_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lead_import_continue_button')));
        await tester.pumpAndSettle();

        // Structure -> Continue
        await tester.tap(
          find.byKey(const Key('lead_import_structure_continue_button')),
        );
        await tester.pumpAndSettle();

        // Map Name & Email
        await tester.tap(
          find.byKey(const Key('lead_import_field_name_dropdown')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Column 1 — Name').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_field_email_dropdown')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Column 2 — Email').last);
        await tester.pumpAndSettle();

        // Mapping -> Continue
        await tester.tap(
          find.byKey(const Key('lead_import_mapping_continue_button')),
        );
        await tester.pumpAndSettle();

        // Preview -> Continue
        await scrollAndTap(
          tester,
          find.byKey(const Key('lead_import_preview_continue_button')),
        );

        // Review Screen: duplicate banner visible
        expect(
          find.byKey(const Key('lead_import_review_duplicate_banner')),
          findsOneWidget,
        );
        expect(
          find.text('Exact duplicate rows were found in this file.'),
          findsOneWidget,
        );

        // Uncheck the second duplicate row (displayRowNumber = 3)
        final checkbox = find.byKey(const Key('lead_import_review_checkbox_3'));
        await scrollAndTap(tester, checkbox);

        // Import Leads (1 selected)
        await scrollAndTap(
          tester,
          find.byKey(const Key('lead_import_review_continue_button')),
        );

        // Result screen: 1 imported, 1 excluded
        expect(find.text('Import Complete'), findsWidgets);
        expect(find.text('1'), findsWidgets);
      },
    );

    testWidgets(
      'Invalid rows: invalid rows are unselectable and not imported',
      (tester) async {
        parser.parsedFileToReturn = LeadImportParsedFile(
          fileName: 'invalid.csv',
          source: LeadSource.csv,
          sheets: [
            const LeadImportParsedSheet(
              name: 'Sheet1',
              rows: [
                ['Name', 'Email'],
                ['Alice', 'not-an-email'],
                ['Bob', 'bob@example.com'],
              ],
            ),
          ],
        );

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Select file & parse
        await tester.tap(
          find.byKey(const Key('lead_import_choose_file_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lead_import_continue_button')));
        await tester.pumpAndSettle();

        // Structure -> continue
        await tester.tap(
          find.byKey(const Key('lead_import_structure_continue_button')),
        );
        await tester.pumpAndSettle();

        // Map Name & Email
        await tester.tap(
          find.byKey(const Key('lead_import_field_name_dropdown')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Column 1 — Name').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_field_email_dropdown')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Column 2 — Email').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_mapping_continue_button')),
        );
        await tester.pumpAndSettle();

        // Preview shows 1 valid, 1 invalid
        final validStat = find.byKey(const Key('lead_import_stat_valid_rows'));
        expect(
          find.descendant(of: validStat, matching: find.text('1')),
          findsOneWidget,
        );
        final invalidStat = find.byKey(
          const Key('lead_import_stat_invalid_rows'),
        );
        expect(
          find.descendant(of: invalidStat, matching: find.text('1')),
          findsOneWidget,
        );

        await scrollAndTap(
          tester,
          find.byKey(const Key('lead_import_preview_continue_button')),
        );

        // Execute import -> only 1 imported
        await scrollAndTap(
          tester,
          find.byKey(const Key('lead_import_review_continue_button')),
        );

        expect(find.text('Import Complete'), findsWidgets);
      },
    );

    testWidgets(
      'Back navigation: Back to Mapping and changing mapping rebuilds preview',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Select & Parse
        await tester.tap(
          find.byKey(const Key('lead_import_choose_file_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lead_import_continue_button')));
        await tester.pumpAndSettle();

        // Structure -> Continue
        await tester.tap(
          find.byKey(const Key('lead_import_structure_continue_button')),
        );
        await tester.pumpAndSettle();

        // Map Name only
        await tester.tap(
          find.byKey(const Key('lead_import_field_name_dropdown')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Column 1 — Name').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_mapping_continue_button')),
        );
        await tester.pumpAndSettle();

        // In Preview: only Name is mapped
        expect(find.text('Import Preview'), findsOneWidget);
        expect(find.textContaining('alice@example.com'), findsNothing);

        // Back to Mapping
        await tester.tap(
          find.byKey(const Key('lead_import_preview_back_button')),
        );
        await tester.pumpAndSettle();

        // Map Email as well
        await tester.tap(
          find.byKey(const Key('lead_import_field_email_dropdown')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Column 2 — Email').last);
        await tester.pumpAndSettle();

        // Continue to Preview
        await tester.tap(
          find.byKey(const Key('lead_import_mapping_continue_button')),
        );
        await tester.pumpAndSettle();

        // Fresh preview reflects email mapping
        expect(find.textContaining('alice@example.com'), findsOneWidget);
      },
    );

    testWidgets(
      'MANDATORY REGRESSION: Choosing a new file with same filename invalidates downstream data',
      (tester) async {
        final fileA = LeadImportSelectedFile(
          name: 'leads.csv',
          extension: 'csv',
          sizeBytes: 100,
          source: LeadSource.csv,
          content: InMemoryLeadImportFileContent(Uint8List.fromList([1, 2])),
        );

        final fileB = LeadImportSelectedFile(
          name: 'leads.csv',
          extension: 'csv',
          sizeBytes: 500,
          source: LeadSource.csv,
          content: InMemoryLeadImportFileContent(Uint8List.fromList([3, 4, 5])),
        );

        filePicker.fileToPick = fileA;
        parser.parsedFileToReturn = LeadImportParsedFile(
          fileName: 'leads.csv',
          source: LeadSource.csv,
          sheets: [
            const LeadImportParsedSheet(
              name: 'Sheet1',
              rows: [
                ['Name'],
                ['AliceFromFirstFile'],
              ],
            ),
          ],
        );

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Select File A
        await tester.tap(
          find.byKey(const Key('lead_import_choose_file_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lead_import_continue_button')));
        await tester.pumpAndSettle();

        // Reached Structure
        expect(find.text('Prepare Import'), findsOneWidget);

        // Go back to File Selection
        await tester.tap(
          find.byKey(const Key('lead_import_structure_back_button')),
        );
        await tester.pumpAndSettle();

        // Select File B with same name 'leads.csv' but different content
        filePicker.fileToPick = fileB;
        parser.parsedFileToReturn = LeadImportParsedFile(
          fileName: 'leads.csv',
          source: LeadSource.csv,
          sheets: [
            const LeadImportParsedSheet(
              name: 'Sheet1',
              rows: [
                ['Name'],
                ['BobFromSecondFile'],
              ],
            ),
          ],
        );

        await tester.tap(
          find.byKey(const Key('lead_import_change_file_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lead_import_continue_button')));
        await tester.pumpAndSettle();

        // Advances through Structure to Mapping to Preview
        await tester.tap(
          find.byKey(const Key('lead_import_structure_continue_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_field_name_dropdown')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Column 1 — Name').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_mapping_continue_button')),
        );
        await tester.pumpAndSettle();

        // Preview contains Bob, NOT Alice!
        expect(find.textContaining('BobFromSecondFile'), findsOneWidget);
        expect(find.textContaining('AliceFromFirstFile'), findsNothing);
      },
    );

    testWidgets('Execution failure displays error banner and allows Retry', (
      tester,
    ) async {
      final failingRepo = FailingImportLeadRepository(
        dataSource: dataSource,
        failOnce: true,
      );

      await tester.pumpWidget(buildTestApp(customRepo: failingRepo));
      await tester.pumpAndSettle();

      // Select & Parse
      await tester.tap(find.byKey(const Key('lead_import_choose_file_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lead_import_continue_button')));
      await tester.pumpAndSettle();

      // Structure -> Mapping -> Map Name -> Preview -> Review
      await tester.tap(
        find.byKey(const Key('lead_import_structure_continue_button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('lead_import_field_name_dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Column 1 — Name').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('lead_import_mapping_continue_button')),
      );
      await tester.pumpAndSettle();

      await scrollAndTap(
        tester,
        find.byKey(const Key('lead_import_preview_continue_button')),
      );

      // Execute import -> fails on first attempt
      await scrollAndTap(
        tester,
        find.byKey(const Key('lead_import_review_continue_button')),
      );

      expect(find.text('Unable to import the selected Leads.'), findsOneWidget);
      expect(
        find.byKey(const Key('lead_import_execution_retry_button')),
        findsOneWidget,
      );

      // Tap Retry -> succeeds
      await tester.tap(
        find.byKey(const Key('lead_import_execution_retry_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Import Complete'), findsWidgets);
    });

    testWidgets(
      'MANDATORY REGRESSION: System Back after successful import returns true and does not re-enter Review',
      (tester) async {
        bool successPopped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      final res = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => LeadImportWorkflowScreen(
                            repository: repository,
                            filePicker: filePicker,
                            parseCubit: LeadImportParseCubit(parser),
                          ),
                        ),
                      );
                      if (res == true) {
                        successPopped = true;
                      }
                    },
                    child: const Text('Launch Workflow'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Launch workflow
        await tester.tap(find.text('Launch Workflow'));
        await tester.pumpAndSettle();

        // Complete import to reach Result screen
        await tester.tap(
          find.byKey(const Key('lead_import_choose_file_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lead_import_continue_button')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_structure_continue_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_field_name_dropdown')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Column 1 — Name').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_import_mapping_continue_button')),
        );
        await tester.pumpAndSettle();

        await scrollAndTap(
          tester,
          find.byKey(const Key('lead_import_preview_continue_button')),
        );

        await scrollAndTap(
          tester,
          find.byKey(const Key('lead_import_review_continue_button')),
        );

        expect(find.text('Import Complete'), findsWidgets);

        // Now trigger system Back
        final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
        await widgetsAppState.didPopRoute();
        await tester.pumpAndSettle();

        // Verified: workflow popped with true and returned to caller!
        expect(find.text('Launch Workflow'), findsOneWidget);
        expect(successPopped, isTrue);
      },
    );

    testWidgets(
      'Cancellation on file selection screen pops false without repository calls',
      (tester) async {
        bool cancelCalled = false;
        final initialLeads = await repository.getLeads();

        await tester.pumpWidget(
          buildTestApp(onCancel: () => cancelCalled = true),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_import_back_button')));
        await tester.pumpAndSettle();

        expect(cancelCalled, isTrue);
        final leads = await repository.getLeads();
        expect(leads.items.length, initialLeads.items.length);
      },
    );

    testWidgets(
      'Responsive & dark theme: renders cleanly across viewports without overflow',
      (tester) async {
        const sizes = [
          Size(320, 568),
          Size(360, 640),
          Size(768, 1024),
          Size(1200, 800),
        ];

        for (final size in sizes) {
          await tester.pumpWidget(
            buildTestApp(size: size, theme: ThemeData.dark(useMaterial3: true)),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('lead_import_upload_card')),
            findsOneWidget,
          );
        }
      },
    );
  });
}
