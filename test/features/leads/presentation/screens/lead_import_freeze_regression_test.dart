import 'dart:typed_data';

import 'package:enterprise_crm/app/crm_app.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_selected_file.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_dashboard_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_import_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_import_workflow_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_list_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/services/lead_import_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TrackingFakeFilePicker implements LeadImportFilePicker {
  int pickCallCount = 0;
  LeadImportSelectedFile? fileToReturn;

  @override
  Future<LeadImportSelectedFile?> pickFile() async {
    pickCallCount++;
    return fileToReturn;
  }
}

class _TrackingMockLeadRepository extends MockLeadRepository {
  int importCallCount = 0;

  @override
  Future<LeadImportResult> importLeads(LeadImportRequest request) async {
    importCallCount++;
    return super.importLeads(request);
  }
}

void main() {
  group('Lead Import Freeze & Regression (FIX 1)', () {
    late _TrackingMockLeadRepository repository;
    late _TrackingFakeFilePicker filePicker;

    setUp(() {
      repository = _TrackingMockLeadRepository();
      filePicker = _TrackingFakeFilePicker();
    });

    testWidgets(
      'Dashboard -> tap Import Leads -> opens cleanly, settles normally, no hang, Back returns to Dashboard',
      (tester) async {
        await tester.pumpWidget(
          CrmApp(leadRepository: repository, filePicker: filePicker),
        );
        await tester.pumpAndSettle();

        // 1. Verify on Dashboard
        expect(find.byType(LeadDashboardScreen), findsOneWidget);
        expect(find.byType(LeadImportWorkflowScreen), findsNothing);

        // 2. Tap Import Leads
        final importAction = find.text('Import Leads');
        expect(importAction, findsWidgets);
        await tester.tap(importAction.first);
        await tester.pumpAndSettle();

        // 3. Workflow screen opened and settled normally
        expect(find.byType(LeadImportWorkflowScreen), findsOneWidget);
        expect(find.byType(LeadImportScreen), findsOneWidget);
        expect(find.text('Upload file'), findsOneWidget);
        expect(find.text('CSV or Excel (.xlsx)'), findsOneWidget);

        // 4. Interactive and no unintended repo calls
        expect(
          find.byKey(const Key('lead_import_choose_file_button')),
          findsOneWidget,
        );
        expect(repository.importCallCount, 0);

        // 5. Back navigation pops route without infinite recursive loop / freeze
        final backButton = find.byKey(const Key('lead_import_back_button'));
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // 6. Back on Dashboard cleanly
        expect(find.byType(LeadImportWorkflowScreen), findsNothing);
        expect(find.byType(LeadDashboardScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Lead List -> tap Import Leads -> opens cleanly, interactive, Back returns to Lead List',
      (tester) async {
        await tester.pumpWidget(
          CrmApp(leadRepository: repository, filePicker: filePicker),
        );
        await tester.pumpAndSettle();

        // Open Lead List
        await tester.tap(find.text('View Leads'));
        await tester.pumpAndSettle();
        expect(find.byType(LeadListScreen), findsOneWidget);

        // Tap Import Leads AppBar icon
        final listImportButton = find.byKey(
          const Key('lead_list_import_button'),
        );
        expect(listImportButton, findsOneWidget);
        await tester.tap(listImportButton);
        await tester.pumpAndSettle();

        // Import screen is open
        expect(find.byType(LeadImportWorkflowScreen), findsOneWidget);
        expect(
          find.byKey(const Key('lead_import_choose_file_button')),
          findsOneWidget,
        );

        // Tap Back
        await tester.tap(find.byKey(const Key('lead_import_back_button')));
        await tester.pumpAndSettle();

        // Returns to Lead List
        expect(find.byType(LeadImportWorkflowScreen), findsNothing);
        expect(find.byType(LeadListScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Select File starts existing file picker workflow and updates UI when file is picked',
      (tester) async {
        filePicker.fileToReturn = LeadImportSelectedFile(
          name: 'test_leads.csv',
          extension: 'csv',
          sizeBytes: 1024,
          source: LeadSource.csv,
          content: InMemoryLeadImportFileContent(
            Uint8List.fromList('Name,Email\nBob,b@b.com'.codeUnits),
          ),
        );

        await tester.pumpWidget(
          CrmApp(leadRepository: repository, filePicker: filePicker),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Import Leads').first);
        await tester.pumpAndSettle();

        // Tap Choose File
        final chooseFileButton = find.byKey(
          const Key('lead_import_choose_file_button'),
        );
        await tester.tap(chooseFileButton);
        await tester.pumpAndSettle();

        expect(filePicker.pickCallCount, 1);
        expect(find.text('test_leads.csv'), findsOneWidget);
        expect(
          find.byKey(const Key('lead_import_continue_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'LeadImportWorkflowScreen direct standalone mount: no infinite loop, no endless loading, settles immediately',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: LeadImportWorkflowScreen(
              repository: repository,
              filePicker: filePicker,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LeadImportWorkflowScreen), findsOneWidget);
        expect(find.byType(LeadImportScreen), findsOneWidget);
        expect(repository.importCallCount, 0);
      },
    );
  });
}
