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
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_details_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadRepository implements LeadRepository {
  List<Lead> leads = [];
  List<LeadAssignee> assignees = const [];
  bool shouldThrow = false;
  bool shouldThrowOnGetAssignees = false;
  bool shouldThrowOnAssignLead = false;
  bool shouldThrowOnGetLeadByIdAfterAssignment = false;
  bool shouldThrowOnReassignLead = false;
  bool shouldThrowOnGetLeadByIdAfterReassignment = false;
  bool returnNullOnGetLeadByIdAfterReassignment = false;
  Completer<Lead?>? completer;
  Completer<void>? assignLeadCompleter;
  Completer<void>? reassignLeadCompleter;
  int getLeadByIdCallCount = 0;
  int assignLeadCallCount = 0;
  int reassignLeadCallCount = 0;
  String? lastAssignedLeadId;
  String? lastAssignedAssigneeId;
  LeadReassignmentRequest? lastReassignmentRequest;

  @override
  Future<Lead?> getLeadById(String leadId) async {
    getLeadByIdCallCount++;
    if (completer != null) return completer!.future;
    if (shouldThrow ||
        (shouldThrowOnGetLeadByIdAfterAssignment && assignLeadCallCount > 0) ||
        (shouldThrowOnGetLeadByIdAfterReassignment &&
            reassignLeadCallCount > 0)) {
      throw Exception('Database connection failed');
    }
    if (returnNullOnGetLeadByIdAfterReassignment && reassignLeadCallCount > 0) {
      return null;
    }
    return leads.cast<Lead?>().firstWhere(
      (l) => l?.id == leadId,
      orElse: () => null,
    );
  }

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async {
    if (shouldThrowOnGetAssignees) {
      throw Exception('Failed to fetch assignees');
    }
    return assignees;
  }

  @override
  Future<void> assignLead({
    required String leadId,
    required String assigneeId,
  }) async {
    assignLeadCallCount++;
    lastAssignedLeadId = leadId;
    lastAssignedAssigneeId = assigneeId;

    if (assignLeadCompleter != null) {
      await assignLeadCompleter!.future;
    }

    if (shouldThrowOnAssignLead) {
      throw Exception('Failed to assign lead');
    }

    final index = leads.indexWhere((l) => l.id == leadId);
    if (index != -1) {
      final assignee = assignees.where((a) => a.id == assigneeId).firstOrNull;
      leads[index] = leads[index].copyWith(
        assignedUserId: assigneeId,
        assignedUserName: assignee?.displayName ?? 'Agent $assigneeId',
        updatedAt: DateTime.now(),
      );
    }
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
  Future<Lead> createLead(CreateLeadInput input) async =>
      const Lead(id: 'dummy');

  @override
  Future<Lead> updateLead(UpdateLeadInput input) async =>
      const Lead(id: 'dummy');

  @override
  Future<void> assignLeads(LeadAssignmentRequest request) async {}

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) async {
    reassignLeadCallCount++;
    lastReassignmentRequest = request;

    if (reassignLeadCompleter != null) {
      await reassignLeadCompleter!.future;
    }

    if (shouldThrowOnReassignLead) {
      throw Exception('Failed to reassign lead');
    }

    final index = leads.indexWhere((l) => l.id == request.leadId);
    if (index != -1) {
      final assignee = assignees
          .where((a) => a.id == request.newAssigneeId)
          .firstOrNull;
      leads[index] = leads[index].copyWith(
        assignedUserId: request.newAssigneeId,
        assignedUserName:
            assignee?.displayName ?? 'Agent ${request.newAssigneeId}',
        updatedAt: DateTime.now(),
      );
    }
  }

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
    required String leadId,
    LeadDetailsCubit? cubit,
    LeadRepository? repo,
    void Function(Lead lead)? onEditLead,
    VoidCallback? onLeadAssigned,
    ThemeData? theme,
    Size size = const Size(800, 600),
  }) {
    return MaterialApp(
      theme: theme ?? ThemeData.light(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: LeadDetailsScreen(
            leadId: leadId,
            cubit: cubit,
            repository: repo ?? repository,
            onEditLead: onEditLead,
            onLeadAssigned: onLeadAssigned,
          ),
        ),
      ),
    );
  }

  group('LeadDetailsScreen - Loading', () {
    testWidgets('renders loading indicator and message while loading', (
      tester,
    ) async {
      repository.completer = Completer<Lead?>();
      final cubit = LeadDetailsCubit(repository);
      cubit.loadLead('lead-1');

      await tester.pumpWidget(buildTestWidget(leadId: 'lead-1', cubit: cubit));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading lead details...'), findsOneWidget);

      repository.completer!.complete(null);
      await tester.pumpAndSettle();
    });
  });

  group('LeadDetailsScreen - Loaded', () {
    testWidgets('renders all lead fields accurately', (tester) async {
      final lead = Lead(
        id: 'crm-lead-100',
        name: 'Priya Sharma',
        phone: '+91 9876500000',
        email: 'priya.sharma@example.com',
        source: LeadSource.manual,
        status: const LeadStatus('Discovery Complete'),
        assignedUserId: 'agent-10',
        assignedUserName: 'Sarah Jenkins',
        createdAt: DateTime.parse('2026-09-01T10:30:00Z'),
        updatedAt: DateTime.parse('2026-09-02T14:15:00Z'),
      );
      repository.leads = [lead];

      final cubit = LeadDetailsCubit(repository);
      await cubit.loadLead('crm-lead-100');

      await tester.pumpWidget(
        buildTestWidget(leadId: 'crm-lead-100', cubit: cubit),
      );
      await tester.pumpAndSettle();

      // Basic Information
      expect(find.text('Priya Sharma'), findsWidgets);
      expect(find.text('crm-lead-100'), findsOneWidget);

      // Contact Information
      expect(find.text('+91 9876500000'), findsOneWidget);
      expect(find.text('priya.sharma@example.com'), findsOneWidget);

      // Lead Information
      expect(find.text('Manual'), findsWidgets);
      expect(find.text('Discovery Complete'), findsWidgets);

      // Assignment
      expect(find.text('Sarah Jenkins'), findsWidgets);
      expect(find.text('Assigned'), findsWidgets);

      // Record Information
      expect(find.text('2026-09-01'), findsOneWidget);
      expect(find.text('2026-09-02'), findsOneWidget);

      // Section titles
      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.text('Contact Information'), findsOneWidget);
      expect(find.text('Lead Information'), findsOneWidget);
      expect(find.text('Assignment'), findsOneWidget);
      expect(find.text('Record Information'), findsOneWidget);
    });

    testWidgets('renders unassigned lead clearly', (tester) async {
      final lead = const Lead(
        id: 'unassigned-lead',
        name: 'Rahul Varma',
        source: LeadSource.excel,
        assignedUserId: null,
        assignedUserName: null,
      );
      repository.leads = [lead];

      final cubit = LeadDetailsCubit(repository);
      await cubit.loadLead('unassigned-lead');

      await tester.pumpWidget(
        buildTestWidget(leadId: 'unassigned-lead', cubit: cubit),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unassigned'), findsWidgets);
    });
  });

  group('LeadDetailsScreen - Nullable Fields Handling', () {
    testWidgets('handles all nullable values safely with neutral fallbacks', (
      tester,
    ) async {
      final lead = const Lead(
        id: 'lead-null-fields',
        name: null,
        phone: null,
        email: null,
        status: null,
        source: LeadSource.csv,
        assignedUserId: null,
        assignedUserName: null,
        createdAt: null,
        updatedAt: null,
      );
      repository.leads = [lead];

      final cubit = LeadDetailsCubit(repository);
      await cubit.loadLead('lead-null-fields');

      await tester.pumpWidget(
        buildTestWidget(leadId: 'lead-null-fields', cubit: cubit),
      );
      await tester.pumpAndSettle();

      // Name fallback
      expect(find.text('Unnamed Lead'), findsWidgets);
      // Fallback '—' for missing phone, email, status, created, updated
      expect(find.text('—'), findsWidgets);
      // Unassigned fallback
      expect(find.text('Unassigned'), findsWidgets);
      // CSV source
      expect(find.text('CSV'), findsWidgets);

      // Confirm no literal 'null' string is rendered anywhere
      expect(find.text('null'), findsNothing);
    });
  });

  group('LeadDetailsScreen - Not Found State', () {
    testWidgets('renders dedicated not found UI when lead does not exist', (
      tester,
    ) async {
      repository.leads = [];

      final cubit = LeadDetailsCubit(repository);
      await cubit.loadLead('unknown-lead-id');

      await tester.pumpWidget(
        buildTestWidget(leadId: 'unknown-lead-id', cubit: cubit),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lead not found'), findsOneWidget);
      expect(
        find.text('The requested lead could not be found.'),
        findsOneWidget,
      );
      expect(find.text('ID: unknown-lead-id'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_outlined), findsOneWidget);
    });
  });

  group('LeadDetailsScreen - Failure State', () {
    testWidgets(
      'renders failure UI with safe message and retry button reloads',
      (tester) async {
        repository.shouldThrow = true;

        final cubit = LeadDetailsCubit(repository);
        await cubit.loadLead('err-lead');

        await tester.pumpWidget(
          buildTestWidget(leadId: 'err-lead', cubit: cubit),
        );
        await tester.pumpAndSettle();

        expect(find.text('Failed to load lead'), findsOneWidget);
        expect(find.text('Database connection failed'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Now recover and tap Retry
        repository.shouldThrow = false;
        repository.leads = [const Lead(id: 'err-lead', name: 'Recovered Lead')];

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.text('Recovered Lead'), findsWidgets);
      },
    );
  });

  group('LeadDetailsScreen - Actions', () {
    testWidgets('tapping Edit Lead triggers onEditLead callback with lead', (
      tester,
    ) async {
      final lead = const Lead(
        id: 'edit-target',
        name: 'Editable Lead',
        source: LeadSource.manual,
      );
      repository.leads = [lead];

      Lead? editedLead;
      final cubit = LeadDetailsCubit(repository);
      await cubit.loadLead('edit-target');

      await tester.pumpWidget(
        buildTestWidget(
          leadId: 'edit-target',
          cubit: cubit,
          onEditLead: (l) => editedLead = l,
        ),
      );
      await tester.pumpAndSettle();

      final editButton = find.widgetWithText(FilledButton, 'Edit Lead');
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);

      expect(editedLead, isNotNull);
      expect(editedLead?.id, 'edit-target');
      expect(editedLead?.name, 'Editable Lead');
    });
  });

  group('LeadDetailsScreen - Responsive Layout', () {
    testWidgets(
      'mobile layout (360x640) renders with long values without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final lead = Lead(
          id: 'long-mobile-id-12345678901234567890',
          name:
              'A Very Long Enterprise Lead Name That Needs Safe Wrapping On Mobile Screens',
          phone: '+91 9876543210-extension-45678',
          email:
              'very.long.enterprise.lead.email.address@multinational-corporation.example.com',
          source: LeadSource.manual,
          status: const LeadStatus(
            'Very Long Enterprise Pipeline Lifecycle Status',
          ),
          assignedUserId: 'u1',
          assignedUserName: 'Assigned Senior Lead Executive Agent Specialist',
          createdAt: DateTime.parse('2026-09-01T10:00:00Z'),
          updatedAt: DateTime.parse('2026-09-02T12:00:00Z'),
        );
        repository.leads = [lead];

        final cubit = LeadDetailsCubit(repository);
        await cubit.loadLead('long-mobile-id-12345678901234567890');

        await tester.pumpWidget(
          buildTestWidget(
            leadId: 'long-mobile-id-12345678901234567890',
            cubit: cubit,
            size: const Size(360, 640),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('desktop layout (1200x800) renders wide details layout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lead = const Lead(
        id: 'desktop-lead',
        name: 'Desktop Display Lead',
        source: LeadSource.excel,
      );
      repository.leads = [lead];

      final cubit = LeadDetailsCubit(repository);
      await cubit.loadLead('desktop-lead');

      await tester.pumpWidget(
        buildTestWidget(
          leadId: 'desktop-lead',
          cubit: cubit,
          size: const Size(1200, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Desktop Display Lead'), findsWidgets);
      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.text('Assignment'), findsOneWidget);
    });
  });

  group('LeadDetailsScreen - L5.2 Single Lead Assignment', () {
    const agent1 = LeadAssignee(id: 'agent-1', displayName: 'Mock Agent One');
    const agent2 = LeadAssignee(id: 'agent-2', displayName: 'Mock Agent Two');

    const unassignedLead = Lead(
      id: 'lead-unassigned',
      name: 'Unassigned Person',
      source: LeadSource.manual,
    );

    const assignedLead = Lead(
      id: 'lead-assigned',
      name: 'Assigned Person',
      source: LeadSource.manual,
      assignedUserId: 'agent-1',
      assignedUserName: 'Mock Agent One',
    );

    testWidgets(
      'unassigned Lead shows Assign Lead button, assigned Lead does NOT',
      (tester) async {
        repository.leads = [unassignedLead, assignedLead];

        // 1. Unassigned Lead
        await tester.pumpWidget(buildTestWidget(leadId: 'lead-unassigned'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assign_lead_button')), findsOneWidget);
        expect(find.text('Assign Lead'), findsOneWidget);

        // 2. Assigned Lead
        await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assign_lead_button')), findsNothing);
        expect(find.text('Mock Agent One'), findsWidgets);
        expect(find.text('Assigned'), findsWidgets);
      },
    );

    testWidgets('tap Assign Lead opens dialog and loads assignable users', (
      tester,
    ) async {
      repository.leads = [unassignedLead];
      repository.assignees = [agent1, agent2];

      await tester.pumpWidget(buildTestWidget(leadId: 'lead-unassigned'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('assign_lead_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assign_lead_dialog')), findsOneWidget);
      expect(find.text('Assign Lead'), findsWidgets);
      expect(find.byKey(const Key('lead_assignee_dropdown')), findsOneWidget);
      expect(
        find.byKey(const Key('assign_dialog_cancel_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('assign_dialog_submit_button')),
        findsOneWidget,
      );
    });

    testWidgets(
      'happy path: selects assignee and assigns lead, updates details screen',
      (tester) async {
        repository.leads = [unassignedLead];
        repository.assignees = [agent1, agent2];

        bool callbackCalled = false;
        await tester.pumpWidget(
          buildTestWidget(
            leadId: 'lead-unassigned',
            onLeadAssigned: () => callbackCalled = true,
          ),
        );
        await tester.pumpAndSettle();

        // Open dialog
        await tester.tap(find.byKey(const Key('assign_lead_button')));
        await tester.pumpAndSettle();

        // Submit should initially be disabled
        final submitButton = tester.widget<FilledButton>(
          find.byKey(const Key('assign_dialog_submit_button')),
        );
        expect(submitButton.onPressed, isNull);

        // Select Mock Agent One
        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Mock Agent One').last);
        await tester.pumpAndSettle();

        // Tap Assign
        await tester.tap(find.byKey(const Key('assign_dialog_submit_button')));
        await tester.pumpAndSettle();

        // Dialog is closed
        expect(find.byKey(const Key('assign_lead_dialog')), findsNothing);
        expect(repository.assignLeadCallCount, equals(1));
        expect(repository.lastAssignedLeadId, equals('lead-unassigned'));
        expect(repository.lastAssignedAssigneeId, equals('agent-1'));
        expect(callbackCalled, isTrue);

        // Details screen shows updated assignee and state
        expect(find.text('Mock Agent One'), findsWidgets);
        expect(find.text('Assigned'), findsWidgets);
        expect(find.byKey(const Key('assign_lead_button')), findsNothing);
      },
    );

    testWidgets(
      'repository failure displays safe error and preserves selected assignee for retry',
      (tester) async {
        repository.leads = [unassignedLead];
        repository.assignees = [agent1];
        repository.shouldThrowOnAssignLead = true;

        await tester.pumpWidget(buildTestWidget(leadId: 'lead-unassigned'));
        await tester.pumpAndSettle();

        // Open dialog
        await tester.tap(find.byKey(const Key('assign_lead_button')));
        await tester.pumpAndSettle();

        // Select agent1
        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent One').last);
        await tester.pumpAndSettle();

        // Tap Assign -> fails
        await tester.tap(find.byKey(const Key('assign_dialog_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assign_lead_dialog')), findsOneWidget);
        expect(find.byKey(const Key('assign_dialog_error')), findsOneWidget);
        expect(find.text('Unable to assign the Lead.'), findsOneWidget);
        expect(repository.assignLeadCallCount, equals(1));

        // Retry: recover repository
        repository.shouldThrowOnAssignLead = false;
        await tester.tap(find.byKey(const Key('assign_dialog_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assign_lead_dialog')), findsNothing);
        expect(repository.assignLeadCallCount, equals(2));
        expect(find.text('Mock Agent One'), findsWidgets);
      },
    );

    testWidgets('cancel before submission does not mutate repository', (
      tester,
    ) async {
      repository.leads = [unassignedLead];
      repository.assignees = [agent1];

      await tester.pumpWidget(buildTestWidget(leadId: 'lead-unassigned'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('assign_lead_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('assign_dialog_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assign_lead_dialog')), findsNothing);
      expect(repository.assignLeadCallCount, equals(0));
      expect(find.byKey(const Key('assign_lead_button')), findsOneWidget);
    });

    testWidgets('system back during pending submission is blocked', (
      tester,
    ) async {
      repository.leads = [unassignedLead];
      repository.assignees = [agent1];
      final completer = Completer<void>();
      repository.assignLeadCompleter = completer;

      await tester.pumpWidget(buildTestWidget(leadId: 'lead-unassigned'));
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.byKey(const Key('assign_lead_button')));
      await tester.pumpAndSettle();

      // Select agent1
      await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mock Agent One').last);
      await tester.pumpAndSettle();

      // Tap Assign (will hang on completer)
      await tester.tap(find.byKey(const Key('assign_dialog_submit_button')));
      await tester.pump();

      // Attempt Back/pop while pending
      await tester.binding.handlePopRoute();
      await tester.pump();

      // Dialog is still open
      expect(find.byKey(const Key('assign_lead_dialog')), findsOneWidget);
      expect(repository.assignLeadCallCount, equals(1));

      // Complete future
      completer.complete();
      await tester.pumpAndSettle();

      // Dialog now closes
      expect(find.byKey(const Key('assign_lead_dialog')), findsNothing);
      expect(find.text('Mock Agent One'), findsWidgets);
    });

    testWidgets(
      'refresh failure after successful assignment is distinguished and does not re-run assignment',
      (tester) async {
        repository.leads = [unassignedLead];
        repository.assignees = [agent1];
        repository.shouldThrowOnGetLeadByIdAfterAssignment = true;

        await tester.pumpWidget(buildTestWidget(leadId: 'lead-unassigned'));
        await tester.pumpAndSettle();

        // Open dialog
        await tester.tap(find.byKey(const Key('assign_lead_button')));
        await tester.pumpAndSettle();

        // Select agent1
        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent One').last);
        await tester.pumpAndSettle();

        // Tap Assign
        await tester.tap(find.byKey(const Key('assign_dialog_submit_button')));
        await tester.pumpAndSettle();

        // Assignment mutation succeeded exactly once
        expect(repository.assignLeadCallCount, equals(1));
        expect(find.byKey(const Key('assign_lead_dialog')), findsNothing);

        // UI reports refresh failure, NOT "Unable to assign the Lead."
        expect(find.text('Unable to assign the Lead.'), findsNothing);
        expect(find.text('Failed to load lead'), findsOneWidget);
      },
    );

    testWidgets('renders cleanly in dark theme and across viewports', (
      tester,
    ) async {
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

        repository.leads = [unassignedLead];
        repository.assignees = [agent1];

        await tester.pumpWidget(
          buildTestWidget(
            leadId: 'lead-unassigned',
            theme: ThemeData.dark(useMaterial3: true),
            size: size,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('assign_lead_button')), findsOneWidget);

        // Open dialog and check for overflows
        await tester.ensureVisible(find.byKey(const Key('assign_lead_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('assign_lead_button')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('assign_lead_dialog')), findsOneWidget);

        // Close dialog
        await tester.ensureVisible(
          find.byKey(const Key('assign_dialog_cancel_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('assign_dialog_cancel_button')));
        await tester.pumpAndSettle();
      }
    });
  });

  group('LeadDetailsScreen - L6A.2 Lead Reassignment UI', () {
    const agent1 = LeadAssignee(id: 'agent-1', displayName: 'Mock Agent One');
    const agent2 = LeadAssignee(id: 'agent-2', displayName: 'Mock Agent Two');
    const agent3 = LeadAssignee(id: 'agent-3', displayName: 'Mock Agent Three');

    const assignedLead = Lead(
      id: 'lead-assigned',
      name: 'Assigned Customer',
      source: LeadSource.manual,
      assignedUserId: 'agent-1',
      assignedUserName: 'Mock Agent One',
    );

    const unassignedLead = Lead(
      id: 'lead-unassigned',
      name: 'Unassigned Customer',
      source: LeadSource.manual,
    );

    testWidgets(
      'visibility: unassigned Lead shows Assign Lead and hides Reassign Lead; assigned Lead shows Reassign Lead and hides Assign Lead',
      (tester) async {
        repository.leads = [unassignedLead, assignedLead];

        // 1. Unassigned
        await tester.pumpWidget(buildTestWidget(leadId: 'lead-unassigned'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assign_lead_button')), findsOneWidget);
        expect(find.byKey(const Key('reassign_lead_button')), findsNothing);

        // 2. Assigned
        await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reassign_lead_button')), findsOneWidget);
        expect(find.byKey(const Key('assign_lead_button')), findsNothing);
        expect(find.text('Mock Agent One'), findsWidgets);
        expect(find.text('Assigned'), findsWidgets);
      },
    );

    testWidgets(
      'tapping Reassign Lead opens dialog, displays current assignee, and loads assignees',
      (tester) async {
        repository.leads = [assignedLead];
        repository.assignees = [agent1, agent2, agent3];

        await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reassign_lead_dialog')), findsOneWidget);
        expect(find.text('Reassign Lead'), findsWidgets);
        expect(find.text('Current assignee:'), findsOneWidget);
        expect(find.text('Mock Agent One'), findsWidgets);
        expect(find.text('New assignee:'), findsOneWidget);
        expect(
          find.byKey(const Key('lead_reassignee_dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('reassign_dialog_reason_input')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('reassign_dialog_cancel_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('reassign_dialog_submit_button')),
          findsOneWidget,
        );

        final submitBtn = tester.widget<FilledButton>(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        expect(submitBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'assignee loading states: loading, error + retry, and truthful empty state',
      (tester) async {
        // 1. Error state on initial fetch
        repository.leads = [assignedLead];
        repository.shouldThrowOnGetAssignees = true;

        await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('reassign_assignee_selector_failure')),
          findsOneWidget,
        );
        expect(find.text('Unable to load assignable users.'), findsOneWidget);
        expect(
          find.byKey(const Key('reassign_assignee_selector_retry_button')),
          findsOneWidget,
        );

        // Retry
        repository.shouldThrowOnGetAssignees = false;
        repository.assignees = [];
        await tester.tap(
          find.byKey(const Key('reassign_assignee_selector_retry_button')),
        );
        await tester.pumpAndSettle();

        // Empty state
        expect(
          find.byKey(const Key('reassign_assignee_selector_empty')),
          findsOneWidget,
        );
        expect(find.text('No assignable users available.'), findsOneWidget);
        final submitBtn = tester.widget<FilledButton>(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        expect(submitBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'same assignee guard: current assignee is disabled in dropdown and cannot be submitted',
      (tester) async {
        repository.leads = [assignedLead];
        repository.assignees = [agent1, agent2];

        await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        // Open dropdown
        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();

        expect(find.text('Mock Agent One (Current)'), findsWidgets);

        // Attempt to tap the current assignee item
        await tester.tap(find.text('Mock Agent One (Current)').last);
        await tester.pumpAndSettle();

        // Submit button remains disabled
        final submitBtn = tester.widget<FilledButton>(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        expect(submitBtn.onPressed, isNull);
        expect(repository.reassignLeadCallCount, 0);
      },
    );

    testWidgets(
      'happy path: selects replacement, enters reason, reassigns lead, reloads details screen and invokes callback',
      (tester) async {
        repository.leads = [assignedLead];
        repository.assignees = [agent1, agent2, agent3];

        bool callbackCalled = false;
        await tester.pumpWidget(
          buildTestWidget(
            leadId: 'lead-assigned',
            onLeadAssigned: () => callbackCalled = true,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        // Open dropdown and select Mock Agent Two
        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        // Enter reason
        await tester.enterText(
          find.byKey(const Key('reassign_dialog_reason_input')),
          'Workload balancing',
        );
        await tester.pumpAndSettle();

        // Submit should now be enabled
        final submitBtn = tester.widget<FilledButton>(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        expect(submitBtn.onPressed, isNotNull);

        await tester.tap(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Repository called with correct arguments
        expect(repository.reassignLeadCallCount, 1);
        expect(repository.lastReassignmentRequest!.leadId, 'lead-assigned');
        expect(repository.lastReassignmentRequest!.newAssigneeId, 'agent-2');
        expect(
          repository.lastReassignmentRequest!.reason,
          'Workload balancing',
        );

        // Dialog closed
        expect(find.byKey(const Key('reassign_lead_dialog')), findsNothing);

        // Callback invoked
        expect(callbackCalled, isTrue);

        // Details screen updated
        expect(find.text('Mock Agent Two'), findsWidgets);
        expect(find.byKey(const Key('reassign_lead_button')), findsOneWidget);
      },
    );

    testWidgets('reason normalization: blank reason normalizes to null', (
      tester,
    ) async {
      repository.leads = [assignedLead];
      repository.assignees = [agent1, agent2];

      await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reassign_lead_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mock Agent Two').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('reassign_dialog_reason_input')),
        '   \t  ',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reassign_dialog_submit_button')));
      await tester.pumpAndSettle();

      expect(repository.lastReassignmentRequest!.reason, isNull);
    });

    testWidgets(
      'reason normalization: trimmed whitespace reason is normalized to trimmed string',
      (tester) async {
        repository.leads = [assignedLead];
        repository.assignees = [agent1, agent2];

        await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('reassign_dialog_reason_input')),
          '  Territory adjustment  ',
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(
          repository.lastReassignmentRequest!.reason,
          'Territory adjustment',
        );
      },
    );

    testWidgets(
      'repository failure displays safe error and preserves inputs for retry',
      (tester) async {
        repository.leads = [assignedLead];
        repository.assignees = [agent1, agent2];
        repository.shouldThrowOnReassignLead = true;

        await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('reassign_dialog_reason_input')),
          'Shift rebalance',
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Safe error displayed
        expect(find.byKey(const Key('reassign_dialog_error')), findsOneWidget);
        expect(find.text('Unable to reassign the Lead.'), findsOneWidget);
        expect(find.byKey(const Key('reassign_lead_dialog')), findsOneWidget);

        // Retry succeeds
        repository.shouldThrowOnReassignLead = false;
        await tester.tap(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reassign_lead_dialog')), findsNothing);
        expect(find.text('Mock Agent Two'), findsWidgets);
      },
    );

    testWidgets('pending submission blocks dismissal and barrier', (
      tester,
    ) async {
      repository.leads = [assignedLead];
      repository.assignees = [agent1, agent2];
      final completer = Completer<void>();
      repository.reassignLeadCompleter = completer;

      await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reassign_lead_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mock Agent Two').last);
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('reassign_dialog_submit_button')));
      await tester.pump();

      // In submitting state, cancel is disabled
      final cancelBtn = tester.widget<TextButton>(
        find.byKey(const Key('reassign_dialog_cancel_button')),
      );
      expect(cancelBtn.onPressed, isNull);

      // PopScope blocks pop
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reassign_lead_dialog')), findsNothing);
      expect(repository.reassignLeadCallCount, 1);
    });

    testWidgets(
      'refresh failure after successful reassignment is distinguished and does not re-run reassignment',
      (tester) async {
        repository.leads = [assignedLead];
        repository.assignees = [agent1, agent2];
        repository.shouldThrowOnGetLeadByIdAfterReassignment = true;

        await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Reassignment mutation occurred once
        expect(repository.reassignLeadCallCount, 1);
        expect(find.byKey(const Key('reassign_lead_dialog')), findsNothing);

        // UI reports refresh failure, NOT "Unable to reassign the Lead."
        expect(find.text('Unable to reassign the Lead.'), findsNothing);
        expect(find.text('Failed to load lead'), findsOneWidget);

        // Retrying detail reload does NOT re-run reassignLead
        repository.shouldThrowOnGetLeadByIdAfterReassignment = false;
        await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
        await tester.pumpAndSettle();

        expect(repository.reassignLeadCallCount, 1);
        expect(find.text('Mock Agent Two'), findsWidgets);
      },
    );

    testWidgets('renders cleanly across viewports and dark theme', (
      tester,
    ) async {
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

        repository.leads = [assignedLead];
        repository.assignees = [agent1, agent2];

        await tester.pumpWidget(
          buildTestWidget(
            leadId: 'lead-assigned',
            theme: ThemeData.dark(useMaterial3: true),
            size: size,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('reassign_lead_button')), findsOneWidget);

        // Open dialog and check for overflows
        await tester.ensureVisible(
          find.byKey(const Key('reassign_lead_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('reassign_lead_dialog')), findsOneWidget);

        // Close dialog
        await tester.ensureVisible(
          find.byKey(const Key('reassign_dialog_cancel_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('reassign_dialog_cancel_button')),
        );
        await tester.pumpAndSettle();
      }
    });

    testWidgets(
      'current assignee missing from getAssignableUsers: header truthfully displays current name and selector shows only repository candidates',
      (tester) async {
        const currentAssigneeLead = Lead(
          id: 'lead-assigned-old',
          name: 'Customer X',
          source: LeadSource.manual,
          assignedUserId: 'agent-old',
          assignedUserName: 'Old Agent',
        );
        repository.leads = [currentAssigneeLead];
        repository.assignees = [agent1, agent2]; // does NOT include agent-old

        await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned-old'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        // 1. Current assignee header truthfully shows 'Old Agent' inside the dialog
        expect(
          find.descendant(
            of: find.byKey(const Key('reassign_lead_dialog')),
            matching: find.text('Old Agent'),
          ),
          findsOneWidget,
        );

        // 2. Open dropdown
        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();

        // 3. Dropdown shows agent1 and agent2 only, does not fabricate Old Agent
        expect(find.text('Mock Agent One'), findsWidgets);
        expect(find.text('Mock Agent Two'), findsWidgets);
        expect(find.text('Old Agent (Current)'), findsNothing);

        // 4. Selecting Mock Agent One succeeds
        await tester.tap(find.text('Mock Agent One').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(repository.reassignLeadCallCount, 1);
        expect(repository.lastReassignmentRequest!.newAssigneeId, 'agent-1');
        expect(find.byKey(const Key('reassign_lead_dialog')), findsNothing);
      },
    );

    testWidgets(
      'empty replacement set: getAssignableUsers returns empty list -> truthful empty message and Reassign disabled',
      (tester) async {
        repository.leads = [assignedLead];
        repository.assignees = [];

        await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reassign_lead_dialog')), findsOneWidget);
        expect(
          find.byKey(const Key('reassign_assignee_selector_empty')),
          findsOneWidget,
        );
        expect(find.text('No assignable users available.'), findsOneWidget);

        // Reassign button is disabled
        final submitBtn = tester.widget<FilledButton>(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        expect(submitBtn.onPressed, isNull);
        expect(repository.reassignLeadCallCount, 0);
      },
    );

    testWidgets(
      'empty replacement set: getAssignableUsers returns only current assignee -> no valid replacement choice and Reassign disabled',
      (tester) async {
        repository.leads = [assignedLead]; // assignedUserId: 'agent-1'
        repository.assignees = [agent1]; // only agent-1

        await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reassign_lead_dialog')), findsOneWidget);
        expect(
          find.byKey(const Key('lead_reassignee_dropdown')),
          findsOneWidget,
        );

        // Open dropdown: current assignee is disabled
        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();

        expect(find.text('Mock Agent One (Current)'), findsOneWidget);

        // Reassign button is disabled
        final submitBtn = tester.widget<FilledButton>(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        expect(submitBtn.onPressed, isNull);
        expect(repository.reassignLeadCallCount, 0);
      },
    );

    testWidgets(
      'missing lead during refresh: reassign succeeds but getLeadById returns null -> displays not-found state without repeating reassignment',
      (tester) async {
        repository.leads = [assignedLead];
        repository.assignees = [agent1, agent2];
        repository.returnNullOnGetLeadByIdAfterReassignment = true;

        await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Mutation succeeded once
        expect(repository.reassignLeadCallCount, 1);
        expect(find.byKey(const Key('reassign_lead_dialog')), findsNothing);

        // Shows not-found state
        expect(find.text('Lead not found'), findsOneWidget);

        // Retrying detail reload does NOT re-run reassignLead
        repository.returnNullOnGetLeadByIdAfterReassignment = false;
        await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
        await tester.pumpAndSettle();

        expect(repository.reassignLeadCallCount, 1);
        expect(find.text('Mock Agent Two'), findsWidgets);
      },
    );

    testWidgets(
      'cancellation: opening dialog, selecting candidate and reason, then tapping Cancel aborts with zero repository mutations',
      (tester) async {
        repository.leads = [assignedLead];
        repository.assignees = [agent1, agent2];

        await tester.pumpWidget(buildTestWidget(leadId: 'lead-assigned'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('reassign_dialog_reason_input')),
          'Cancelled transfer request',
        );
        await tester.pumpAndSettle();

        // Cancel
        await tester.tap(
          find.byKey(const Key('reassign_dialog_cancel_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reassign_lead_dialog')), findsNothing);
        expect(repository.reassignLeadCallCount, 0);
        expect(find.text('Mock Agent One'), findsWidgets);
      },
    );
  });
}
