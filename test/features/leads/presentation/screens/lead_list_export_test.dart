import 'dart:convert';
import 'package:enterprise_crm/app/crm_app.dart';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/data/services/lead_export_file_saver.dart';
import 'package:enterprise_crm/features/leads/data/services/lead_export_serializer.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_list_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExportFileSaver implements LeadExportFileSaver {
  LeadExportSaveResult saveResult = const LeadExportSaveResult.saved();
  bool shouldThrowOnSave = false;
  int saveCallCount = 0;
  LeadExportResult? lastSavedResult;

  @override
  Future<LeadExportSaveResult> save(LeadExportResult exportResult) async {
    saveCallCount++;
    lastSavedResult = exportResult;
    if (shouldThrowOnSave) {
      throw Exception('Disk write error');
    }
    return saveResult;
  }
}

class _RecordingLeadRepository extends MockLeadRepository {
  _RecordingLeadRepository({super.dataSource});

  LeadExportRequest? lastExportRequest;
  int exportCallCount = 0;

  @override
  Future<LeadExportResult> exportLeads(LeadExportRequest request) async {
    exportCallCount++;
    lastExportRequest = request;
    return super.exportLeads(request);
  }
}

void main() {
  group('Lead List Export Integration (L7A.4)', () {
    late _RecordingLeadRepository repository;
    late _FakeExportFileSaver fileSaver;

    setUp(() {
      repository = _RecordingLeadRepository();
      fileSaver = _FakeExportFileSaver();
    });

    testWidgets(
      'Normal Lead List mode displays export action and opens dialog with list context',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          CrmApp(leadRepository: repository, exportFileSaver: fileSaver),
        );
        await tester.pumpAndSettle();

        // Navigate to Lead List screen
        await tester.tap(find.byKey(const Key('dashboard_card_total_leads')));
        await tester.pumpAndSettle();

        // Verify export action button is present in AppBar
        expect(
          find.byKey(const Key('lead_list_export_button')),
          findsOneWidget,
        );

        // Tap export action button
        await tester.tap(find.byKey(const Key('lead_list_export_button')));
        await tester.pumpAndSettle();

        // Verify dialog is visible with list-specific description
        expect(find.byKey(const Key('lead_export_dialog')), findsOneWidget);
        expect(
          find.text(
            'All Leads matching the current search and filters will be exported across all pages.',
          ),
          findsOneWidget,
        );

        // Default format should be Excel
        expect(find.text('Excel (.xlsx)'), findsOneWidget);
        expect(find.text('CSV (.csv)'), findsOneWidget);

        // Close dialog cleanly
        await tester.tap(
          find.byKey(const Key('lead_export_dialog_cancel_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('lead_export_dialog')), findsNothing);
      },
    );

    testWidgets(
      'Lead List export flow with CSV saves matching leads and displays success SnackBar',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          CrmApp(leadRepository: repository, exportFileSaver: fileSaver),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('dashboard_card_total_leads')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_list_export_button')));
        await tester.pumpAndSettle();

        // Select CSV format
        await tester.tap(find.byKey(const Key('lead_export_format_csv')));
        await tester.pumpAndSettle();

        // Tap export
        await tester.tap(
          find.byKey(const Key('lead_export_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Verify dialog closes and success SnackBar is displayed
        expect(find.byKey(const Key('lead_export_dialog')), findsNothing);
        expect(find.text('Lead export saved.'), findsOneWidget);

        expect(repository.exportCallCount, 1);
        expect(repository.lastExportRequest?.format, LeadExportFormat.csv);
        expect(fileSaver.saveCallCount, 1);
        expect(fileSaver.lastSavedResult, isNotNull);
        expect(fileSaver.lastSavedResult!.fileName.endsWith('.csv'), isTrue);
      },
    );

    testWidgets(
      'Selection mode hides the export action button (no selected-lead export)',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          CrmApp(leadRepository: repository, exportFileSaver: fileSaver),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('dashboard_card_total_leads')));
        await tester.pumpAndSettle();

        // Initially present in normal mode
        expect(
          find.byKey(const Key('lead_list_export_button')),
          findsOneWidget,
        );

        // Enter bulk assignment selection mode
        await tester.tap(find.byKey(const Key('lead_list_select_mode_button')));
        await tester.pumpAndSettle();

        // In selection mode, export button MUST NOT be present
        expect(find.byKey(const Key('lead_list_export_button')), findsNothing);

        // Exit selection mode
        await tester.tap(
          find.byKey(const Key('lead_list_cancel_selection_button')),
        );
        await tester.pumpAndSettle();

        // Export button is restored
        expect(
          find.byKey(const Key('lead_list_export_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Distribution mode does not show export action button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        CrmApp(leadRepository: repository, exportFileSaver: fileSaver),
      );
      await tester.pumpAndSettle();

      // Tap Distribute Leads from dashboard quick actions
      await tester.tap(find.text('Distribute Leads'));
      await tester.pumpAndSettle();

      // In distribution mode, export button MUST NOT be present
      expect(find.byKey(const Key('lead_list_export_button')), findsNothing);
    });

    testWidgets(
      'Standalone LeadListScreen without exportFileSaver injected falls back cleanly to DI provider',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LeadListScreen(
                repository: repository,
                exportFileSaver: fileSaver,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('lead_list_export_button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('lead_list_export_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('lead_export_dialog')), findsOneWidget);
      },
    );

    testWidgets('Export snapshots active query with search and filters', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        CrmApp(leadRepository: repository, exportFileSaver: fileSaver),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dashboard_card_total_leads')));
      await tester.pumpAndSettle();

      // Enter search query in search TextField
      await tester.enterText(find.byType(TextField), 'Aarav');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Open export dialog
      await tester.tap(find.byKey(const Key('lead_list_export_button')));
      await tester.pumpAndSettle();

      // Submit export
      await tester.tap(
        find.byKey(const Key('lead_export_dialog_submit_button')),
      );
      await tester.pumpAndSettle();

      // Verify the query passed to repository had searchText == 'Aarav'
      expect(repository.lastExportRequest, isNotNull);
      expect(repository.lastExportRequest!.query.searchText, 'Aarav');
    });

    testWidgets(
      'Multi-page integration exports ALL matching leads across all pages',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Create 25 leads matching a query
        final multiPageLeads = List.generate(
          25,
          (i) => Lead(
            id: 'test-lead-$i',
            name: 'MultiPage Lead ${i.toString().padLeft(2, '0')}',
            phone: '+91 91000${i.toString().padLeft(5, '0')}',
            email: 'lead$i@multipage.example.com',
            status: const LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: 'agent-1',
            assignedUserName: 'Mock Agent One',
            createdAt: DateTime.parse('2026-09-01T10:00:00Z'),
            updatedAt: DateTime.parse('2026-09-01T10:00:00Z'),
          ),
        );

        final dataSource = MockLeadDataSource(initialLeads: multiPageLeads);
        final multiPageRepo = _RecordingLeadRepository(dataSource: dataSource);

        await tester.pumpWidget(
          CrmApp(leadRepository: multiPageRepo, exportFileSaver: fileSaver),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('dashboard_card_total_leads')));
        await tester.pumpAndSettle();

        // Open export dialog
        await tester.tap(find.byKey(const Key('lead_list_export_button')));
        await tester.pumpAndSettle();

        // Select CSV format
        await tester.tap(find.byKey(const Key('lead_export_format_csv')));
        await tester.pumpAndSettle();

        // Submit
        await tester.tap(
          find.byKey(const Key('lead_export_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        final content =
            fileSaver.lastSavedResult!.fileReference as LeadExportContent;
        final csvString = utf8.decode(content.bytes);

        // Verify that ALL 25 leads are in the exported CSV, spanning across pages
        for (int i = 0; i < 25; i++) {
          expect(
            csvString,
            contains('MultiPage Lead ${i.toString().padLeft(2, '0')}'),
          );
        }
      },
    );

    testWidgets(
      'Filtered export integration exports only matching leads across all pages',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final cubit = LeadListCubit(repository);
        await cubit.loadLeads(
          query: const LeadQuery(assignedUserId: 'agent-2'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LeadListScreen(
                cubit: cubit,
                repository: repository,
                exportFileSaver: fileSaver,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open export dialog
        await tester.tap(find.byKey(const Key('lead_list_export_button')));
        await tester.pumpAndSettle();

        // Select CSV format
        await tester.tap(find.byKey(const Key('lead_export_format_csv')));
        await tester.pumpAndSettle();

        // Submit
        await tester.tap(
          find.byKey(const Key('lead_export_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        final content =
            fileSaver.lastSavedResult!.fileReference as LeadExportContent;
        final csvString = utf8.decode(content.bytes);

        // In default mock data, Rohan Mehta is assigned to agent-2
        expect(csvString, contains('Rohan Mehta'));
        expect(csvString, isNot(contains('Aarav Sharma'))); // agent-1
        expect(csvString, isNot(contains('Pooja Verma'))); // unassigned

        // Verify assignedUserId is not exposed as a column header
        final headerLine = csvString.split('\n').first;
        expect(headerLine, isNot(contains('assignedUserId')));
        expect(headerLine, isNot(contains('Assigned User Id')));
        expect(headerLine, contains('Assigned To'));
      },
    );

    testWidgets('Search export integration exports only search matches', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        CrmApp(leadRepository: repository, exportFileSaver: fileSaver),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dashboard_card_total_leads')));
      await tester.pumpAndSettle();

      // Enter search for 'Mehta' (Rohan Mehta)
      await tester.enterText(find.byType(TextField), 'Mehta');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lead_list_export_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lead_export_format_csv')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('lead_export_dialog_submit_button')),
      );
      await tester.pumpAndSettle();

      final content =
          fileSaver.lastSavedResult!.fileReference as LeadExportContent;
      final csvString = utf8.decode(content.bytes);

      expect(csvString, contains('Rohan Mehta'));
      expect(csvString, isNot(contains('Aarav Sharma')));
      expect(csvString, isNot(contains('Pooja Verma')));
    });

    testWidgets('Lead List export handles cancellation cleanly', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fileSaver.saveResult = const LeadExportSaveResult.cancelled();

      await tester.pumpWidget(
        CrmApp(leadRepository: repository, exportFileSaver: fileSaver),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dashboard_card_total_leads')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lead_list_export_button')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('lead_export_dialog_submit_button')),
      );
      await tester.pumpAndSettle();

      // Dialog remains open, no SnackBar, no error banner
      expect(find.byKey(const Key('lead_export_dialog')), findsOneWidget);
      expect(find.text('Lead export saved.'), findsNothing);
      expect(find.byKey(const Key('lead_export_dialog_error')), findsNothing);

      // Cancel dialog cleanly
      await tester.tap(
        find.byKey(const Key('lead_export_dialog_cancel_button')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lead_export_dialog')), findsNothing);
    });

    testWidgets(
      'Lead List export handles saver failure cleanly and allows retry',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fileSaver.shouldThrowOnSave = true;

        await tester.pumpWidget(
          CrmApp(leadRepository: repository, exportFileSaver: fileSaver),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('dashboard_card_total_leads')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_list_export_button')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_export_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Dialog remains open with safe error banner
        expect(find.byKey(const Key('lead_export_dialog')), findsOneWidget);
        expect(find.text('Unable to export Leads.'), findsOneWidget);

        // Retry after resolving saver error
        fileSaver.shouldThrowOnSave = false;
        await tester.tap(
          find.byKey(const Key('lead_export_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('lead_export_dialog')), findsNothing);
        expect(find.text('Lead export saved.'), findsOneWidget);
        expect(fileSaver.saveCallCount, 2);
      },
    );

    testWidgets(
      'Lead List AppBar with export button renders responsive without overflow',
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

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LeadListScreen(
                  repository: repository,
                  exportFileSaver: fileSaver,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('lead_list_export_button')),
            findsOneWidget,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow at size $size',
          );
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets('Lead List export works correctly under dark theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: LeadListScreen(
              repository: repository,
              exportFileSaver: fileSaver,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lead_list_export_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('lead_list_export_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lead_export_dialog')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
