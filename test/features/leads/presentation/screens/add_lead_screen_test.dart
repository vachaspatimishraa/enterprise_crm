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
import 'package:enterprise_crm/features/leads/domain/entities/lead_summary.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_form_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/add_lead_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadRepository implements LeadRepository {
  CreateLeadInput? lastCreateInput;
  int createLeadCallCount = 0;
  Completer<Lead>? createCompleter;
  bool shouldThrowOnCreate = false;

  @override
  Future<Lead> createLead(CreateLeadInput input) async {
    lastCreateInput = input;
    createLeadCallCount++;
    if (createCompleter != null) return createCompleter!.future;
    if (shouldThrowOnCreate) throw Exception('Creation failed on server');
    return Lead(
      id: 'created-lead-123',
      name: input.draft.name,
      phone: input.draft.phone,
      email: input.draft.email,
      status: input.draft.status,
      source: input.draft.source ?? LeadSource.manual,
    );
  }

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
  Future<Lead> updateLead(UpdateLeadInput input) async =>
      const Lead(id: 'dummy');

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
    LeadFormCubit? cubit,
    void Function(Lead lead)? onLeadCreated,
    VoidCallback? onCancel,
    Size size = const Size(800, 600),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: AddLeadScreen(
            cubit: cubit,
            repository: cubit == null ? repository : null,
            onLeadCreated: onLeadCreated,
            onCancel: onCancel,
          ),
        ),
      ),
    );
  }

  group('AddLeadScreen - Rendering', () {
    testWidgets('renders all supported fields and initial controls', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Add Lead'), findsOneWidget);
      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.text('Lead Name'), findsOneWidget);
      expect(find.text('Contact Information'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create Lead'), findsOneWidget);
    });
  });

  group('AddLeadScreen - Optional Fields', () {
    testWidgets(
      'allows submitting without requiring fields, no mandatory errors shown',
      (tester) async {
        Lead? createdResult;
        await tester.pumpWidget(
          buildTestWidget(onLeadCreated: (lead) => createdResult = lead),
        );
        await tester.pumpAndSettle();

        // Tap Create Lead without typing anything
        await tester.tap(find.text('Create Lead'));
        await tester.pumpAndSettle();

        // No form validation errors
        expect(find.text('Please enter'), findsNothing);
        expect(find.text('Required'), findsNothing);

        // createLead was called
        expect(repository.createLeadCallCount, 1);
        expect(repository.lastCreateInput, isNotNull);
        expect(repository.lastCreateInput!.draft.name, isNull);
        expect(repository.lastCreateInput!.draft.phone, isNull);
        expect(repository.lastCreateInput!.draft.email, isNull);
        expect(
          repository.lastCreateInput!.draft.source,
          equals(LeadSource.manual),
        );
        expect(createdResult, isNotNull);
      },
    );

    testWidgets('validates email format only when email is provided', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Enter invalid email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'invalid-email-string',
      );
      await tester.tap(find.text('Create Lead'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(repository.createLeadCallCount, 0);

      // Correct email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'valid@example.com',
      );
      await tester.tap(find.text('Create Lead'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsNothing);
      expect(repository.createLeadCallCount, 1);
    });
  });

  group('AddLeadScreen - Data Entry & Source Handling', () {
    testWidgets('passes trimmed values and LeadSource.manual to repository', (
      tester,
    ) async {
      Lead? capturedLead;
      await tester.pumpWidget(
        buildTestWidget(onLeadCreated: (lead) => capturedLead = lead),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Lead Name'),
        '   Rajesh Sharma   ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone'),
        '  +91 9876543210  ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        '  rajesh@example.com  ',
      );

      await tester.tap(find.text('Create Lead'));
      await tester.pumpAndSettle();

      expect(repository.createLeadCallCount, 1);
      final draft = repository.lastCreateInput!.draft;
      expect(draft.name, 'Rajesh Sharma');
      expect(draft.phone, '+91 9876543210');
      expect(draft.email, 'rajesh@example.com');
      expect(draft.source, LeadSource.manual);
      expect(draft.status, isNull);

      expect(capturedLead, isNotNull);
      expect(capturedLead!.name, 'Rajesh Sharma');
      expect(capturedLead!.source, LeadSource.manual);
    });
  });

  group('AddLeadScreen - Submission State & Duplicate Tap Protection', () {
    testWidgets('shows loading and prevents duplicate taps while submitting', (
      tester,
    ) async {
      repository.createCompleter = Completer<Lead>();
      final cubit = LeadFormCubit(repository);

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Lead Name'),
        'Pooja Verma',
      );

      // First tap to trigger submission
      await tester.tap(find.text('Create Lead'));
      await tester.pump(); // Enter submitting state

      expect(find.text('Creating...'), findsOneWidget);
      expect(repository.createLeadCallCount, 1);

      // Attempt second tap during submission
      await tester.tap(find.text('Creating...'));
      await tester.pump();

      // Call count must remain 1
      expect(repository.createLeadCallCount, 1);

      // Complete async creation
      repository.createCompleter!.complete(
        const Lead(
          id: 'lead-pooja',
          name: 'Pooja Verma',
          source: LeadSource.manual,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lead created successfully'), findsOneWidget);
    });
  });

  group('AddLeadScreen - Failure State', () {
    testWidgets(
      'shows failure feedback, preserves entered values, allows retry',
      (tester) async {
        repository.shouldThrowOnCreate = true;

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Lead Name'),
          'Failed Lead Name',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Phone'),
          '+91 9000000000',
        );

        await tester.tap(find.text('Create Lead'));
        await tester.pumpAndSettle();

        // Failure feedback displayed in banner
        expect(find.text('Creation failed on server'), findsWidgets);

        // Values preserved in fields
        expect(find.text('Failed Lead Name'), findsOneWidget);
        expect(find.text('+91 9000000000'), findsOneWidget);

        // Fix failure condition and retry
        repository.shouldThrowOnCreate = false;
        await tester.tap(find.text('Create Lead'));
        await tester.pumpAndSettle();

        expect(repository.createLeadCallCount, 2);
        expect(find.text('Lead created successfully'), findsOneWidget);
      },
    );
  });

  group('AddLeadScreen - Cancel / Back Actions', () {
    testWidgets('invokes onCancel callback when Cancel is tapped', (
      tester,
    ) async {
      bool cancelCalled = false;
      await tester.pumpWidget(
        buildTestWidget(onCancel: () => cancelCalled = true),
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
      await tester.pumpWidget(
        buildTestWidget(onCancel: () => cancelCalled = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(cancelCalled, isTrue);
    });
  });

  group('AddLeadScreen - Responsive Layout', () {
    testWidgets('mobile layout (360x640) renders cleanly without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(size: const Size(360, 640)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Add Lead'), findsOneWidget);
      expect(find.text('Lead Name'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Create Lead'), findsOneWidget);
    });

    testWidgets('desktop layout (1200x800) renders centered wide layout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(size: const Size(1200, 800)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Add Lead'), findsOneWidget);
      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.text('Contact Information'), findsOneWidget);
      expect(find.text('Create Lead'), findsOneWidget);
    });
  });
}
