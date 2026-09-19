import 'dart:async';

import 'package:enterprise_crm/features/leads/data/services/lead_export_file_saver.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignee.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_summary.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_export_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/widgets/lead_export_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements LeadRepository {
  LeadExportRequest? lastExportRequest;
  int exportLeadsCallCount = 0;
  bool shouldThrowOnExport = false;
  Completer<LeadExportResult>? exportCompleter;
  LeadExportResult exportResult = const LeadExportResult(
    fileReference: 'dummy_ref',
    fileName: 'leads_export.xlsx',
  );

  @override
  Future<LeadExportResult> exportLeads(LeadExportRequest request) async {
    exportLeadsCallCount++;
    lastExportRequest = request;
    if (exportCompleter != null) {
      return await exportCompleter!.future;
    }
    if (shouldThrowOnExport) {
      throw Exception('Repository export failure');
    }
    return exportResult;
  }

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async =>
      const LeadPage(
        items: [],
        currentPage: 1,
        pageSize: 20,
        totalItems: 0,
        hasNext: false,
      );

  @override
  Future<LeadSummary> getLeadSummary() async => const LeadSummary(
    totalLeads: 0,
    assignedLeads: 0,
    unassignedLeads: 0,
    manualLeads: 0,
    excelLeads: 0,
    csvLeads: 0,
  );

  @override
  Future<Lead?> getLeadById(String leadId) async => null;

  @override
  Future<Lead> createLead(CreateLeadInput input) async =>
      throw UnimplementedError();

  @override
  Future<Lead> updateLead(UpdateLeadInput input) async =>
      throw UnimplementedError();

  @override
  Future<void> assignLead({
    required String leadId,
    required String assigneeId,
  }) async {}

  @override
  Future<void> assignLeads(LeadAssignmentRequest request) async {}

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) async {}

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async => const [];

  @override
  Future<LeadImportResult> importLeads(LeadImportRequest request) async =>
      throw UnimplementedError();
}

class _FakeLeadExportFileSaver implements LeadExportFileSaver {
  int saveCallCount = 0;
  bool shouldThrowOnSave = false;
  LeadExportSaveResult saveResult = const LeadExportSaveResult.saved();
  Completer<LeadExportSaveResult>? saveCompleter;

  @override
  Future<LeadExportSaveResult> save(LeadExportResult result) async {
    saveCallCount++;
    if (saveCompleter != null) {
      return await saveCompleter!.future;
    }
    if (shouldThrowOnSave) {
      throw Exception('File saver platform error');
    }
    return saveResult;
  }
}

void main() {
  late _FakeRepository repository;
  late _FakeLeadExportFileSaver fileSaver;

  setUp(() {
    repository = _FakeRepository();
    fileSaver = _FakeLeadExportFileSaver();
  });

  Widget buildTestDialog({
    LeadQuery query = const LeadQuery(),
    String contextExplanation = 'All Leads will be exported.',
    LeadExportCubit? cubit,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showLeadExportDialog(
                context: context,
                repository: repository,
                fileSaver: fileSaver,
                query: query,
                contextExplanation: contextExplanation,
                cubit: cubit,
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );
  }

  group('LeadExportDialog Widget Tests', () {
    testWidgets(
      'renders dialog title, context explanation, and format selector with default Excel',
      (tester) async {
        await tester.pumpWidget(buildTestDialog());
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('lead_export_dialog')), findsOneWidget);
        expect(find.text('Export Leads'), findsOneWidget);
        expect(find.byIcon(Icons.download_outlined), findsOneWidget);
        expect(find.text('All Leads will be exported.'), findsOneWidget);

        expect(
          find.byKey(const Key('lead_export_format_excel')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('lead_export_format_csv')), findsOneWidget);
        expect(find.text('Excel (.xlsx)'), findsOneWidget);
        expect(find.text('CSV (.csv)'), findsOneWidget);

        final radioGroup = tester.widget<RadioGroup<LeadExportFormat>>(
          find.byType(RadioGroup<LeadExportFormat>),
        );
        expect(radioGroup.groupValue, LeadExportFormat.excel);

        expect(
          find.byKey(const Key('lead_export_dialog_cancel_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lead_export_dialog_submit_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets('switching format updates selected option to CSV', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestDialog());
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lead_export_format_csv')));
      await tester.pumpAndSettle();

      final radioGroup = tester.widget<RadioGroup<LeadExportFormat>>(
        find.byType(RadioGroup<LeadExportFormat>),
      );
      expect(radioGroup.groupValue, LeadExportFormat.csv);
    });

    testWidgets('Cancel button dismisses dialog without export', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestDialog());
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('lead_export_dialog_cancel_button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lead_export_dialog')), findsNothing);
      expect(repository.exportLeadsCallCount, 0);
      expect(fileSaver.saveCallCount, 0);
    });

    testWidgets(
      'Export button triggers export pipeline and success closes dialog',
      (tester) async {
        await tester.pumpWidget(
          buildTestDialog(query: const LeadQuery(searchText: 'Test Search')),
        );
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_export_format_csv')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_export_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(repository.exportLeadsCallCount, 1);
        expect(repository.lastExportRequest?.format, LeadExportFormat.csv);
        expect(repository.lastExportRequest?.query.searchText, 'Test Search');
        expect(fileSaver.saveCallCount, 1);

        // Dialog is dismissed on success
        expect(find.byKey(const Key('lead_export_dialog')), findsNothing);
      },
    );

    testWidgets(
      'busy exporting state disables controls and renders Generating...',
      (tester) async {
        repository.exportCompleter = Completer<LeadExportResult>();

        await tester.pumpWidget(buildTestDialog());
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_export_dialog_submit_button')),
        );
        await tester.pump();

        expect(find.text('Generating...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Cancel button disabled
        final cancelButton = tester.widget<TextButton>(
          find.byKey(const Key('lead_export_dialog_cancel_button')),
        );
        expect(cancelButton.onPressed, isNull);

        // Submit button disabled
        final submitButton = tester.widget<FilledButton>(
          find.byKey(const Key('lead_export_dialog_submit_button')),
        );
        expect(submitButton.onPressed, isNull);

        // Format tiles disabled
        final excelTile = tester.widget<RadioListTile<LeadExportFormat>>(
          find.byKey(const Key('lead_export_format_excel')),
        );
        expect(excelTile.enabled, isFalse);

        // Complete export
        repository.exportCompleter!.complete(repository.exportResult);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('lead_export_dialog')), findsNothing);
      },
    );

    testWidgets('busy saving state disables controls and renders Saving...', (
      tester,
    ) async {
      fileSaver.saveCompleter = Completer<LeadExportSaveResult>();

      await tester.pumpWidget(buildTestDialog());
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('lead_export_dialog_submit_button')),
      );
      await tester.pump();

      expect(find.text('Saving...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      fileSaver.saveCompleter!.complete(const LeadExportSaveResult.saved());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lead_export_dialog')), findsNothing);
    });

    testWidgets(
      'save cancellation leaves dialog open, retains format, no error banner, Export enabled',
      (tester) async {
        fileSaver.saveResult = const LeadExportSaveResult.cancelled();

        await tester.pumpWidget(buildTestDialog());
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_export_format_csv')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_export_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Dialog remains open
        expect(find.byKey(const Key('lead_export_dialog')), findsOneWidget);
        // No error banner
        expect(find.byKey(const Key('lead_export_dialog_error')), findsNothing);
        // Format retained as CSV
        final radioGroup = tester.widget<RadioGroup<LeadExportFormat>>(
          find.byType(RadioGroup<LeadExportFormat>),
        );
        expect(radioGroup.groupValue, LeadExportFormat.csv);

        // Submit button is active again
        final submitButton = tester.widget<FilledButton>(
          find.byKey(const Key('lead_export_dialog_submit_button')),
        );
        expect(submitButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'export failure displays safe error banner, retains format, enables retry',
      (tester) async {
        repository.shouldThrowOnExport = true;

        await tester.pumpWidget(buildTestDialog());
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_export_format_csv')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_export_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Dialog remains open
        expect(find.byKey(const Key('lead_export_dialog')), findsOneWidget);
        // Safe error banner visible
        expect(
          find.byKey(const Key('lead_export_dialog_error')),
          findsOneWidget,
        );
        expect(find.text('Unable to export Leads.'), findsOneWidget);
        // Format retained
        final radioGroup = tester.widget<RadioGroup<LeadExportFormat>>(
          find.byType(RadioGroup<LeadExportFormat>),
        );
        expect(radioGroup.groupValue, LeadExportFormat.csv);

        // Retry: fix repository error and submit again
        repository.shouldThrowOnExport = false;
        await tester.tap(
          find.byKey(const Key('lead_export_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(repository.exportLeadsCallCount, 2);
        expect(find.byKey(const Key('lead_export_dialog')), findsNothing);
      },
    );

    testWidgets(
      'responsive layout renders cleanly across 320x568, 360x640, 768x1024, 1200x800',
      (tester) async {
        const viewports = [
          Size(320, 568),
          Size(360, 640),
          Size(768, 1024),
          Size(1200, 800),
        ];

        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            buildTestDialog(
              contextExplanation:
                  'All Leads matching the current search and filters will be exported across all pages.',
            ),
          );
          await tester.tap(find.text('Open Dialog'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('lead_export_dialog')), findsOneWidget);

          // Dismiss dialog for next iteration
          await tester.tap(
            find.byKey(const Key('lead_export_dialog_cancel_button')),
          );
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets('dark theme renders cleanly without exception', (tester) async {
      await tester.pumpWidget(buildTestDialog(themeMode: ThemeMode.dark));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('lead_export_dialog')), findsOneWidget);
      expect(find.text('Export Leads'), findsOneWidget);
    });
  });
}
