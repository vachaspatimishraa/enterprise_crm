import 'dart:async';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignee.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_summary.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_form_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/edit_lead_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadRepository implements LeadRepository {
  UpdateLeadInput? lastUpdateInput;
  int updateLeadCallCount = 0;
  Completer<Lead>? updateCompleter;
  bool shouldThrowOnUpdate = false;

  @override
  Future<Lead> updateLead(UpdateLeadInput input) async {
    lastUpdateInput = input;
    updateLeadCallCount++;
    if (updateCompleter != null) return updateCompleter!.future;
    if (shouldThrowOnUpdate) throw Exception('Update failed on server');
    return Lead(
      id: input.leadId,
      name: input.draft.name,
      phone: input.draft.phone,
      email: input.draft.email,
      status: input.draft.status,
      source: input.draft.source ?? LeadSource.manual,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<Lead> createLead(CreateLeadInput input) async =>
      const Lead(id: 'dummy');

  @override
  Future<Lead?> getLeadById(String leadId) async => null;

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
      const LeadImportResult(
        totalRows: 0,
        importedRows: 0,
        skippedRows: 0,
        failedRows: 0,
        duplicateRows: 0,
      );

  @override
  Future<LeadExportResult> exportLeads(LeadExportRequest request) async =>
      const LeadExportResult(fileReference: '', fileName: '');

  @override
  Future<LeadSummary> getLeadSummary() async => const LeadSummary(
    totalLeads: 0,
    assignedLeads: 0,
    unassignedLeads: 0,
    manualLeads: 0,
    excelLeads: 0,
    csvLeads: 0,
  );
}

void main() {
  late _FakeLeadRepository repository;

  setUp(() {
    repository = _FakeLeadRepository();
  });

  Widget buildTestWidget({
    required Lead lead,
    LeadFormCubit? cubit,
    void Function(Lead lead)? onLeadUpdated,
    VoidCallback? onCancel,
    Size size = const Size(800, 600),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: EditLeadScreen(
            lead: lead,
            cubit: cubit,
            repository: cubit == null ? repository : null,
            onLeadUpdated: onLeadUpdated,
            onCancel: onCancel,
          ),
        ),
      ),
    );
  }

  group('EditLeadScreen - Initial Values & Context', () {
    testWidgets('populates existing Lead values into form controllers', (
      tester,
    ) async {
      const existing = Lead(
        id: 'crm-lead-101',
        name: 'Aarav Sharma',
        phone: '+91 9876543210',
        email: 'aarav.sharma@example.com',
        source: LeadSource.manual,
        status: LeadStatus('Negotiation'),
        assignedUserId: 'agent-1',
        assignedUserName: 'Sarah Connor',
      );

      await tester.pumpWidget(buildTestWidget(lead: existing));
      await tester.pumpAndSettle();

      expect(find.text('Edit Lead'), findsOneWidget);
      expect(find.text('ID: crm-lead-101'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Status: Negotiation'), findsOneWidget);
      expect(find.text('Assigned: Sarah Connor'), findsOneWidget);

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('+91 9876543210'), findsOneWidget);
      expect(find.text('aarav.sharma@example.com'), findsOneWidget);
    });

    testWidgets(
      'handles nullable fields safely with empty inputs and no literal null',
      (tester) async {
        const minimalLead = Lead(
          id: 'crm-lead-102',
          name: null,
          phone: null,
          email: null,
          source: LeadSource.excel,
          status: null,
          assignedUserId: null,
          assignedUserName: null,
        );

        await tester.pumpWidget(buildTestWidget(lead: minimalLead));
        await tester.pumpAndSettle();

        expect(find.text('null'), findsNothing);
        expect(find.text('ID: crm-lead-102'), findsOneWidget);
        expect(find.text('Excel'), findsOneWidget);
        expect(find.text('Status: —'), findsOneWidget);
        expect(find.text('Assigned: Unassigned'), findsOneWidget);

        final nameField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Lead Name'),
        );
        expect(nameField.controller?.text, isEmpty);
      },
    );
  });

  group('EditLeadScreen - Dirty State & No Changes', () {
    testWidgets(
      'Save Changes button is disabled when form has not been modified',
      (tester) async {
        const existing = Lead(
          id: 'crm-lead-103',
          name: 'Pooja Hegde',
          phone: '+91 9123456780',
          email: 'pooja@example.com',
          source: LeadSource.csv,
        );

        await tester.pumpWidget(buildTestWidget(lead: existing));
        await tester.pumpAndSettle();

        // Find FilledButton
        final saveButtonFinder = find.widgetWithText(
          FilledButton,
          'Save Changes',
        );
        expect(saveButtonFinder, findsOneWidget);

        final saveButton = tester.widget<FilledButton>(saveButtonFinder);
        expect(saveButton.onPressed, isNull);

        // Tap on disabled button should not call updateLead
        await tester.tap(saveButtonFinder);
        await tester.pumpAndSettle();
        expect(repository.updateLeadCallCount, 0);
      },
    );

    testWidgets('Save Changes button enables as soon as a field changes', (
      tester,
    ) async {
      const existing = Lead(
        id: 'crm-lead-104',
        name: 'Original Name',
        phone: '+91 9000000001',
        email: 'original@example.com',
        source: LeadSource.manual,
      );

      await tester.pumpWidget(buildTestWidget(lead: existing));
      await tester.pumpAndSettle();

      var saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save Changes'),
      );
      expect(saveButton.onPressed, isNull);

      // Edit name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Lead Name'),
        'Modified Name',
      );
      await tester.pump();

      saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save Changes'),
      );
      expect(saveButton.onPressed, isNotNull);

      // Revert name back to original
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Lead Name'),
        'Original Name',
      );
      await tester.pump();

      saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save Changes'),
      );
      expect(saveButton.onPressed, isNull);
    });
  });

  group('EditLeadScreen - Editing & Preserving Read-Only Fields', () {
    testWidgets(
      'submits modified fields and preserves original source and status',
      (tester) async {
        const original = Lead(
          id: 'crm-lead-105',
          name: 'Rohan Joshi',
          phone: '+91 9888877777',
          email: 'rohan@example.com',
          source: LeadSource.csv,
          status: LeadStatus('Discovery Call'),
          assignedUserId: 'agent-5',
          assignedUserName: 'Agent Five',
        );

        Lead? updatedResult;
        await tester.pumpWidget(
          buildTestWidget(
            lead: original,
            onLeadUpdated: (lead) => updatedResult = lead,
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Phone'),
          '+91 9999911111',
        );
        await tester.pump();

        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        expect(repository.updateLeadCallCount, 1);
        final updateInput = repository.lastUpdateInput!;
        expect(updateInput.leadId, 'crm-lead-105');
        expect(updateInput.draft.name, 'Rohan Joshi');
        expect(updateInput.draft.phone, '+91 9999911111');
        expect(updateInput.draft.email, 'rohan@example.com');
        // Preserved fields:
        expect(updateInput.draft.source, LeadSource.csv);
        expect(updateInput.draft.status, const LeadStatus('Discovery Call'));

        expect(updatedResult, isNotNull);
        expect(updatedResult!.id, 'crm-lead-105');
        expect(updatedResult!.phone, '+91 9999911111');
        expect(updatedResult!.source, LeadSource.csv);
      },
    );

    testWidgets('validates email format when invalid email is entered', (
      tester,
    ) async {
      const original = Lead(
        id: 'crm-lead-106',
        name: 'Test Lead',
        email: 'valid@example.com',
      );

      await tester.pumpWidget(buildTestWidget(lead: original));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'invalid-email-no-at',
      );
      await tester.pump();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(repository.updateLeadCallCount, 0);
    });
  });

  group('EditLeadScreen - Submission State & Duplicate Protection', () {
    testWidgets(
      'shows loading state and prevents duplicate submissions while saving',
      (tester) async {
        repository.updateCompleter = Completer<Lead>();
        final cubit = LeadFormCubit(repository);

        const original = Lead(
          id: 'crm-lead-107',
          name: 'Kavita Roy',
          source: LeadSource.manual,
        );

        await tester.pumpWidget(buildTestWidget(lead: original, cubit: cubit));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Lead Name'),
          'Kavita Roy Choudhury',
        );
        await tester.pump();

        // Trigger save
        await tester.tap(find.text('Save Changes'));
        await tester.pump(); // Enter submitting state

        expect(find.text('Saving...'), findsOneWidget);
        expect(repository.updateLeadCallCount, 1);

        // Attempt second tap during submission
        await tester.tap(find.text('Saving...'));
        await tester.pump();
        expect(repository.updateLeadCallCount, 1);

        // Complete async update
        repository.updateCompleter!.complete(
          const Lead(
            id: 'crm-lead-107',
            name: 'Kavita Roy Choudhury',
            source: LeadSource.manual,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lead updated successfully'), findsOneWidget);
      },
    );
  });

  group('EditLeadScreen - Failure State', () {
    testWidgets(
      'displays failure feedback, preserves edited values, allows retry',
      (tester) async {
        repository.shouldThrowOnUpdate = true;

        const original = Lead(
          id: 'crm-lead-108',
          name: 'Initial Name',
          phone: '+91 9000000000',
        );

        await tester.pumpWidget(buildTestWidget(lead: original));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Lead Name'),
          'Updated Failing Name',
        );
        await tester.pump();

        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        expect(find.text('Update failed on server'), findsWidgets);
        expect(find.text('Updated Failing Name'), findsOneWidget);

        // Retry after resolving failure
        repository.shouldThrowOnUpdate = false;
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        expect(repository.updateLeadCallCount, 2);
        expect(find.text('Lead updated successfully'), findsOneWidget);
      },
    );
  });

  group('EditLeadScreen - Cancel / Back Actions', () {
    testWidgets('invokes onCancel callback when Cancel is tapped', (
      tester,
    ) async {
      bool cancelCalled = false;
      const lead = Lead(id: 'crm-lead-109', name: 'Lead 109');

      await tester.pumpWidget(
        buildTestWidget(lead: lead, onCancel: () => cancelCalled = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(cancelCalled, isTrue);
    });

    testWidgets('invokes onCancel callback when AppBar back button is tapped', (
      tester,
    ) async {
      bool cancelCalled = false;
      const lead = Lead(id: 'crm-lead-110', name: 'Lead 110');

      await tester.pumpWidget(
        buildTestWidget(lead: lead, onCancel: () => cancelCalled = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(cancelCalled, isTrue);
    });
  });

  group('EditLeadScreen - Responsive Layout', () {
    testWidgets(
      'mobile layout (360x640) renders without overflow with long values',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const longLead = Lead(
          id: 'crm-lead-very-long-id-1234567890',
          name: 'A Very Long Enterprise Lead Name For Mobile Testing Purposes',
          phone: '+91 9876543210-extension-4567',
          email:
              'very.long.enterprise.email.address@multinational-firm.example.com',
          source: LeadSource.manual,
          status: LeadStatus('Long Enterprise Negotiation Pipeline Status'),
          assignedUserName: 'Senior Regional Enterprise Sales Executive',
        );

        await tester.pumpWidget(
          buildTestWidget(lead: longLead, size: const Size(360, 640)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Edit Lead'), findsOneWidget);
        expect(find.text('Basic Information'), findsOneWidget);
        expect(find.text('Contact Information'), findsOneWidget);
        expect(find.text('Save Changes'), findsOneWidget);
      },
    );

    testWidgets('desktop layout (1200x800) renders centered wide layout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const desktopLead = Lead(
        id: 'crm-lead-desktop',
        name: 'Desktop Test Lead',
        source: LeadSource.excel,
      );

      await tester.pumpWidget(
        buildTestWidget(lead: desktopLead, size: const Size(1200, 800)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Lead'), findsOneWidget);
      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.text('Contact Information'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });
  });
}
