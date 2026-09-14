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
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_list_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_list_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/widgets/lead_data_table.dart';
import 'package:enterprise_crm/features/leads/presentation/widgets/lead_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadRepository implements LeadRepository {
  List<Lead> leads = [];
  bool shouldThrow = false;
  int getLeadsCallCount = 0;
  Completer<LeadPage>? completer;
  LeadQuery? lastQuery;

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async {
    lastQuery = query;
    getLeadsCallCount++;
    if (completer != null) return completer!.future;
    if (shouldThrow) throw Exception('Unable to connect to lead service');
    return LeadPage(
      items: leads,
      currentPage: 1,
      pageSize: query.pageSize,
      totalItems: leads.length,
      hasNext: false,
    );
  }

  @override
  Future<Lead?> getLeadById(String leadId) async => null;

  @override
  Future<Lead> createLead(CreateLeadInput input) async =>
      const Lead(id: 'dummy');

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
    LeadListCubit? cubit,
    void Function(Lead lead)? onViewLead,
    VoidCallback? onAddLead,
    VoidCallback? onImportLeads,
    Size size = const Size(800, 600),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: LeadListScreen(
            cubit: cubit,
            repository: cubit == null ? repository : null,
            onViewLead: onViewLead,
            onAddLead: onAddLead,
            onImportLeads: onImportLeads,
          ),
        ),
      ),
    );
  }

  group('LeadListScreen - Loading', () {
    testWidgets('renders loading state with progress indicator and text', (
      tester,
    ) async {
      repository.completer = Completer<LeadPage>();
      final cubit = LeadListCubit(repository);
      cubit.loadLeads();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading leads...'), findsOneWidget);

      repository.completer!.complete(
        const LeadPage(
          items: [],
          currentPage: 1,
          pageSize: 20,
          totalItems: 0,
          hasNext: false,
        ),
      );
      await tester.pumpAndSettle();
    });
  });

  group('LeadListScreen - Loaded', () {
    testWidgets('renders lead items when loaded', (tester) async {
      repository.leads = [
        Lead(
          id: 'lead-1',
          name: 'Aarav Sharma',
          phone: '+91 9876543210',
          email: 'aarav@example.com',
          source: LeadSource.manual,
          status: const LeadStatus('Sample New'),
          assignedUserId: 'u1',
          assignedUserName: 'Mock Agent One',
          createdAt: DateTime.parse('2026-09-01T10:00:00Z'),
        ),
        Lead(
          id: 'lead-2',
          name: 'Pooja Verma',
          phone: '+91 9811122233',
          email: 'pooja@example.com',
          source: LeadSource.excel,
          status: const LeadStatus('Sample Follow-up'),
          assignedUserId: null,
          createdAt: DateTime.parse('2026-09-02T11:00:00Z'),
        ),
      ];

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Pooja Verma'), findsOneWidget);
      expect(find.text('+91 9876543210'), findsOneWidget);
      expect(find.text('aarav@example.com'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Excel'), findsOneWidget);
      expect(find.text('Sample New'), findsOneWidget);
      expect(find.text('Sample Follow-up'), findsOneWidget);
      expect(find.text('Mock Agent One'), findsOneWidget);
      expect(find.text('Unassigned'), findsOneWidget);
    });
  });

  group('LeadListScreen - Nullable Data Handling', () {
    testWidgets(
      'handles all nullable fields gracefully with neutral fallbacks',
      (tester) async {
        repository.leads = [
          const Lead(
            id: 'null-lead',
            name: null,
            phone: null,
            email: null,
            status: null,
            source: LeadSource.csv,
            assignedUserId: null,
            assignedUserName: null,
            createdAt: null,
          ),
        ];

        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        // Check fallback values
        expect(find.text('Unnamed Lead'), findsOneWidget);
        expect(find.text('CSV'), findsOneWidget);
        expect(find.text('Unassigned'), findsOneWidget);
        // Phone, email, status, date fallbacks are '—'
        expect(find.text('—'), findsWidgets);

        // Verify no literal 'null' string is rendered
        expect(find.text('null'), findsNothing);
      },
    );
  });

  group('LeadListScreen - Empty State', () {
    testWidgets('renders empty state when zero leads exist', (tester) async {
      repository.leads = [];

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('No leads found'), findsOneWidget);
      expect(
        find.text('Add a lead manually or import leads from Excel/CSV.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('Add Lead'), findsWidgets);
      expect(find.text('Import Leads'), findsOneWidget);
    });

    testWidgets('triggers onAddLead and onImportLeads from empty state', (
      tester,
    ) async {
      repository.leads = [];
      bool addTapped = false;
      bool importTapped = false;

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(
        buildTestWidget(
          cubit: cubit,
          onAddLead: () => addTapped = true,
          onImportLeads: () => importTapped = true,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Add Lead in empty state body
      final addLeadButtons = find.widgetWithText(FilledButton, 'Add Lead');
      await tester.tap(addLeadButtons.last);
      expect(addTapped, isTrue);

      // Tap Import Leads
      final importButton = find.widgetWithText(OutlinedButton, 'Import Leads');
      await tester.tap(importButton);
      expect(importTapped, isTrue);
    });
  });

  group('LeadListScreen - Failure State', () {
    testWidgets('renders failure state on error and retry button reloads', (
      tester,
    ) async {
      repository.shouldThrow = true;

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load leads'), findsOneWidget);
      expect(find.text('Unable to connect to lead service'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Now set shouldThrow to false and tap Retry
      repository.shouldThrow = false;
      repository.leads = [
        const Lead(
          id: 'lead-recovered',
          name: 'Recovered Lead',
          source: LeadSource.manual,
        ),
      ];

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Recovered Lead'), findsOneWidget);
    });
  });

  group('LeadListScreen - Responsive Layout', () {
    testWidgets('mobile layout (360x640) renders cards without overflow', (
      tester,
    ) async {
      repository.leads = [
        Lead(
          id: 'mobile-lead-1',
          name: 'A Very Long Enterprise Lead Name That Might Overflow Mobile',
          phone: '+91 9876543210',
          email:
              'very.long.enterprise.email.address@multinational-corp.example.com',
          source: LeadSource.manual,
          status: const LeadStatus('High Priority Enterprise Status'),
          assignedUserId: 'u1',
          assignedUserName: 'Assigned Senior Lead Executive Agent',
          createdAt: DateTime.parse('2026-09-01T10:00:00Z'),
        ),
      ];

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(
        buildTestWidget(cubit: cubit, size: const Size(360, 640)),
      );
      await tester.pumpAndSettle();

      // Card layout should be used on mobile
      expect(find.byType(LeadListCard), findsOneWidget);
      expect(find.byType(LeadDataTable), findsNothing);

      // Verify no overflow exception occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop layout (1200x800) renders data table', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      repository.leads = [
        const Lead(
          id: 'desktop-lead-1',
          name: 'Desktop Test Lead',
          phone: '+91 9876543210',
          email: 'desktop@example.com',
          source: LeadSource.excel,
        ),
      ];

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(
        buildTestWidget(cubit: cubit, size: const Size(1200, 800)),
      );
      await tester.pumpAndSettle();

      // Data table layout should be used on desktop
      expect(find.byType(LeadDataTable), findsOneWidget);
      expect(find.byType(LeadListCard), findsNothing);

      // Verify table column headers
      expect(find.text('Lead'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Assigned To'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
    });
  });

  group('LeadListScreen - Action Callbacks', () {
    testWidgets(
      'tapping View invokes onViewLead callback with lead on mobile',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final testLead = const Lead(
          id: 'view-lead-1',
          name: 'Target Lead',
          source: LeadSource.manual,
        );
        repository.leads = [testLead];

        Lead? selectedLead;
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(
          buildTestWidget(
            cubit: cubit,
            size: const Size(360, 640),
            onViewLead: (lead) => selectedLead = lead,
          ),
        );
        await tester.pumpAndSettle();

        final viewButton = find.widgetWithText(OutlinedButton, 'View');
        expect(viewButton, findsOneWidget);
        await tester.tap(viewButton);

        expect(selectedLead, isNotNull);
        expect(selectedLead?.id, 'view-lead-1');
        expect(selectedLead?.name, 'Target Lead');
      },
    );

    testWidgets(
      'tapping View invokes onViewLead callback with lead on desktop',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final testLead = const Lead(
          id: 'view-lead-2',
          name: 'Target Lead 2',
          source: LeadSource.csv,
        );
        repository.leads = [testLead];

        Lead? selectedLead;
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(
          buildTestWidget(
            cubit: cubit,
            size: const Size(1200, 800),
            onViewLead: (lead) => selectedLead = lead,
          ),
        );
        await tester.pumpAndSettle();

        final viewButton = find.widgetWithText(OutlinedButton, 'View');
        expect(viewButton, findsOneWidget);
        await tester.ensureVisible(viewButton);
        await tester.tap(viewButton);

        expect(selectedLead, isNotNull);
        expect(selectedLead?.id, 'view-lead-2');
        expect(selectedLead?.name, 'Target Lead 2');
      },
    );

    testWidgets('tapping Add Lead in AppBar triggers onAddLead callback', (
      tester,
    ) async {
      repository.leads = [const Lead(id: 'lead-1', name: 'Existing Lead')];
      bool addLeadTapped = false;

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(
        buildTestWidget(cubit: cubit, onAddLead: () => addLeadTapped = true),
      );
      await tester.pumpAndSettle();

      final addLeadButton = find.widgetWithText(FilledButton, 'Add Lead');
      await tester.tap(addLeadButton);

      expect(addLeadTapped, isTrue);
    });

    testWidgets('tapping Refresh in AppBar reloads leads', (tester) async {
      repository.leads = [const Lead(id: 'lead-1', name: 'Initial Lead')];

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();
      final initialCallCount = repository.getLeadsCallCount;

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      final refreshButton = find.byTooltip('Refresh Leads');
      expect(refreshButton, findsOneWidget);
      await tester.tap(refreshButton);
      await tester.pumpAndSettle();

      expect(repository.getLeadsCallCount, greaterThan(initialCallCount));
    });
  });

  group('LeadListScreen - Search', () {
    testWidgets('renders search input field with hint and search icon', (
      tester,
    ) async {
      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text('Search leads by name, phone, or email'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byTooltip('Search'), findsOneWidget);
    });

    testWidgets(
      'submitting search by tapping Search icon applies query with page 1',
      (tester) async {
        repository.leads = [
          const Lead(id: '1', name: 'Alice Smith'),
          const Lead(id: '2', name: 'Bob Jones'),
        ];
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'alice');
        await tester.pump();
        await tester.tap(find.byTooltip('Search'));
        await tester.pumpAndSettle();

        expect(repository.lastQuery?.searchText, equals('alice'));
        expect(repository.lastQuery?.page, equals(1));
        expect(find.text('Results for "alice"'), findsOneWidget);
      },
    );

    testWidgets('submitting search by pressing Enter applies query', (
      tester,
    ) async {
      repository.leads = [const Lead(id: '1', name: 'Bob Jones')];
      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bob');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(repository.lastQuery?.searchText, equals('bob'));
      expect(repository.lastQuery?.page, equals(1));
      expect(find.text('Results for "bob"'), findsOneWidget);
    });

    testWidgets(
      'submitting search with leading/trailing whitespace trims before applying',
      (tester) async {
        repository.leads = [const Lead(id: '1', name: 'Alice')];
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '   Alice   ');
        await tester.tap(find.byTooltip('Search'));
        await tester.pumpAndSettle();

        expect(repository.lastQuery?.searchText, equals('Alice'));
        expect(repository.lastQuery?.page, equals(1));
      },
    );

    testWidgets(
      'submitting empty or whitespace-only search clears searchText and reloads',
      (tester) async {
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads(query: const LeadQuery(searchText: 'alice'));

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        expect(repository.lastQuery?.searchText, equals('alice'));

        await tester.enterText(find.byType(TextField), '   ');
        await tester.tap(find.byTooltip('Search'));
        await tester.pumpAndSettle();

        expect(repository.lastQuery?.searchText, isNull);
        expect(repository.lastQuery?.page, equals(1));
        expect(find.text('Results for "alice"'), findsNothing);
      },
    );

    testWidgets(
      'tapping clear icon button clears text and resets query with page 1',
      (tester) async {
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads(query: const LeadQuery(searchText: 'alice'));

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        final clearButton = find.byTooltip('Clear Search');
        expect(clearButton, findsOneWidget);
        await tester.tap(clearButton);
        await tester.pumpAndSettle();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, isEmpty);
        expect(repository.lastQuery?.searchText, isNull);
        expect(repository.lastQuery?.page, equals(1));
      },
    );

    testWidgets(
      'displays search-specific empty state when search returns zero leads',
      (tester) async {
        repository.leads = [];
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads(
          query: const LeadQuery(searchText: 'nonexistent'),
        );

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        expect(find.text('No matching leads'), findsOneWidget);
        expect(
          find.text(
            'No leads match "nonexistent".\nTry a different name, phone number, or email.',
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.search_off_outlined), findsOneWidget);
        expect(
          find.widgetWithText(OutlinedButton, 'Clear Search'),
          findsOneWidget,
        );
        // Base empty state copy should NOT be shown
        expect(find.text('No leads found'), findsNothing);
        expect(
          find.text('Add a lead manually or import leads from Excel/CSV.'),
          findsNothing,
        );
      },
    );

    testWidgets('tapping Clear Search in empty state restores full lead list', (
      tester,
    ) async {
      repository.leads = [];
      final cubit = LeadListCubit(repository);
      await cubit.loadLeads(query: const LeadQuery(searchText: 'nonexistent'));

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('No matching leads'), findsOneWidget);

      repository.leads = [const Lead(id: '1', name: 'Existing Lead')];
      final clearButton = find.widgetWithText(OutlinedButton, 'Clear Search');
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(repository.lastQuery?.searchText, isNull);
      expect(repository.lastQuery?.page, equals(1));
      expect(find.text('Existing Lead'), findsOneWidget);
    });

    testWidgets(
      'search retains query text during failure, and retry re-executes search',
      (tester) async {
        repository.leads = [const Lead(id: '1', name: 'Alice')];
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        // Perform search that fails
        repository.shouldThrow = true;
        await tester.enterText(find.byType(TextField), 'alice');
        await tester.tap(find.byTooltip('Search'));
        await tester.pumpAndSettle();

        // Verify failure state rendered but search field still visible with 'alice'
        expect(find.text('Failed to load leads'), findsOneWidget);
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, equals('alice'));

        // Retry should retry with active search
        repository.shouldThrow = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(repository.lastQuery?.searchText, equals('alice'));
        expect(find.text('Alice'), findsOneWidget);
      },
    );

    testWidgets('preserves non-search query values when searching', (
      tester,
    ) async {
      const existingQuery = LeadQuery(
        source: LeadSource.manual,
        status: LeadStatus('Negotiation'),
        assignedUserId: 'u42',
        isAssigned: true,
        page: 3,
      );
      final cubit = LeadListCubit(repository);
      await cubit.loadLeads(query: existingQuery);

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'target');
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();

      final query = repository.lastQuery!;
      expect(query.searchText, equals('target'));
      expect(query.page, equals(1)); // page reset to 1
      expect(query.source, equals(LeadSource.manual));
      expect(query.status, equals(const LeadStatus('Negotiation')));
      expect(query.assignedUserId, equals('u42'));
      expect(query.isAssigned, isTrue);
    });

    testWidgets('renders cleanly without overflow across mobile sizes', (
      tester,
    ) async {
      final mobileSizes = [
        const Size(320, 568),
        const Size(360, 640),
        const Size(390, 844),
      ];

      for (final size in mobileSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        repository.leads = [
          const Lead(
            id: '1',
            name: 'Mobile Search Lead With Long Details',
            source: LeadSource.manual,
          ),
        ];
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(buildTestWidget(cubit: cubit, size: size));
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byTooltip('Search'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets(
      'renders constrained search bar alongside data table on desktop (1200x800)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        repository.leads = [
          const Lead(id: '1', name: 'Desktop Lead', source: LeadSource.manual),
        ];
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, size: const Size(1200, 800)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LeadDataTable), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byTooltip('Search'), findsOneWidget);

        // ConstrainedBox with maxWidth: 480 should wrap the TextField
        final constrainedBox = tester.widget<ConstrainedBox>(
          find
              .ancestor(
                of: find.byType(TextField),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        );
        expect(constrainedBox.constraints.maxWidth, equals(480));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
