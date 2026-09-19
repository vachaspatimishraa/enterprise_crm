import 'dart:convert';

import 'package:enterprise_crm/app/crm_app.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/data/services/lead_export_file_saver.dart';
import 'package:enterprise_crm/features/leads/data/services/lead_export_serializer.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadExportFileSaver implements LeadExportFileSaver {
  LeadExportResult? lastSavedResult;
  int saveCallCount = 0;
  bool shouldThrowOnSave = false;
  LeadExportSaveResult saveResult = const LeadExportSaveResult.saved();

  @override
  Future<LeadExportSaveResult> save(LeadExportResult result) async {
    saveCallCount++;
    lastSavedResult = result;
    if (shouldThrowOnSave) {
      throw Exception('File save error');
    }
    return saveResult;
  }
}

void main() {
  group('Lead Dashboard Export Integration (L7A.4)', () {
    late MockLeadRepository repository;
    late _FakeLeadExportFileSaver fileSaver;

    setUp(() {
      repository = MockLeadRepository();
      fileSaver = _FakeLeadExportFileSaver();
    });

    testWidgets(
      'Dashboard Export Leads opens real dialog without Coming Soon',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          CrmApp(leadRepository: repository, exportFileSaver: fileSaver),
        );
        await tester.pumpAndSettle();

        // Tap 'Export Leads' quick action
        await tester.tap(find.text('Export Leads'));
        await tester.pumpAndSettle();

        // Verify real dialog is open
        expect(find.byKey(const Key('lead_export_dialog')), findsOneWidget);
        expect(find.text('Export Leads'), findsWidgets);
        expect(find.text('All Leads will be exported.'), findsOneWidget);

        // Verify "Coming Soon" does NOT appear
        expect(
          find.text('Export Leads will be connected in upcoming phases.'),
          findsNothing,
        );

        // Default format is Excel
        expect(find.text('Excel (.xlsx)'), findsOneWidget);
        expect(find.text('CSV (.csv)'), findsOneWidget);
      },
    );

    testWidgets(
      'Dashboard export flow with CSV saves all leads and displays success SnackBar',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          CrmApp(leadRepository: repository, exportFileSaver: fileSaver),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Export Leads'));
        await tester.pumpAndSettle();

        // Switch to CSV
        await tester.tap(find.byKey(const Key('lead_export_format_csv')));
        await tester.pumpAndSettle();

        // Submit export
        await tester.tap(
          find.byKey(const Key('lead_export_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Dialog is dismissed
        expect(find.byKey(const Key('lead_export_dialog')), findsNothing);

        // Verify SnackBar shown
        expect(find.text('Lead export saved.'), findsOneWidget);

        // Verify saver was called with CSV content
        expect(fileSaver.saveCallCount, 1);
        final savedResult = fileSaver.lastSavedResult!;
        expect(savedResult.fileName, 'leads_export.csv');
        final content = savedResult.fileReference as LeadExportContent;
        expect(content.extension, 'csv');
        expect(content.mimeType, 'text/csv');

        // Decode CSV and verify headers and initial leads exist
        final csvString = utf8.decode(content.bytes);
        expect(
          csvString,
          contains(
            'Name,Phone,Email,Status,Source,Assigned To,Created At,Updated At',
          ),
        );
        expect(csvString, contains('Aarav Sharma'));
        expect(csvString, contains('Pooja Verma'));
      },
    );

    testWidgets(
      'Dashboard standalone without onExportLeads falls back to opening dialog when repo is available',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LeadDashboardScreen(
                repository: repository,
                fileSaver: fileSaver,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Export Leads'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('lead_export_dialog')), findsOneWidget);
        expect(find.text('All Leads will be exported.'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('lead_export_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('lead_export_dialog')), findsNothing);
        expect(find.text('Lead export saved.'), findsOneWidget);
        expect(fileSaver.saveCallCount, 1);
      },
    );

    testWidgets(
      'Dashboard export reflects current repository mutations (created and reassigned leads)',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Add a new lead to repository
        await repository.createLead(
          CreateLeadInput(
            draft: const LeadDraft(
              name: 'Delta Corporate Partner',
              phone: '+91 9998887777',
              email: 'delta@corp.example.com',
              source: LeadSource.manual,
              status: LeadStatus('New'),
            ),
          ),
        );

        // Reassign an existing lead (e.g. Alice Johnson / lead-1 assigned to agent-2)
        await repository.reassignLead(
          const LeadReassignmentRequest(
            leadId: 'lead-1',
            newAssigneeId: 'agent-2',
            reason: 'Workload balancing',
          ),
        );

        await tester.pumpWidget(
          CrmApp(leadRepository: repository, exportFileSaver: fileSaver),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Export Leads'));
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

        // Verify newly created lead is present
        expect(csvString, contains('Delta Corporate Partner'));
        expect(csvString, contains('+91 9998887777'));
        expect(csvString, contains('delta@corp.example.com'));

        // Verify reassigned lead displays current assignee (Mock Agent Two / agent-2)
        // and does NOT leak reason or history fields
        expect(csvString, contains('Aarav Sharma'));
        expect(csvString, contains('Mock Agent Two'));
        expect(csvString, isNot(contains('Workload balancing')));
      },
    );

    testWidgets('Dashboard export handles user cancellation cleanly', (
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

      await tester.tap(find.text('Export Leads'));
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
      'Dashboard export handles saver failure cleanly and allows retry',
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

        await tester.tap(find.text('Export Leads'));
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
  });
}
