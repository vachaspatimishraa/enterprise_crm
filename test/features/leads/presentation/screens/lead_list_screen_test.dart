import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignee.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_sort.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_summary.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_filter_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_list_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_selected_file.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_import_workflow_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_list_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/services/lead_import_file_picker.dart';
import 'package:enterprise_crm/features/leads/presentation/widgets/lead_active_filters.dart';
import 'package:enterprise_crm/features/leads/presentation/widgets/bulk_assign_leads_dialog.dart';
import 'package:enterprise_crm/features/leads/presentation/widgets/lead_data_table.dart';
import 'package:enterprise_crm/features/leads/presentation/widgets/lead_filter_sheet.dart';
import 'package:enterprise_crm/features/leads/presentation/widgets/lead_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadImportFilePicker implements LeadImportFilePicker {
  _FakeLeadImportFilePicker({this.fileToPick});

  LeadImportSelectedFile? fileToPick;

  @override
  Future<LeadImportSelectedFile?> pickFile() async => fileToPick;
}

class _FakeLeadRepository implements LeadRepository {
  List<Lead> leads = [];
  bool shouldThrow = false;
  int getLeadsCallCount = 0;
  Completer<LeadPage>? completer;
  LeadQuery? lastQuery;
  int? overrideCurrentPage;
  int? overrideTotalItems;
  bool? overrideHasNext;
  bool filterByQuery = false;

  int assignLeadsCallCount = 0;
  LeadAssignmentRequest? lastAssignLeadsRequest;
  Completer<void>? assignLeadsCompleter;
  int assignLeadsFailureCount = 0;

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async {
    lastQuery = query;
    getLeadsCallCount++;
    if (completer != null) return completer!.future;
    if (shouldThrow) throw Exception('Unable to connect to lead service');
    var resultLeads = leads;
    if (filterByQuery) {
      if (query.isAssigned != null) {
        resultLeads = resultLeads
            .where((l) => l.isAssigned == query.isAssigned)
            .toList();
      }
      if (query.searchText != null && query.searchText!.trim().isNotEmpty) {
        final st = query.searchText!.trim().toLowerCase();
        resultLeads = resultLeads
            .where((l) => (l.name?.toLowerCase().contains(st) ?? false))
            .toList();
      }
    }
    return LeadPage(
      items: resultLeads,
      currentPage: overrideCurrentPage ?? query.page,
      pageSize: query.pageSize,
      totalItems: overrideTotalItems ?? resultLeads.length,
      hasNext: overrideHasNext ?? false,
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
  Future<void> assignLeads(LeadAssignmentRequest request) async {
    lastAssignLeadsRequest = request;
    assignLeadsCallCount++;
    if (assignLeadsCompleter != null) {
      await assignLeadsCompleter!.future;
    }
    if (assignLeadsFailureCount > 0) {
      assignLeadsFailureCount--;
      throw Exception('Assignment failed');
    }
    final updated = <Lead>[];
    for (final l in leads) {
      if (request.leadIds.contains(l.id)) {
        final assigneeName = assignableUsers
            .firstWhere(
              (u) => u.id == request.assigneeId,
              orElse: () => LeadAssignee(
                id: request.assigneeId,
                displayName: 'Agent ${request.assigneeId}',
              ),
            )
            .displayName;
        updated.add(
          l.copyWith(
            assignedUserId: request.assigneeId,
            assignedUserName: assigneeName,
          ),
        );
      } else {
        updated.add(l);
      }
    }
    leads = updated;
  }

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) async {}

  List<LeadAssignee> assignableUsers = const [
    LeadAssignee(id: 'agent-1', displayName: 'Mock Agent One'),
    LeadAssignee(id: 'agent-2', displayName: 'Mock Agent Two'),
  ];

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async => assignableUsers;

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
    LeadFilterCubit? filterCubit,
    void Function(Lead lead)? onViewLead,
    VoidCallback? onAddLead,
    VoidCallback? onImportLeads,
    Size size = const Size(800, 600),
    ThemeData? theme,
    bool isDistributionMode = false,
  }) {
    return MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: LeadListScreen(
            cubit: cubit,
            repository: repository,
            filterCubit: filterCubit,
            onViewLead: onViewLead,
            onAddLead: onAddLead,
            onImportLeads: onImportLeads,
            isDistributionMode: isDistributionMode,
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

  group('LeadListScreen - Filters', () {
    testWidgets(
      'renders filter button with "Filters" when no filters are active',
      (tester) async {
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('lead_filter_button')), findsOneWidget);
        expect(find.text('Filters'), findsOneWidget);
      },
    );

    testWidgets(
      'renders filter button with "Filters (2)" when 2 filters are active',
      (tester) async {
        final cubit = LeadListCubit(repository);
        // Query with 2 filters, plus search and status which should NOT be counted
        const query = LeadQuery(
          source: LeadSource.manual,
          isAssigned: true,
          searchText: 'Alice',
          status: LeadStatus('Sample New'),
        );
        await cubit.loadLeads(query: query);

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        expect(find.text('Filters (2)'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping filter button on mobile (< 600px) opens bottom sheet',
      (tester) async {
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, size: const Size(360, 640)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_filter_button')));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.byType(LeadFilterSheet), findsOneWidget);
      },
    );

    testWidgets('tapping filter button on desktop (>= 600px) opens dialog', (
      tester,
    ) async {
      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(
        buildTestWidget(cubit: cubit, size: const Size(1200, 800)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lead_filter_button')));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(LeadFilterSheet), findsOneWidget);
    });

    testWidgets(
      'applying filters through modal updates LeadListCubit.currentQuery with page 1',
      (tester) async {
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads(query: const LeadQuery(page: 3));

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, size: const Size(1200, 800)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_filter_button')));
        await tester.pumpAndSettle();

        // Tap Manual source
        await tester.tap(find.byKey(const Key('filter_source_manual')));
        await tester.pumpAndSettle();

        // Tap Assigned
        await tester.tap(find.byKey(const Key('filter_assignment_assigned')));
        await tester.pumpAndSettle();

        final applyButton = find.byKey(const Key('filter_apply_button'));
        await tester.ensureVisible(applyButton);
        await tester.tap(applyButton);
        await tester.pumpAndSettle();

        expect(cubit.currentQuery.source, equals(LeadSource.manual));
        expect(cubit.currentQuery.isAssigned, isTrue);
        expect(cubit.currentQuery.page, equals(1));
      },
    );

    testWidgets(
      'preserves active search when applying filters and vice-versa',
      (tester) async {
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads(
          query: const LeadQuery(searchText: 'Alice', page: 2),
        );

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, size: const Size(800, 600)),
        );
        await tester.pumpAndSettle();

        // Open filters and apply Source: Excel
        await tester.tap(find.byKey(const Key('lead_filter_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('filter_source_excel')));
        await tester.pumpAndSettle();

        final applyButton = find.byKey(const Key('filter_apply_button'));
        await tester.ensureVisible(applyButton);
        await tester.tap(applyButton);
        await tester.pumpAndSettle();

        // Verify both search and filter are present, page reset to 1
        expect(cubit.currentQuery.searchText, equals('Alice'));
        expect(cubit.currentQuery.source, equals(LeadSource.excel));
        expect(cubit.currentQuery.page, equals(1));

        // Now change search text and press Enter
        await tester.enterText(find.byType(TextField), 'Bob');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        // Verify filter is preserved
        expect(cubit.currentQuery.searchText, equals('Bob'));
        expect(cubit.currentQuery.source, equals(LeadSource.excel));
        expect(cubit.currentQuery.page, equals(1));
      },
    );

    testWidgets(
      'active filter chips render on screen and can be removed individually',
      (tester) async {
        repository.assignableUsers = [
          const LeadAssignee(id: 'u1', displayName: 'Mock Agent One'),
        ];
        final cubit = LeadListCubit(repository);
        const query = LeadQuery(
          source: LeadSource.manual,
          isAssigned: true,
          assignedUserId: 'u1',
        );
        await cubit.loadLeads(query: query);

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        expect(find.byType(LeadActiveFilters), findsOneWidget);
        expect(find.text('Manual'), findsOneWidget);
        expect(find.text('Assigned'), findsOneWidget);
        expect(find.text('Mock Agent One'), findsOneWidget);

        // Remove Source chip
        final sourceDelete = find.descendant(
          of: find.byKey(const Key('active_filter_source_chip')),
          matching: find.byIcon(Icons.close),
        );
        await tester.tap(sourceDelete);
        await tester.pumpAndSettle();

        expect(cubit.currentQuery.source, isNull);
        expect(cubit.currentQuery.isAssigned, isTrue);
        expect(cubit.currentQuery.assignedUserId, equals('u1'));
        expect(cubit.currentQuery.page, equals(1));

        // Remove Assignee chip
        final assigneeDelete = find.descendant(
          of: find.byKey(const Key('active_filter_assignee_chip')),
          matching: find.byIcon(Icons.close),
        );
        await tester.tap(assigneeDelete);
        await tester.pumpAndSettle();

        expect(cubit.currentQuery.assignedUserId, isNull);
        expect(cubit.currentQuery.isAssigned, isTrue);
        expect(cubit.currentQuery.page, equals(1));
      },
    );

    testWidgets(
      'Clear all on active chips clears all filters but preserves search',
      (tester) async {
        final cubit = LeadListCubit(repository);
        const query = LeadQuery(
          searchText: 'Alice',
          source: LeadSource.manual,
          isAssigned: true,
          assignedUserId: 'u1',
          status: LeadStatus('Sample New'),
          page: 4,
        );
        await cubit.loadLeads(query: query);

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('active_filters_clear_all')));
        await tester.pumpAndSettle();

        expect(cubit.currentQuery.source, isNull);
        expect(cubit.currentQuery.isAssigned, isNull);
        expect(cubit.currentQuery.assignedUserId, isNull);
        expect(cubit.currentQuery.page, equals(1));
        expect(cubit.currentQuery.searchText, equals('Alice'));
        expect(
          cubit.currentQuery.status,
          equals(const LeadStatus('Sample New')),
        );
      },
    );

    testWidgets(
      'displays filtered empty state when only filters return zero leads and clear filters restores list',
      (tester) async {
        repository.leads = [];
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads(query: const LeadQuery(source: LeadSource.excel));

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        expect(find.text('No leads match these filters'), findsOneWidget);
        expect(
          find.text('Try changing or clearing your filters.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('empty_clear_filters_button')),
          findsOneWidget,
        );

        // Restore leads in repo and tap Clear Filters
        repository.leads = [
          const Lead(id: '1', name: 'Restored Lead', source: LeadSource.manual),
        ];
        await tester.tap(find.byKey(const Key('empty_clear_filters_button')));
        await tester.pumpAndSettle();

        expect(cubit.currentQuery.source, isNull);
        expect(cubit.currentQuery.page, equals(1));
        expect(find.text('Restored Lead'), findsOneWidget);
      },
    );

    testWidgets(
      'displays search + filter empty state when both search and filters are active',
      (tester) async {
        repository.leads = [];
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads(
          query: const LeadQuery(
            searchText: 'NonExistent',
            source: LeadSource.csv,
          ),
        );

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        expect(
          find.text('No leads match your search and filters'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('empty_clear_filters_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('empty_clear_search_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'failure state preserves applied filters, and retry re-executes query',
      (tester) async {
        repository.shouldThrow = true;
        final cubit = LeadListCubit(repository);
        const query = LeadQuery(
          searchText: 'Alice',
          source: LeadSource.manual,
          isAssigned: true,
        );
        await cubit.loadLeads(query: query);

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        expect(find.text('Failed to load leads'), findsOneWidget);
        expect(find.text('Filters (2)'), findsOneWidget);

        repository.shouldThrow = false;
        repository.leads = [
          const Lead(id: '1', name: 'Alice', source: LeadSource.manual),
        ];

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(cubit.currentQuery, equals(query));
        expect(
          find.descendant(
            of: find.byType(LeadDataTable),
            matching: find.text('Alice'),
          ),
          findsOneWidget,
        );
      },
    );

    for (final size in [
      const Size(320, 568),
      const Size(360, 640),
      const Size(768, 1024),
      const Size(1200, 800),
    ]) {
      testWidgets(
        'renders cleanly without overflow at ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          repository.leads = [
            const Lead(
              id: '1',
              name: 'Responsive Lead',
              source: LeadSource.manual,
            ),
          ];
          final cubit = LeadListCubit(repository);
          await cubit.loadLeads(
            query: const LeadQuery(
              searchText: 'Responsive',
              source: LeadSource.manual,
              isAssigned: true,
            ),
          );

          await tester.pumpWidget(buildTestWidget(cubit: cubit, size: size));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Filters (2)'), findsOneWidget);
          expect(find.byType(LeadActiveFilters), findsOneWidget);
        },
      );
    }
  });

  group('LeadListScreen - Sorting', () {
    testWidgets('sort selector is visible and displays current sort label', (
      tester,
    ) async {
      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lead_sort_button')), findsOneWidget);
      expect(find.text('Sort: Default'), findsOneWidget);
    });

    testWidgets(
      'selecting a sort updates query with page 1, preserves other fields, and updates UI label',
      (tester) async {
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads(
          query: const LeadQuery(
            searchText: 'Acme',
            source: LeadSource.manual,
            status: LeadStatus('New'),
            isAssigned: true,
            page: 3,
            pageSize: 50,
          ),
        );

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        // Tap sort button to open menu
        await tester.tap(find.byKey(const Key('lead_sort_button')));
        await tester.pumpAndSettle();

        // Menu items should be visible
        expect(find.text('Name A–Z'), findsOneWidget);
        expect(find.text('Name Z–A'), findsOneWidget);
        expect(find.text('Newest Created'), findsOneWidget);
        expect(find.text('Oldest Created'), findsOneWidget);

        // Select Name A–Z
        await tester.tap(find.text('Name A–Z'));
        await tester.pumpAndSettle();

        expect(
          cubit.currentQuery.sort,
          equals(
            const LeadSort(
              field: LeadSortField.name,
              direction: LeadSortDirection.ascending,
            ),
          ),
        );
        expect(cubit.currentQuery.page, 1);
        expect(cubit.currentQuery.pageSize, 50);
        expect(cubit.currentQuery.searchText, 'Acme');
        expect(cubit.currentQuery.source, LeadSource.manual);
        expect(cubit.currentQuery.status, const LeadStatus('New'));
        expect(cubit.currentQuery.isAssigned, isTrue);

        expect(find.text('Sort: Name A–Z'), findsOneWidget);
      },
    );

    testWidgets('selecting Default clears sort to null', (tester) async {
      final cubit = LeadListCubit(repository);
      await cubit.loadLeads(
        query: const LeadQuery(
          sort: LeadSort(
            field: LeadSortField.name,
            direction: LeadSortDirection.ascending,
          ),
        ),
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('Sort: Name A–Z'), findsOneWidget);

      await tester.tap(find.byKey(const Key('lead_sort_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Default'));
      await tester.pumpAndSettle();

      expect(cubit.currentQuery.sort, isNull);
      expect(find.text('Sort: Default'), findsOneWidget);
    });

    testWidgets('clear search preserves active sort', (tester) async {
      final cubit = LeadListCubit(repository);
      await cubit.loadLeads(
        query: const LeadQuery(
          searchText: 'Alice',
          sort: LeadSort(
            field: LeadSortField.createdAt,
            direction: LeadSortDirection.descending,
          ),
        ),
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('Sort: Newest Created'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear Search'));
      await tester.pumpAndSettle();

      expect(cubit.currentQuery.searchText, isNull);
      expect(
        cubit.currentQuery.sort,
        equals(
          const LeadSort(
            field: LeadSortField.createdAt,
            direction: LeadSortDirection.descending,
          ),
        ),
      );
      expect(find.text('Sort: Newest Created'), findsOneWidget);
    });

    testWidgets('clear filters preserves active sort', (tester) async {
      final cubit = LeadListCubit(repository);
      await cubit.loadLeads(
        query: const LeadQuery(
          source: LeadSource.manual,
          sort: LeadSort(
            field: LeadSortField.name,
            direction: LeadSortDirection.descending,
          ),
        ),
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('Sort: Name Z–A'), findsOneWidget);
      expect(
        find.byKey(const Key('active_filter_source_chip')),
        findsOneWidget,
      );
      expect(find.text('Manual'), findsOneWidget);

      // Tap remove chip icon
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('active_filter_source_chip')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();

      expect(cubit.currentQuery.source, isNull);
      expect(
        cubit.currentQuery.sort,
        equals(
          const LeadSort(
            field: LeadSortField.name,
            direction: LeadSortDirection.descending,
          ),
        ),
      );
      expect(find.text('Sort: Name Z–A'), findsOneWidget);
    });

    testWidgets(
      'failure state preserves sort, and retry re-executes query with sort',
      (tester) async {
        repository.shouldThrow = true;
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads(
          query: const LeadQuery(
            sort: LeadSort(
              field: LeadSortField.name,
              direction: LeadSortDirection.ascending,
            ),
          ),
        );

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        expect(find.text('Failed to load leads'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        repository.shouldThrow = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(
          repository.lastQuery!.sort,
          equals(
            const LeadSort(
              field: LeadSortField.name,
              direction: LeadSortDirection.ascending,
            ),
          ),
        );
      },
    );

    for (final size in [
      const Size(320, 568),
      const Size(360, 640),
      const Size(600, 800),
      const Size(768, 1024),
      const Size(1200, 800),
    ]) {
      testWidgets(
        'renders header with Search + Filters + Sort cleanly at ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          repository.leads = [
            const Lead(
              id: '1',
              name: 'Enterprise Client Name',
              source: LeadSource.manual,
            ),
          ];
          final cubit = LeadListCubit(repository);
          await cubit.loadLeads(
            query: const LeadQuery(
              searchText: 'Enterprise',
              source: LeadSource.manual,
              isAssigned: true,
              sort: LeadSort(
                field: LeadSortField.createdAt,
                direction: LeadSortDirection.descending,
              ),
            ),
          );

          await tester.pumpWidget(buildTestWidget(cubit: cubit, size: size));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('lead_sort_button')), findsOneWidget);
          expect(find.byKey(const Key('lead_filter_button')), findsOneWidget);
          expect(find.text('Sort: Newest Created'), findsOneWidget);
        },
      );
    }
  });

  group('LeadListScreen - Pagination', () {
    testWidgets('renders pagination footer with result range and page text', (
      tester,
    ) async {
      repository.leads = List.generate(
        20,
        (i) => Lead(id: 'lead-$i', name: 'Lead $i'),
      );
      repository.overrideTotalItems = 53;
      repository.overrideHasNext = true;

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pagination_range_text')), findsOneWidget);
      expect(find.text('1–20 of 53 leads'), findsOneWidget);
      expect(find.byKey(const Key('pagination_page_text')), findsOneWidget);
      expect(find.text('Page 1 of 3'), findsOneWidget);
      expect(
        find.byKey(const Key('pagination_previous_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pagination_next_button')), findsOneWidget);
    });

    testWidgets(
      'Previous button is disabled on page 1 and tapping does not issue request',
      (tester) async {
        repository.leads = List.generate(
          20,
          (i) => Lead(id: 'lead-$i', name: 'Lead $i'),
        );
        repository.overrideTotalItems = 53;
        repository.overrideHasNext = true;

        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        final initialCalls = repository.getLeadsCallCount;

        final prevButton = tester.widget<OutlinedButton>(
          find.byKey(const Key('pagination_previous_button')),
        );
        expect(prevButton.onPressed, isNull);

        await tester.tap(find.byKey(const Key('pagination_previous_button')));
        await tester.pumpAndSettle();

        expect(repository.getLeadsCallCount, initialCalls);
        expect(cubit.currentQuery.page, 1);
      },
    );

    testWidgets(
      'Next button is enabled when hasNext is true and tapping navigates to page 2',
      (tester) async {
        repository.leads = List.generate(
          20,
          (i) => Lead(id: 'lead-$i', name: 'Lead $i'),
        );
        repository.overrideTotalItems = 53;
        repository.overrideHasNext = true;

        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        // Tap Next
        await tester.tap(find.byKey(const Key('pagination_next_button')));
        await tester.pumpAndSettle();

        expect(cubit.currentQuery.page, 2);
        expect(repository.lastQuery!.page, 2);
        expect(find.text('21–40 of 53 leads'), findsOneWidget);
        expect(find.text('Page 2 of 3'), findsOneWidget);
      },
    );

    testWidgets('tapping Previous on page 2 navigates back to page 1', (
      tester,
    ) async {
      repository.leads = List.generate(
        20,
        (i) => Lead(id: 'lead-$i', name: 'Lead $i'),
      );
      repository.overrideTotalItems = 53;
      repository.overrideHasNext = true;

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads(query: const LeadQuery(page: 2));

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('Page 2 of 3'), findsOneWidget);

      // Tap Previous
      await tester.tap(find.byKey(const Key('pagination_previous_button')));
      await tester.pumpAndSettle();

      expect(cubit.currentQuery.page, 1);
      expect(repository.lastQuery!.page, 1);
      expect(find.text('Page 1 of 3'), findsOneWidget);
    });

    testWidgets(
      'Next button is disabled when hasNext is false and does not trigger request',
      (tester) async {
        repository.leads = List.generate(
          13,
          (i) => Lead(id: 'lead-$i', name: 'Lead $i'),
        );
        repository.overrideTotalItems = 53;
        repository.overrideHasNext = false;

        final cubit = LeadListCubit(repository);
        await cubit.loadLeads(query: const LeadQuery(page: 3));

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        expect(find.text('Page 3 of 3'), findsOneWidget);

        final nextButton = tester.widget<OutlinedButton>(
          find.byKey(const Key('pagination_next_button')),
        );
        expect(nextButton.onPressed, isNull);

        final callsBefore = repository.getLeadsCallCount;
        await tester.tap(find.byKey(const Key('pagination_next_button')));
        await tester.pumpAndSettle();

        expect(repository.getLeadsCallCount, callsBefore);
        expect(cubit.currentQuery.page, 3);
      },
    );

    testWidgets('search preservation: Next preserves active search text', (
      tester,
    ) async {
      repository.leads = [const Lead(id: '1', name: 'Alice')];
      repository.overrideTotalItems = 30;
      repository.overrideHasNext = true;

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads(
        query: const LeadQuery(searchText: 'Alice', page: 1),
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pagination_next_button')));
      await tester.pumpAndSettle();

      expect(cubit.currentQuery.searchText, 'Alice');
      expect(cubit.currentQuery.page, 2);
    });

    testWidgets('filter preservation: Next preserves active filters', (
      tester,
    ) async {
      repository.leads = [const Lead(id: '1', name: 'Lead 1')];
      repository.overrideTotalItems = 30;
      repository.overrideHasNext = true;

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads(
        query: const LeadQuery(
          source: LeadSource.manual,
          isAssigned: true,
          assignedUserId: 'agent-1',
          page: 1,
        ),
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pagination_next_button')));
      await tester.pumpAndSettle();

      expect(cubit.currentQuery.source, LeadSource.manual);
      expect(cubit.currentQuery.isAssigned, isTrue);
      expect(cubit.currentQuery.assignedUserId, 'agent-1');
      expect(cubit.currentQuery.page, 2);
    });

    testWidgets('sort preservation: Next preserves active sort', (
      tester,
    ) async {
      repository.leads = [const Lead(id: '1', name: 'Lead 1')];
      repository.overrideTotalItems = 30;
      repository.overrideHasNext = true;

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads(
        query: const LeadQuery(
          sort: LeadSort(
            field: LeadSortField.name,
            direction: LeadSortDirection.ascending,
          ),
          page: 1,
        ),
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pagination_next_button')));
      await tester.pumpAndSettle();

      expect(
        cubit.currentQuery.sort,
        equals(
          const LeadSort(
            field: LeadSortField.name,
            direction: LeadSortDirection.ascending,
          ),
        ),
      );
      expect(cubit.currentQuery.page, 2);
    });

    testWidgets(
      'MANDATORY REGRESSION TEST: Combined query preservation across pagination',
      (tester) async {
        repository.leads = [const Lead(id: '1', name: 'Lead 1')];
        repository.overrideTotalItems = 100;
        repository.overrideHasNext = true;

        const complexQuery = LeadQuery(
          searchText: 'Acme',
          status: LeadStatus('Qualified'),
          source: LeadSource.manual,
          isAssigned: true,
          assignedUserId: 'agent-1',
          sort: LeadSort(
            field: LeadSortField.name,
            direction: LeadSortDirection.ascending,
          ),
          pageSize: 20,
          page: 1,
        );

        final cubit = LeadListCubit(repository);
        await cubit.loadLeads(query: complexQuery);

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        // Navigate Next
        await tester.tap(find.byKey(const Key('pagination_next_button')));
        await tester.pumpAndSettle();

        // Verify ONLY page changed
        expect(cubit.currentQuery.page, 2);
        expect(cubit.currentQuery.searchText, complexQuery.searchText);
        expect(cubit.currentQuery.status, complexQuery.status);
        expect(cubit.currentQuery.source, complexQuery.source);
        expect(cubit.currentQuery.isAssigned, complexQuery.isAssigned);
        expect(cubit.currentQuery.assignedUserId, complexQuery.assignedUserId);
        expect(cubit.currentQuery.sort, complexQuery.sort);
        expect(cubit.currentQuery.pageSize, complexQuery.pageSize);

        // Navigate Previous
        await tester.tap(find.byKey(const Key('pagination_previous_button')));
        await tester.pumpAndSettle();

        // Verify back to page 1 with all original fields
        expect(cubit.currentQuery, equals(complexQuery));
      },
    );

    testWidgets('search change resets page to 1', (tester) async {
      repository.leads = [const Lead(id: '1', name: 'Lead 1')];
      repository.overrideTotalItems = 100;
      repository.overrideHasNext = true;

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads(query: const LeadQuery(page: 4));

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(cubit.currentQuery.page, 4);

      // Enter search
      await tester.enterText(find.byType(TextField), 'New Search');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(cubit.currentQuery.page, 1);
      expect(cubit.currentQuery.searchText, 'New Search');
    });

    testWidgets('filter change resets page to 1', (tester) async {
      repository.leads = [
        const Lead(id: '1', name: 'Lead 1', source: LeadSource.manual),
      ];
      repository.overrideTotalItems = 100;
      repository.overrideHasNext = true;

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads(
        query: const LeadQuery(source: LeadSource.manual, page: 3),
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(cubit.currentQuery.page, 3);

      // Remove source chip
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('active_filter_source_chip')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();

      expect(cubit.currentQuery.page, 1);
      expect(cubit.currentQuery.source, isNull);
    });

    testWidgets('sort change resets page to 1', (tester) async {
      repository.leads = [const Lead(id: '1', name: 'Lead 1')];
      repository.overrideTotalItems = 100;
      repository.overrideHasNext = true;

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads(query: const LeadQuery(page: 2));

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(cubit.currentQuery.page, 2);

      // Change sort
      await tester.tap(find.byKey(const Key('lead_sort_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name A–Z'));
      await tester.pumpAndSettle();

      expect(cubit.currentQuery.page, 1);
      expect(
        cubit.currentQuery.sort,
        equals(
          const LeadSort(
            field: LeadSortField.name,
            direction: LeadSortDirection.ascending,
          ),
        ),
      );
    });

    testWidgets(
      'failure state on page 2 preserves page 2 and Retry re-executes query with page 2',
      (tester) async {
        repository.leads = [const Lead(id: '1', name: 'Lead 1')];
        repository.overrideTotalItems = 50;
        repository.overrideHasNext = true;

        final cubit = LeadListCubit(repository);
        await cubit.loadLeads(
          query: const LeadQuery(
            page: 2,
            searchText: 'Acme',
            source: LeadSource.manual,
          ),
        );

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        // Simulate failure on next reload
        repository.shouldThrow = true;
        cubit.refreshLeads();
        await tester.pumpAndSettle();

        expect(find.text('Failed to load leads'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Tap Retry
        repository.shouldThrow = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(repository.lastQuery!.page, 2);
        expect(repository.lastQuery!.searchText, 'Acme');
        expect(repository.lastQuery!.source, LeadSource.manual);
      },
    );

    for (final size in [
      const Size(320, 568),
      const Size(360, 640),
      const Size(600, 800),
      const Size(768, 1024),
      const Size(1200, 800),
    ]) {
      testWidgets(
        'renders full lead list with search, filters, sort, and pagination cleanly at ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          repository.leads = List.generate(
            10,
            (i) => Lead(
              id: 'lead-$i',
              name: 'Customer Client Number $i',
              source: LeadSource.manual,
            ),
          );
          repository.overrideTotalItems = 53;
          repository.overrideHasNext = true;

          final cubit = LeadListCubit(repository);
          await cubit.loadLeads(
            query: const LeadQuery(
              searchText: 'Customer',
              source: LeadSource.manual,
              isAssigned: true,
              sort: LeadSort(
                field: LeadSortField.createdAt,
                direction: LeadSortDirection.descending,
              ),
              page: 2,
            ),
          );

          await tester.pumpWidget(buildTestWidget(cubit: cubit, size: size));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('pagination_previous_button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('pagination_next_button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('pagination_range_text')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('pagination_page_text')), findsOneWidget);
          expect(find.text('21–40 of 53 leads'), findsOneWidget);
          expect(find.text('Page 2 of 3'), findsOneWidget);
        },
      );
    }
  });

  group('LeadListScreen - Lead Import Workflow Integration', () {
    testWidgets('exactly one import button in AppBar in loaded state', (
      tester,
    ) async {
      repository.leads = [const Lead(id: '1', name: 'Lead 1')];
      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lead_list_import_button')), findsOneWidget);
    });

    testWidgets('tapping AppBar import button opens LeadImportWorkflowScreen', (
      tester,
    ) async {
      repository.leads = [const Lead(id: '1', name: 'Lead 1')];
      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lead_list_import_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LeadImportWorkflowScreen), findsOneWidget);
    });

    testWidgets('successful import pops true and refreshes leads', (
      tester,
    ) async {
      repository.leads = [const Lead(id: '1', name: 'Lead 1')];
      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lead_list_import_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LeadImportWorkflowScreen), findsOneWidget);

      // Simulate repository receiving new lead during import
      repository.leads = [
        const Lead(id: '1', name: 'Lead 1'),
        const Lead(id: '2', name: 'Imported Lead'),
      ];

      // Simulate workflow popping true
      Navigator.of(
        tester.element(find.byType(LeadImportWorkflowScreen)),
      ).pop(true);
      await tester.pumpAndSettle();

      // Verified: back to list screen and list refreshed!
      expect(find.byType(LeadListScreen), findsOneWidget);
      expect(find.text('Imported Lead'), findsOneWidget);
    });

    testWidgets(
      'MANDATORY REGRESSION: shared repository instance is mutated by import and refreshed by LeadListScreen',
      (tester) async {
        final dataSource = MockLeadDataSource(
          initialLeads: [
            const Lead(
              id: 'initial-1',
              name: 'Initial Lead',
              source: LeadSource.manual,
            ),
          ],
        );
        final sharedRepository = MockLeadRepository(dataSource: dataSource);

        final csvFile = LeadImportSelectedFile(
          name: 'shared_import.csv',
          extension: 'csv',
          sizeBytes: 150,
          source: LeadSource.csv,
          content: InMemoryLeadImportFileContent(
            Uint8List.fromList(
              utf8.encode('Name,Email\nAlice,alice@example.com\n'),
            ),
          ),
        );
        final filePicker = _FakeLeadImportFilePicker(fileToPick: csvFile);

        await tester.pumpWidget(
          MaterialApp(
            home: LeadListScreen(
              repository: sharedRepository,
              filePicker: filePicker,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial visible leads: 'Initial Lead' is visible, Alice is not
        expect(find.text('Initial Lead'), findsOneWidget);
        expect(find.text('Alice'), findsNothing);

        // 2. Open import workflow from AppBar
        await tester.tap(find.byKey(const Key('lead_list_import_button')));
        await tester.pumpAndSettle();
        expect(find.byType(LeadImportWorkflowScreen), findsOneWidget);

        // 3. Complete workflow steps through to Result screen
        // Select file -> Continue
        await tester.tap(
          find.byKey(const Key('lead_import_choose_file_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lead_import_continue_button')));
        await tester.pumpAndSettle();

        // Structure -> Continue
        expect(find.text('Prepare Import'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('lead_import_structure_continue_button')),
        );
        await tester.pumpAndSettle();

        // Mapping -> Map Name and Email -> Continue
        expect(find.text('Map Lead Fields'), findsOneWidget);
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

        // Preview -> Continue
        expect(find.text('Import Preview'), findsOneWidget);
        expect(find.textContaining('Alice'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('lead_import_preview_continue_button')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('lead_import_preview_continue_button')),
        );
        await tester.pumpAndSettle();

        // Review -> Continue to Execute
        expect(find.text('Final Import Review'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('lead_import_review_continue_button')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('lead_import_review_continue_button')),
        );
        await tester.pumpAndSettle();

        // Result screen -> Tap Done
        expect(find.text('Import Complete'), findsWidgets);
        await tester.scrollUntilVisible(
          find.byKey(const Key('lead_import_result_done_button')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('lead_import_result_done_button')),
        );
        await tester.pumpAndSettle();

        // 4. Returned to LeadListScreen: caller refreshes and visible Leads now include Alice!
        expect(find.byType(LeadListScreen), findsOneWidget);
        expect(find.text('Initial Lead'), findsOneWidget);
        expect(find.text('Alice'), findsOneWidget);
      },
    );
  });

  group('LeadListScreen - L5.3 Bulk Lead Selection & Assignment', () {
    testWidgets(
      'selection mode enter, exit, toggle selection, and count display',
      (tester) async {
        repository.leads = [
          const Lead(
            id: 'lead-1',
            name: 'Lead One',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
          const Lead(
            id: 'lead-2',
            name: 'Lead Two',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
        ];

        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        // Initially in normal mode
        expect(
          find.byKey(const Key('lead_list_select_mode_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lead_list_cancel_selection_button')),
          findsNothing,
        );

        // Enter selection mode
        await tester.tap(find.byKey(const Key('lead_list_select_mode_button')));
        await tester.pumpAndSettle();

        // Verify selection mode UI
        expect(find.text('0 selected'), findsOneWidget);
        expect(
          find.byKey(const Key('lead_list_cancel_selection_button')),
          findsOneWidget,
        );
        final assignButtonFinder = find.byKey(
          const Key('lead_list_assign_leads_button'),
        );
        expect(assignButtonFinder, findsOneWidget);

        // Assign button should be disabled when 0 selected
        final assignButton = tester.widget<FilledButton>(assignButtonFinder);
        expect(assignButton.onPressed, isNull);

        // Select Lead One
        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-1')));
        await tester.pumpAndSettle();

        expect(find.text('1 selected'), findsOneWidget);
        final enabledAssignButton = tester.widget<FilledButton>(
          assignButtonFinder,
        );
        expect(enabledAssignButton.onPressed, isNotNull);

        // Deselect Lead One
        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-1')));
        await tester.pumpAndSettle();

        expect(find.text('0 selected'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(assignButtonFinder).onPressed,
          isNull,
        );

        // Exit selection mode
        await tester.tap(
          find.byKey(const Key('lead_list_cancel_selection_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('lead_list_select_mode_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lead_list_cancel_selection_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'mobile card layout: unassigned selectable, assigned not selectable, no details navigation in selection mode',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        repository.leads = [
          const Lead(
            id: 'unassigned-lead',
            name: 'Unassigned Person',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
          const Lead(
            id: 'assigned-lead',
            name: 'Assigned Person',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: 'agent-1',
            assignedUserName: 'Mock Agent One',
          ),
        ];

        bool viewLeadCalled = false;
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(
          buildTestWidget(
            cubit: cubit,
            size: const Size(360, 640),
            onViewLead: (lead) => viewLeadCalled = true,
          ),
        );
        await tester.pumpAndSettle();

        // In normal mobile mode, Lead cards are visible
        expect(find.byType(LeadListCard), findsNWidgets(2));

        // Enter selection mode
        await tester.tap(find.byKey(const Key('lead_list_select_mode_button')));
        await tester.pumpAndSettle();

        // Checkboxes should exist
        final unassignedCheckboxFinder = find.byKey(
          const Key('lead_select_checkbox_unassigned-lead'),
        );
        final assignedCheckboxFinder = find.byKey(
          const Key('lead_select_checkbox_assigned-lead'),
        );

        expect(unassignedCheckboxFinder, findsOneWidget);
        expect(assignedCheckboxFinder, findsOneWidget);

        // Unassigned checkbox is enabled
        final unassignedCheckbox = tester.widget<Checkbox>(
          unassignedCheckboxFinder,
        );
        expect(unassignedCheckbox.onChanged, isNotNull);

        // Assigned checkbox is disabled
        final assignedCheckbox = tester.widget<Checkbox>(
          assignedCheckboxFinder,
        );
        expect(assignedCheckbox.onChanged, isNull);

        // Tapping unassigned card toggles selection and does NOT navigate to details
        await tester.tap(unassignedCheckboxFinder);
        await tester.pumpAndSettle();

        expect(find.text('1 selected'), findsOneWidget);
        expect(viewLeadCalled, isFalse);

        // Tapping assigned card does not select it
        await tester.tap(find.text('Assigned Person'));
        await tester.pumpAndSettle();

        expect(find.text('1 selected'), findsOneWidget);
        expect(viewLeadCalled, isFalse);
      },
    );

    testWidgets(
      'desktop table layout: selection column, select-all and deselect-all for eligible leads only',
      (tester) async {
        repository.leads = [
          const Lead(
            id: 'lead-a',
            name: 'Lead Alpha',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
          const Lead(
            id: 'lead-b',
            name: 'Lead Beta',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
          const Lead(
            id: 'lead-c',
            name: 'Lead Gamma (Assigned)',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: 'agent-1',
            assignedUserName: 'Mock Agent One',
          ),
        ];

        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, size: const Size(1000, 700)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LeadDataTable), findsOneWidget);

        // Enter selection mode
        await tester.tap(find.byKey(const Key('lead_list_select_mode_button')));
        await tester.pumpAndSettle();

        // Table header checkbox exists
        final selectAllHeaderFinder = find.byKey(
          const Key('lead_data_table_select_all_checkbox'),
        );
        expect(selectAllHeaderFinder, findsOneWidget);

        // Tap table select-all checkbox: selects all eligible unassigned leads (A & B), not C
        await tester.tap(selectAllHeaderFinder);
        await tester.pumpAndSettle();

        expect(find.text('2 selected'), findsOneWidget);

        // Tap again to deselect all
        await tester.tap(selectAllHeaderFinder);
        await tester.pumpAndSettle();

        expect(find.text('0 selected'), findsOneWidget);

        // AppBar 'Select All' button also selects all eligible
        final appBarSelectAllFinder = find.byKey(
          const Key('lead_list_select_all_button'),
        );
        expect(appBarSelectAllFinder, findsOneWidget);

        await tester.tap(appBarSelectAllFinder);
        await tester.pumpAndSettle();

        expect(find.text('2 selected'), findsOneWidget);
        expect(find.text('Deselect All'), findsOneWidget);
      },
    );

    testWidgets(
      'bulk assignment success flow: selects unassigned leads, chooses assignee, submits, refreshes list from repository, and exits selection mode',
      (tester) async {
        repository.leads = [
          const Lead(
            id: 'lead-a',
            name: 'Lead Alpha',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
          const Lead(
            id: 'lead-b',
            name: 'Lead Beta',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
        ];

        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        // Enter selection mode and select both
        await tester.tap(find.byKey(const Key('lead_list_select_mode_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-a')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-b')));
        await tester.pumpAndSettle();

        expect(find.text('2 selected'), findsOneWidget);

        // Tap Assign Leads
        await tester.tap(
          find.byKey(const Key('lead_list_assign_leads_button')),
        );
        await tester.pumpAndSettle();

        // Modal should be open
        expect(find.byType(BulkAssignLeadsDialog), findsOneWidget);
        expect(find.text('Assign 2 Leads'), findsOneWidget);
        expect(find.text('Assigning 2 unassigned Leads to:'), findsOneWidget);

        // Submit button is disabled before assignee selected
        final submitButtonFinder = find.byKey(
          const Key('bulk_assign_dialog_submit_button'),
        );
        expect(
          tester.widget<FilledButton>(submitButtonFinder).onPressed,
          isNull,
        );

        // Open assignee dropdown and select Mock Agent One
        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Mock Agent One').last);
        await tester.pumpAndSettle();

        // Submit button should now be enabled
        expect(
          tester.widget<FilledButton>(submitButtonFinder).onPressed,
          isNotNull,
        );

        // Submit
        await tester.tap(submitButtonFinder);
        await tester.pumpAndSettle();

        // Modal closed
        expect(find.byType(BulkAssignLeadsDialog), findsNothing);

        // Repository was called
        expect(repository.assignLeadsCallCount, 1);
        expect(repository.lastAssignLeadsRequest?.assigneeId, 'agent-1');
        expect(repository.lastAssignLeadsRequest?.leadIds, [
          'lead-a',
          'lead-b',
        ]);

        // List refreshed and displays updated assignee names
        expect(find.text('Mock Agent One'), findsNWidgets(2));

        // Selection mode exited
        expect(
          find.byKey(const Key('lead_list_select_mode_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lead_list_cancel_selection_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'bulk failure and retry: retains selection and assignee on error, retries successfully',
      (tester) async {
        repository.leads = [
          const Lead(
            id: 'lead-a',
            name: 'Lead Alpha',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
        ];
        repository.assignLeadsFailureCount = 1;

        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        // Select Lead Alpha and open dialog
        await tester.tap(find.byKey(const Key('lead_list_select_mode_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-a')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_list_assign_leads_button')),
        );
        await tester.pumpAndSettle();

        // Select assignee
        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        // Submit (fails on first attempt)
        await tester.tap(
          find.byKey(const Key('bulk_assign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Dialog remains open, safe error displayed
        expect(find.byType(BulkAssignLeadsDialog), findsOneWidget);
        expect(
          find.byKey(const Key('bulk_assign_dialog_error')),
          findsOneWidget,
        );
        expect(
          find.text('Unable to assign the selected Leads.'),
          findsOneWidget,
        );
        expect(find.text('Mock Agent Two'), findsWidgets);

        // Retry submission (succeeds)
        await tester.tap(
          find.byKey(const Key('bulk_assign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BulkAssignLeadsDialog), findsNothing);
        expect(repository.assignLeadsCallCount, 2);
        expect(find.text('Mock Agent Two'), findsOneWidget);
      },
    );

    testWidgets(
      'pending submission blocks back navigation and barrier dismiss',
      (tester) async {
        repository.leads = [
          const Lead(
            id: 'lead-a',
            name: 'Lead Alpha',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
        ];
        repository.assignLeadsCompleter = Completer<void>();

        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        // Select and open dialog
        await tester.tap(find.byKey(const Key('lead_list_select_mode_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-a')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('lead_list_assign_leads_button')),
        );
        await tester.pumpAndSettle();

        // Choose assignee and submit
        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent One').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('bulk_assign_dialog_submit_button')),
        );
        await tester.pump(); // Start async submission

        // Cancel button is disabled while submitting
        final cancelButtonFinder = find.byKey(
          const Key('bulk_assign_dialog_cancel_button'),
        );
        expect(tester.widget<TextButton>(cancelButtonFinder).onPressed, isNull);

        // Attempt system back pop
        final didPop = await tester.binding.handlePopRoute();
        expect(didPop, isTrue);
        await tester.pump();

        // Dialog must remain open
        expect(find.byType(BulkAssignLeadsDialog), findsOneWidget);

        // Complete repository submission
        repository.assignLeadsCompleter!.complete();
        await tester.pumpAndSettle();

        // Dialog now closes and list refreshes
        expect(find.byType(BulkAssignLeadsDialog), findsNothing);
        expect(find.text('Mock Agent One'), findsOneWidget);
      },
    );

    testWidgets(
      'defensive guard rejects batch containing already assigned leads',
      (tester) async {
        // Direct test of BulkAssignLeadsDialog with an already assigned lead
        final assignedLead = const Lead(
          id: 'already-assigned',
          name: 'Assigned Lead',
          status: LeadStatus('Sample New'),
          source: LeadSource.manual,
          assignedUserId: 'agent-1',
          assignedUserName: 'Mock Agent One',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BulkAssignLeadsDialog(
                leads: [assignedLead],
                repository: repository,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Dialog shows defensive error and disables submit
        expect(
          find.text('One or more selected Leads are already assigned.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('bulk_assign_dialog_submit_button')),
              )
              .onPressed,
          isNull,
        );
        expect(repository.assignLeadsCallCount, 0);
      },
    );

    testWidgets('query change (search, sort, pagination) clears selection', (
      tester,
    ) async {
      repository.leads = [
        const Lead(
          id: 'lead-1',
          name: 'Lead One',
          status: LeadStatus('Sample New'),
          source: LeadSource.manual,
          assignedUserId: null,
        ),
        const Lead(
          id: 'lead-2',
          name: 'Lead Two',
          status: LeadStatus('Sample New'),
          source: LeadSource.manual,
          assignedUserId: null,
        ),
      ];

      final cubit = LeadListCubit(repository);
      await cubit.loadLeads();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      // Enter selection mode and select lead-1
      await tester.tap(find.byKey(const Key('lead_list_select_mode_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-1')));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      // Perform search query change
      await tester.enterText(find.byType(TextField), 'Search Term');
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();

      // Selection must be cleared
      expect(find.text('0 selected'), findsOneWidget);
    });

    testWidgets(
      'unassigned filter query semantics: assigned leads disappear from unassigned view upon refresh',
      (tester) async {
        repository.filterByQuery = true;
        repository.leads = [
          const Lead(
            id: 'lead-1',
            name: 'Lead One',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
          const Lead(
            id: 'lead-2',
            name: 'Lead Two',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
        ];

        final filterCubit = LeadFilterCubit(repository);
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads(query: const LeadQuery(isAssigned: false));

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, filterCubit: filterCubit),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lead One'), findsOneWidget);
        expect(find.text('Lead Two'), findsOneWidget);

        // Enter selection mode and select both
        await tester.tap(find.byKey(const Key('lead_list_select_mode_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-2')));
        await tester.pumpAndSettle();

        expect(find.text('2 selected'), findsOneWidget);

        // Assign to Mock Agent One
        await tester.tap(
          find.byKey(const Key('lead_list_assign_leads_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent One').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('bulk_assign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Both leads are now assigned in repository, so with AssignmentFilter.unassigned active,
        // repository getLeads returns 0 matching items.
        expect(find.text('Lead One'), findsNothing);
        expect(find.text('Lead Two'), findsNothing);
        expect(find.text('No leads match these filters'), findsOneWidget);
      },
    );

    testWidgets(
      'normal navigation regression: tapping lead outside selection mode opens details',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        repository.leads = [
          const Lead(
            id: 'lead-1',
            name: 'Lead One',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
        ];

        Lead? viewedLead;
        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(
          buildTestWidget(
            cubit: cubit,
            size: const Size(360, 640),
            onViewLead: (lead) => viewedLead = lead,
          ),
        );
        await tester.pumpAndSettle();

        // Tap View button outside selection mode
        await tester.tap(find.text('View'));
        await tester.pumpAndSettle();

        expect(viewedLead, isNotNull);
        expect(viewedLead?.id, 'lead-1');
      },
    );

    testWidgets(
      'responsive layouts (320x568, 360x640, 768x1024, 1200x800) and dark theme render without overflow',
      (tester) async {
        repository.leads = [
          const Lead(
            id: 'lead-1',
            name: 'Lead One',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
          const Lead(
            id: 'lead-2',
            name: 'Lead Two',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: 'agent-1',
            assignedUserName: 'Mock Agent One',
          ),
        ];

        final sizes = [
          const Size(320, 568),
          const Size(360, 640),
          const Size(768, 1024),
          const Size(1200, 800),
        ];

        for (final size in sizes) {
          final cubit = LeadListCubit(repository);
          await cubit.loadLeads();

          await tester.pumpWidget(
            buildTestWidget(cubit: cubit, size: size, theme: ThemeData.dark()),
          );
          await tester.pumpAndSettle();

          // Enter selection mode
          await tester.tap(
            find.byKey(const Key('lead_list_select_mode_button')),
          );
          await tester.pumpAndSettle();

          // Check selection mode UI renders cleanly
          expect(find.text('0 selected'), findsOneWidget);

          // Exit selection mode
          await tester.tap(
            find.byKey(const Key('lead_list_cancel_selection_button')),
          );
          await tester.pumpAndSettle();
        }
      },
    );
  });

  group('LeadListScreen - L5.4 Dashboard Manual Lead Distribution Integration', () {
    testWidgets(
      'distribution mode starts in selection mode with Unassigned filter invariant and locked chip',
      (tester) async {
        repository.filterByQuery = true;
        repository.leads = [
          const Lead(
            id: 'lead-1',
            name: 'Unassigned One',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
          const Lead(
            id: 'lead-2',
            name: 'Assigned Two',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: 'agent-1',
            assignedUserName: 'Mock Agent One',
          ),
        ];

        final cubit = LeadListCubit(
          repository,
          initialQuery: const LeadQuery(isAssigned: false),
        );
        await cubit.loadLeads();

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDistributionMode: true),
        );
        await tester.pumpAndSettle();

        // 1. Selection mode is active immediately
        expect(find.text('0 selected'), findsOneWidget);
        expect(
          find.byKey(const Key('lead_list_cancel_selection_button')),
          findsOneWidget,
        );

        // 2. Only unassigned lead is candidate (assigned lead is filtered out)
        expect(find.text('Unassigned One'), findsOneWidget);
        expect(find.text('Assigned Two'), findsNothing);

        // 3. Selection of candidate works
        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-1')));
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);

        // 4. Cancel selection mode shows "Distribute Leads" AppBar
        await tester.tap(
          find.byKey(const Key('lead_list_cancel_selection_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Distribute Leads'), findsOneWidget);
        expect(
          find.byKey(const Key('lead_list_select_mode_button')),
          findsOneWidget,
        );

        // 5. Active filter chip for Unassigned is locked
        expect(
          find.byKey(const Key('active_filter_assignment_chip')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('active_filters_clear_all')), findsNothing);
      },
    );

    testWidgets(
      'distribution context search preserves isAssigned = false invariant',
      (tester) async {
        repository.filterByQuery = true;
        repository.leads = [
          const Lead(
            id: 'lead-1',
            name: 'Alice Unassigned',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
          const Lead(
            id: 'lead-2',
            name: 'Bob Unassigned',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
          const Lead(
            id: 'lead-3',
            name: 'Alice Assigned',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: 'agent-1',
            assignedUserName: 'Mock Agent One',
          ),
        ];

        final cubit = LeadListCubit(
          repository,
          initialQuery: const LeadQuery(isAssigned: false),
        );
        await cubit.loadLeads();

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDistributionMode: true),
        );
        await tester.pumpAndSettle();

        // Exit selection mode to interact with search field
        await tester.tap(
          find.byKey(const Key('lead_list_cancel_selection_button')),
        );
        await tester.pumpAndSettle();

        // Search for 'Alice'
        await tester.enterText(find.byType(TextField), 'Alice');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        // Alice Unassigned is visible, Alice Assigned never appears
        expect(find.text('Alice Unassigned'), findsOneWidget);
        expect(find.text('Bob Unassigned'), findsNothing);
        expect(find.text('Alice Assigned'), findsNothing);

        // Clearing search restores Unassigned leads only
        await tester.tap(find.byTooltip('Clear Search'));
        await tester.pumpAndSettle();

        expect(find.text('Alice Unassigned'), findsOneWidget);
        expect(find.text('Bob Unassigned'), findsOneWidget);
        expect(find.text('Alice Assigned'), findsNothing);
      },
    );

    testWidgets(
      'filter modal locks assignment to Unassigned in distribution mode',
      (tester) async {
        repository.filterByQuery = true;
        repository.leads = [
          const Lead(
            id: 'lead-1',
            name: 'Lead One',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
        ];

        final cubit = LeadListCubit(
          repository,
          initialQuery: const LeadQuery(isAssigned: false),
        );
        await cubit.loadLeads();

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDistributionMode: true),
        );
        await tester.pumpAndSettle();

        // Exit selection mode and open filters
        await tester.tap(
          find.byKey(const Key('lead_list_cancel_selection_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_filter_button')));
        await tester.pumpAndSettle();

        // Locked notice is visible
        expect(
          find.text('Locked to Unassigned in distribution mode.'),
          findsOneWidget,
        );

        // Radio tiles for All/Assigned/Unassigned are hidden
        expect(find.byKey(const Key('filter_radio_all')), findsNothing);
        expect(find.byKey(const Key('filter_radio_assigned')), findsNothing);
        expect(find.byKey(const Key('filter_radio_unassigned')), findsNothing);
        expect(find.byKey(const Key('filter_assignee_dropdown')), findsNothing);

        // Apply filters preserves isAssigned = false
        await tester.tap(find.byKey(const Key('filter_apply_button')));
        await tester.pumpAndSettle();

        expect(cubit.currentQuery.isAssigned, isFalse);
      },
    );

    testWidgets(
      'empty distribution state shows truthful message and disabled bulk action',
      (tester) async {
        repository.filterByQuery = true;
        repository.leads = [
          const Lead(
            id: 'lead-1',
            name: 'Assigned Lead',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: 'agent-1',
            assignedUserName: 'Mock Agent One',
          ),
        ];

        final cubit = LeadListCubit(
          repository,
          initialQuery: const LeadQuery(isAssigned: false),
        );
        await cubit.loadLeads();

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDistributionMode: true),
        );
        await tester.pumpAndSettle();

        expect(find.text('No unassigned leads available'), findsOneWidget);
        expect(
          find.text('All leads have been assigned or no leads are available.'),
          findsOneWidget,
        );

        final assignButtonFinder = find.byKey(
          const Key('lead_list_assign_leads_button'),
        );
        expect(
          tester.widget<FilledButton>(assignButtonFinder).onPressed,
          isNull,
        );
      },
    );

    testWidgets(
      'multiple batches in one session: selection mode remains active and assigns sequentially',
      (tester) async {
        repository.filterByQuery = true;
        repository.leads = [
          const Lead(
            id: 'lead-1',
            name: 'Batch Alpha',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
          const Lead(
            id: 'lead-2',
            name: 'Batch Beta',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
        ];

        final cubit = LeadListCubit(
          repository,
          initialQuery: const LeadQuery(isAssigned: false),
        );
        await cubit.loadLeads();

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDistributionMode: true),
        );
        await tester.pumpAndSettle();

        // 1. Select Batch Alpha
        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-1')));
        await tester.pumpAndSettle();

        // Assign Batch Alpha
        await tester.tap(
          find.byKey(const Key('lead_list_assign_leads_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent One').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('bulk_assign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Batch Alpha disappeared; Batch Beta is still available
        expect(find.text('Batch Alpha'), findsNothing);
        expect(find.text('Batch Beta'), findsOneWidget);

        // Selection mode remained active (key feature for multiple distribution batches!)
        expect(find.text('0 selected'), findsOneWidget);

        // 2. Select Batch Beta
        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-2')));
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);

        // Assign Batch Beta
        await tester.tap(
          find.byKey(const Key('lead_list_assign_leads_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('bulk_assign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Both assigned; list is now empty
        expect(find.text('Batch Beta'), findsNothing);
        expect(find.text('No unassigned leads available'), findsOneWidget);
        expect(repository.assignLeadsCallCount, 2);
      },
    );

    testWidgets(
      'responsive layouts and dark theme render distribution mode without overflow',
      (tester) async {
        repository.filterByQuery = true;
        repository.leads = [
          const Lead(
            id: 'lead-1',
            name: 'Responsive Lead',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
            assignedUserId: null,
          ),
        ];

        final sizes = [
          const Size(320, 568),
          const Size(360, 640),
          const Size(768, 1024),
          const Size(1200, 800),
        ];

        for (final size in sizes) {
          final cubit = LeadListCubit(
            repository,
            initialQuery: const LeadQuery(isAssigned: false),
          );
          await cubit.loadLeads();

          await tester.pumpWidget(
            buildTestWidget(
              cubit: cubit,
              size: size,
              theme: ThemeData.dark(),
              isDistributionMode: true,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('0 selected'), findsOneWidget);
        }
      },
    );
  });
}
