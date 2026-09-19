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
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_dashboard_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_dashboard_state.dart';
import 'package:enterprise_crm/features/leads/data/services/lead_export_file_saver.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_dashboard_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_import_workflow_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_list_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/services/lead_import_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadRepository implements LeadRepository {
  List<Lead> leads = [];
  bool shouldThrow = false;

  int assignLeadsCallCount = 0;

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async {
    if (shouldThrow) throw Exception('Unable to load leads');
    var filtered = List<Lead>.from(leads);
    if (query.isAssigned != null) {
      filtered = filtered
          .where((l) => l.isAssigned == query.isAssigned)
          .toList();
    }
    if (query.source != null) {
      filtered = filtered.where((l) => l.source == query.source).toList();
    }
    if (query.assignedUserId != null) {
      filtered = filtered
          .where((l) => l.assignedUserId == query.assignedUserId)
          .toList();
    }
    if (query.searchText != null && query.searchText!.isNotEmpty) {
      filtered = filtered
          .where(
            (l) =>
                l.name?.toLowerCase().contains(
                  query.searchText!.toLowerCase(),
                ) ??
                false,
          )
          .toList();
    }
    return LeadPage(
      items: filtered,
      currentPage: 1,
      pageSize: 100,
      totalItems: filtered.length,
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
  Future<void> assignLeads(LeadAssignmentRequest request) async {
    assignLeadsCallCount++;
    final updated = <Lead>[];
    for (final l in leads) {
      if (request.leadIds.contains(l.id)) {
        updated.add(
          l.copyWith(
            assignedUserId: request.assigneeId,
            assignedUserName: 'Agent ${request.assigneeId}',
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

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async => const [
    LeadAssignee(id: 'mock-agent-1', displayName: 'Mock Agent One'),
    LeadAssignee(id: 'mock-agent-2', displayName: 'Mock Agent Two'),
  ];

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
  Future<LeadSummary> getLeadSummary() async {
    if (shouldThrow) throw Exception('Unable to load leads');
    int assigned = 0;
    int unassigned = 0;
    int manual = 0;
    int excel = 0;
    int csv = 0;
    for (final l in leads) {
      if (l.isAssigned) {
        assigned++;
      } else {
        unassigned++;
      }
      switch (l.source) {
        case LeadSource.manual:
          manual++;
          break;
        case LeadSource.excel:
          excel++;
          break;
        case LeadSource.csv:
          csv++;
          break;
      }
    }
    return LeadSummary(
      totalLeads: leads.length,
      assignedLeads: assigned,
      unassignedLeads: unassigned,
      manualLeads: manual,
      excelLeads: excel,
      csvLeads: csv,
    );
  }
}

void main() {
  late _FakeLeadRepository repository;

  setUp(() {
    repository = _FakeLeadRepository();
  });

  Widget buildTestWidget({
    LeadDashboardCubit? cubit,
    VoidCallback? onViewLeads,
    void Function(LeadQuery query)? onNavigateToLeads,
    VoidCallback? onAddLead,
    VoidCallback? onImportLeads,
    VoidCallback? onDistributeLeads,
    VoidCallback? onExportLeads,
    LeadImportFilePicker? filePicker,
    LeadExportFileSaver? fileSaver,
    ThemeData? theme,
    Size size = const Size(1200, 800),
  }) {
    return MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: LeadDashboardScreen(
          cubit: cubit,
          repository: repository,
          onViewLeads: onViewLeads,
          onNavigateToLeads: onNavigateToLeads,
          onAddLead: onAddLead,
          onImportLeads: onImportLeads,
          onDistributeLeads: onDistributeLeads,
          onExportLeads: onExportLeads,
          filePicker: filePicker,
          fileSaver: fileSaver,
        ),
      ),
    );
  }

  group('LeadDashboardScreen', () {
    testWidgets('renders summary metrics correctly when loaded', (
      tester,
    ) async {
      repository.leads = [
        const Lead(
          id: '1',
          source: LeadSource.manual,
          assignedUserId: 'u1',
          assignedUserName: 'Agent 1',
        ),
        const Lead(id: '2', source: LeadSource.excel, assignedUserId: null),
      ];

      final cubit = LeadDashboardCubit(repository);
      await cubit.loadDashboard();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('Lead Management'), findsOneWidget);
      expect(find.text('Total Leads'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Assigned Leads'), findsOneWidget);
      expect(find.text('Unassigned Leads'), findsOneWidget);
      expect(find.text('Manual Leads'), findsOneWidget);
      expect(find.text('Excel Leads'), findsOneWidget);
      expect(find.text('CSV Leads'), findsOneWidget);

      // Verify quick action buttons exist
      expect(find.text('View Leads'), findsOneWidget);
      expect(find.text('Add Lead'), findsOneWidget);
      expect(find.text('Import Leads'), findsOneWidget);
      expect(find.text('Distribute Leads'), findsOneWidget);
      expect(find.text('Export Leads'), findsOneWidget);
    });

    testWidgets('renders empty state when zero leads exist', (tester) async {
      repository.leads = [];
      final cubit = LeadDashboardCubit(repository);
      await cubit.loadDashboard();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('No leads yet'), findsOneWidget);
      expect(
        find.text('Add a lead manually or import leads from Excel/CSV.'),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsOneWidget); // Add Lead button
      expect(
        find.byType(OutlinedButton),
        findsOneWidget,
      ); // Import Leads button
    });

    testWidgets('renders failure state on error with retry button', (
      tester,
    ) async {
      repository.shouldThrow = true;
      final cubit = LeadDashboardCubit(repository);
      await cubit.loadDashboard();

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load metrics'), findsOneWidget);
      expect(find.text('Unable to load leads'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('mobile layout (360x640) renders without overflow', (
      tester,
    ) async {
      repository.leads = [
        const Lead(
          id: '1',
          source: LeadSource.manual,
          assignedUserId: 'u1',
          assignedUserName: 'Agent 1',
        ),
      ];
      final cubit = LeadDashboardCubit(repository);
      await cubit.loadDashboard();

      await tester.pumpWidget(
        buildTestWidget(cubit: cubit, size: const Size(360, 640)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Overview & Summary'), findsOneWidget);
    });

    testWidgets('quick action callbacks trigger when tapped', (tester) async {
      bool viewTapped = false;
      bool addTapped = false;

      repository.leads = [const Lead(id: '1', source: LeadSource.manual)];
      final cubit = LeadDashboardCubit(repository);
      await cubit.loadDashboard();

      await tester.pumpWidget(
        buildTestWidget(
          cubit: cubit,
          onViewLeads: () => viewTapped = true,
          onAddLead: () => addTapped = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Leads'));
      await tester.pumpAndSettle();
      expect(viewTapped, isTrue);

      await tester.tap(find.text('Add Lead'));
      await tester.pumpAndSettle();
      expect(addTapped, isTrue);
    });

    testWidgets(
      'import quick action opens workflow and refreshes dashboard on success',
      (tester) async {
        repository.leads = [const Lead(id: '1', source: LeadSource.manual)];
        final cubit = LeadDashboardCubit(repository);
        await cubit.loadDashboard();

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Import Leads'));
        await tester.pumpAndSettle();

        expect(find.byType(LeadImportWorkflowScreen), findsOneWidget);

        // Simulate repository update and workflow pop true
        repository.leads = [
          const Lead(id: '1', source: LeadSource.manual),
          const Lead(id: '2', source: LeadSource.csv),
        ];

        Navigator.of(
          tester.element(find.byType(LeadImportWorkflowScreen)),
        ).pop(true);
        await tester.pumpAndSettle();

        expect(find.byType(LeadDashboardScreen), findsOneWidget);
        expect(cubit.state, isA<LeadDashboardLoaded>());
        expect((cubit.state as LeadDashboardLoaded).metrics.totalLeads, 2);
      },
    );

    testWidgets(
      'distribute leads quick action callback triggers when provided',
      (tester) async {
        bool distributeTapped = false;
        repository.leads = [const Lead(id: '1', source: LeadSource.manual)];
        final cubit = LeadDashboardCubit(repository);
        await cubit.loadDashboard();

        await tester.pumpWidget(
          buildTestWidget(
            cubit: cubit,
            onDistributeLeads: () => distributeTapped = true,
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Distribute Leads'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Distribute Leads'));
        await tester.pumpAndSettle();
        expect(distributeTapped, isTrue);
      },
    );

    testWidgets(
      'distribute leads fallback opens LeadListScreen in distribution mode and reloads dashboard when leads were assigned',
      (tester) async {
        repository.leads = [
          const Lead(id: '1', name: 'Lead 1', source: LeadSource.manual),
          const Lead(
            id: '2',
            name: 'Lead 2',
            source: LeadSource.manual,
            assignedUserId: 'agent-1',
            assignedUserName: 'Agent 1',
          ),
        ];
        final cubit = LeadDashboardCubit(repository);
        await cubit.loadDashboard();

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        expect((cubit.state as LeadDashboardLoaded).metrics.assignedLeads, 1);
        expect((cubit.state as LeadDashboardLoaded).metrics.unassignedLeads, 1);

        // Tap Distribute Leads
        await tester.ensureVisible(find.text('Distribute Leads'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Distribute Leads'));
        await tester.pumpAndSettle();

        // LeadListScreen opens in distribution mode
        final listScreenFinder = find.byType(LeadListScreen);
        expect(listScreenFinder, findsOneWidget);
        final listScreenWidget = tester.widget<LeadListScreen>(
          listScreenFinder,
        );
        expect(listScreenWidget.isDistributionMode, isTrue);

        // Simulate successful distribution and pop(true)
        repository.leads = [
          const Lead(
            id: '1',
            name: 'Lead 1',
            source: LeadSource.manual,
            assignedUserId: 'agent-2',
            assignedUserName: 'Agent 2',
          ),
          const Lead(
            id: '2',
            name: 'Lead 2',
            source: LeadSource.manual,
            assignedUserId: 'agent-1',
            assignedUserName: 'Agent 1',
          ),
        ];

        Navigator.of(tester.element(listScreenFinder)).pop(true);
        await tester.pumpAndSettle();

        // Dashboard is refreshed
        expect(find.byType(LeadDashboardScreen), findsOneWidget);
        expect(cubit.state, isA<LeadDashboardLoaded>());
        expect((cubit.state as LeadDashboardLoaded).metrics.assignedLeads, 2);
        expect((cubit.state as LeadDashboardLoaded).metrics.unassignedLeads, 0);
      },
    );

    testWidgets(
      'distribute leads fallback does not reload dashboard when cancelled with no assignment',
      (tester) async {
        repository.leads = [
          const Lead(id: '1', name: 'Lead 1', source: LeadSource.manual),
        ];
        final cubit = LeadDashboardCubit(repository);
        await cubit.loadDashboard();

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        final initialMetrics = (cubit.state as LeadDashboardLoaded).metrics;

        await tester.ensureVisible(find.text('Distribute Leads'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Distribute Leads'));
        await tester.pumpAndSettle();

        final listScreenFinder = find.byType(LeadListScreen);
        expect(listScreenFinder, findsOneWidget);

        // Pop with false (no assignment was made)
        Navigator.of(tester.element(listScreenFinder)).pop(false);
        await tester.pumpAndSettle();

        expect(find.byType(LeadDashboardScreen), findsOneWidget);
        expect((cubit.state as LeadDashboardLoaded).metrics, initialMetrics);
      },
    );

    group('FIX 3 — All 6 Dashboard Summary Cards Clickable', () {
      final leadManualAssigned = const Lead(
        id: 'lead-1',
        name: 'Manual Assigned Lead',
        source: LeadSource.manual,
        assignedUserId: 'u1',
        assignedUserName: 'Agent 1',
      );
      final leadManualUnassigned = const Lead(
        id: 'lead-2',
        name: 'Manual Unassigned Lead',
        source: LeadSource.manual,
      );
      final leadExcelAssigned = const Lead(
        id: 'lead-3',
        name: 'Excel Assigned Lead',
        source: LeadSource.excel,
        assignedUserId: 'u2',
        assignedUserName: 'Agent 2',
      );
      final leadExcelUnassigned = const Lead(
        id: 'lead-4',
        name: 'Excel Unassigned Lead',
        source: LeadSource.excel,
      );
      final leadCsvAssigned = const Lead(
        id: 'lead-5',
        name: 'CSV Assigned Lead',
        source: LeadSource.csv,
        assignedUserId: 'u3',
        assignedUserName: 'Agent 3',
      );
      final leadCsvUnassigned = const Lead(
        id: 'lead-6',
        name: 'CSV Unassigned Lead',
        source: LeadSource.csv,
      );

      final fixtureLeads = [
        leadManualAssigned,
        leadManualUnassigned,
        leadExcelAssigned,
        leadExcelUnassigned,
        leadCsvAssigned,
        leadCsvUnassigned,
      ];

      testWidgets(
        'tapping Total Leads card navigates to LeadList with default query (all leads)',
        (tester) async {
          repository.leads = fixtureLeads;
          final cubit = LeadDashboardCubit(repository);
          await cubit.loadDashboard();

          await tester.pumpWidget(buildTestWidget(cubit: cubit));
          await tester.pumpAndSettle();

          final totalCard = find.byKey(const Key('dashboard_card_total_leads'));
          expect(totalCard, findsOneWidget);
          await tester.tap(totalCard);
          await tester.pumpAndSettle();

          expect(find.byType(LeadListScreen), findsOneWidget);
          expect(find.text('Manual Assigned Lead'), findsOneWidget);
          expect(find.text('Manual Unassigned Lead'), findsOneWidget);
          expect(find.text('Excel Assigned Lead'), findsOneWidget);
          expect(find.text('Excel Unassigned Lead'), findsOneWidget);
          expect(find.text('CSV Assigned Lead'), findsOneWidget);
          expect(find.text('CSV Unassigned Lead'), findsOneWidget);
        },
      );

      testWidgets(
        'tapping Assigned Leads card navigates to LeadList with isAssigned = true',
        (tester) async {
          repository.leads = fixtureLeads;
          final cubit = LeadDashboardCubit(repository);
          await cubit.loadDashboard();

          await tester.pumpWidget(buildTestWidget(cubit: cubit));
          await tester.pumpAndSettle();

          final assignedCard = find.byKey(
            const Key('dashboard_card_assigned_leads'),
          );
          expect(assignedCard, findsOneWidget);
          await tester.tap(assignedCard);
          await tester.pumpAndSettle();

          expect(find.byType(LeadListScreen), findsOneWidget);
          // Only assigned leads visible
          expect(find.text('Manual Assigned Lead'), findsOneWidget);
          expect(find.text('Excel Assigned Lead'), findsOneWidget);
          expect(find.text('CSV Assigned Lead'), findsOneWidget);
          // Unassigned leads not visible
          expect(find.text('Manual Unassigned Lead'), findsNothing);
          expect(find.text('Excel Unassigned Lead'), findsNothing);
          expect(find.text('CSV Unassigned Lead'), findsNothing);

          // Visible filter reflects Assigned
          expect(find.text('Assigned'), findsWidgets);
        },
      );

      testWidgets(
        'tapping Unassigned Leads card navigates to LeadList with isAssigned = false',
        (tester) async {
          repository.leads = fixtureLeads;
          final cubit = LeadDashboardCubit(repository);
          await cubit.loadDashboard();

          await tester.pumpWidget(buildTestWidget(cubit: cubit));
          await tester.pumpAndSettle();

          final unassignedCard = find.byKey(
            const Key('dashboard_card_unassigned_leads'),
          );
          expect(unassignedCard, findsOneWidget);
          await tester.tap(unassignedCard);
          await tester.pumpAndSettle();

          expect(find.byType(LeadListScreen), findsOneWidget);
          // Only unassigned leads visible
          expect(find.text('Manual Unassigned Lead'), findsOneWidget);
          expect(find.text('Excel Unassigned Lead'), findsOneWidget);
          expect(find.text('CSV Unassigned Lead'), findsOneWidget);
          // Assigned leads not visible
          expect(find.text('Manual Assigned Lead'), findsNothing);
          expect(find.text('Excel Assigned Lead'), findsNothing);
          expect(find.text('CSV Assigned Lead'), findsNothing);

          // Visible filter reflects Unassigned
          expect(find.text('Unassigned'), findsWidgets);
        },
      );

      testWidgets(
        'tapping Manual Leads card navigates to LeadList with source = manual',
        (tester) async {
          repository.leads = fixtureLeads;
          final cubit = LeadDashboardCubit(repository);
          await cubit.loadDashboard();

          await tester.pumpWidget(buildTestWidget(cubit: cubit));
          await tester.pumpAndSettle();

          final manualCard = find.byKey(
            const Key('dashboard_card_manual_leads'),
          );
          expect(manualCard, findsOneWidget);
          await tester.tap(manualCard);
          await tester.pumpAndSettle();

          expect(find.byType(LeadListScreen), findsOneWidget);
          // Only manual leads visible
          expect(find.text('Manual Assigned Lead'), findsOneWidget);
          expect(find.text('Manual Unassigned Lead'), findsOneWidget);
          // Excel and CSV leads not visible
          expect(find.text('Excel Assigned Lead'), findsNothing);
          expect(find.text('CSV Assigned Lead'), findsNothing);

          // Visible filter reflects Manual
          expect(find.text('Manual'), findsWidgets);
        },
      );

      testWidgets(
        'tapping Excel Leads card navigates to LeadList with source = excel',
        (tester) async {
          repository.leads = fixtureLeads;
          final cubit = LeadDashboardCubit(repository);
          await cubit.loadDashboard();

          await tester.pumpWidget(buildTestWidget(cubit: cubit));
          await tester.pumpAndSettle();

          final excelCard = find.byKey(const Key('dashboard_card_excel_leads'));
          expect(excelCard, findsOneWidget);
          await tester.tap(excelCard);
          await tester.pumpAndSettle();

          expect(find.byType(LeadListScreen), findsOneWidget);
          // Only Excel leads visible
          expect(find.text('Excel Assigned Lead'), findsOneWidget);
          expect(find.text('Excel Unassigned Lead'), findsOneWidget);
          // Manual and CSV leads not visible
          expect(find.text('Manual Assigned Lead'), findsNothing);
          expect(find.text('CSV Assigned Lead'), findsNothing);

          // Visible filter reflects Excel
          expect(find.text('Excel'), findsWidgets);
        },
      );

      testWidgets(
        'tapping CSV Leads card navigates to LeadList with source = csv',
        (tester) async {
          repository.leads = fixtureLeads;
          final cubit = LeadDashboardCubit(repository);
          await cubit.loadDashboard();

          await tester.pumpWidget(buildTestWidget(cubit: cubit));
          await tester.pumpAndSettle();

          final csvCard = find.byKey(const Key('dashboard_card_csv_leads'));
          expect(csvCard, findsOneWidget);
          await tester.tap(csvCard);
          await tester.pumpAndSettle();

          expect(find.byType(LeadListScreen), findsOneWidget);
          // Only CSV leads visible
          expect(find.text('CSV Assigned Lead'), findsOneWidget);
          expect(find.text('CSV Unassigned Lead'), findsOneWidget);
          // Manual and Excel leads not visible
          expect(find.text('Manual Assigned Lead'), findsNothing);
          expect(find.text('Excel Assigned Lead'), findsNothing);

          // Visible filter reflects CSV
          expect(find.text('CSV'), findsWidgets);
        },
      );

      testWidgets(
        'onNavigateToLeads callback receives exact query for all six cards',
        (tester) async {
          repository.leads = fixtureLeads;
          final cubit = LeadDashboardCubit(repository);
          await cubit.loadDashboard();

          final receivedQueries = <LeadQuery>[];
          await tester.pumpWidget(
            buildTestWidget(
              cubit: cubit,
              onNavigateToLeads: (q) => receivedQueries.add(q),
            ),
          );
          await tester.pumpAndSettle();

          // 1. Total Leads
          await tester.tap(find.byKey(const Key('dashboard_card_total_leads')));
          await tester.pumpAndSettle();
          expect(receivedQueries.last, const LeadQuery());

          // 2. Assigned Leads
          await tester.tap(
            find.byKey(const Key('dashboard_card_assigned_leads')),
          );
          await tester.pumpAndSettle();
          expect(receivedQueries.last, const LeadQuery(isAssigned: true));

          // 3. Unassigned Leads
          await tester.tap(
            find.byKey(const Key('dashboard_card_unassigned_leads')),
          );
          await tester.pumpAndSettle();
          expect(receivedQueries.last, const LeadQuery(isAssigned: false));

          // 4. Manual Leads
          await tester.tap(
            find.byKey(const Key('dashboard_card_manual_leads')),
          );
          await tester.pumpAndSettle();
          expect(
            receivedQueries.last,
            const LeadQuery(source: LeadSource.manual),
          );

          // 5. Excel Leads
          await tester.tap(find.byKey(const Key('dashboard_card_excel_leads')));
          await tester.pumpAndSettle();
          expect(
            receivedQueries.last,
            const LeadQuery(source: LeadSource.excel),
          );

          // 6. CSV Leads
          await tester.tap(find.byKey(const Key('dashboard_card_csv_leads')));
          await tester.pumpAndSettle();
          expect(receivedQueries.last, const LeadQuery(source: LeadSource.csv));

          expect(receivedQueries.length, 6);
        },
      );

      testWidgets(
        'search after navigating from Excel card filters within Excel leads and preserves source filter',
        (tester) async {
          repository.leads = fixtureLeads;
          final cubit = LeadDashboardCubit(repository);
          await cubit.loadDashboard();

          await tester.pumpWidget(buildTestWidget(cubit: cubit));
          await tester.pumpAndSettle();

          // Tap Excel Leads
          await tester.tap(find.byKey(const Key('dashboard_card_excel_leads')));
          await tester.pumpAndSettle();

          expect(find.byType(LeadListScreen), findsOneWidget);
          expect(find.text('Excel Assigned Lead'), findsOneWidget);
          expect(find.text('Excel Unassigned Lead'), findsOneWidget);

          // Search for "Excel Assigned"
          final searchInput = find.byType(TextField);
          expect(searchInput, findsOneWidget);
          await tester.enterText(searchInput, 'Excel Assigned');
          await tester.pumpAndSettle();

          final searchIcon = find.byTooltip('Search');
          await tester.tap(searchIcon);
          await tester.pumpAndSettle();

          // Only Excel Assigned Lead matches both source=excel and search=Assigned
          expect(find.text('Excel Assigned Lead'), findsOneWidget);
          expect(find.text('Excel Unassigned Lead'), findsNothing);
          expect(find.text('Manual Assigned Lead'), findsNothing);
        },
      );

      testWidgets(
        'back from LeadList to Dashboard preserves exact summary metrics without mutation',
        (tester) async {
          repository.leads = fixtureLeads;
          final cubit = LeadDashboardCubit(repository);
          await cubit.loadDashboard();

          await tester.pumpWidget(buildTestWidget(cubit: cubit));
          await tester.pumpAndSettle();

          final initialMetrics = (cubit.state as LeadDashboardLoaded).metrics;

          // Navigate to CSV Leads
          await tester.tap(find.byKey(const Key('dashboard_card_csv_leads')));
          await tester.pumpAndSettle();

          expect(find.byType(LeadListScreen), findsOneWidget);

          // Pop route back to Dashboard
          Navigator.of(tester.element(find.byType(LeadListScreen))).pop();
          await tester.pumpAndSettle();

          expect(find.byType(LeadDashboardScreen), findsOneWidget);
          expect(cubit.state, isA<LeadDashboardLoaded>());
          final finalMetrics = (cubit.state as LeadDashboardLoaded).metrics;
          expect(finalMetrics.totalLeads, initialMetrics.totalLeads);
          expect(finalMetrics.assignedLeads, initialMetrics.assignedLeads);
          expect(finalMetrics.unassignedLeads, initialMetrics.unassignedLeads);
          expect(finalMetrics.manualLeads, initialMetrics.manualLeads);
          expect(finalMetrics.excelLeads, initialMetrics.excelLeads);
          expect(finalMetrics.csvLeads, initialMetrics.csvLeads);
        },
      );

      testWidgets(
        'responsive layouts (320x568, 360x640, 768x1024, 1200x800) render clickable cards without overflow',
        (tester) async {
          repository.leads = fixtureLeads;
          final cubit = LeadDashboardCubit(repository);
          await cubit.loadDashboard();

          final sizes = [
            const Size(320, 568),
            const Size(360, 640),
            const Size(768, 1024),
            const Size(1200, 800),
          ];

          for (final size in sizes) {
            await tester.pumpWidget(buildTestWidget(cubit: cubit, size: size));
            await tester.pumpAndSettle();

            expect(
              find.byKey(const Key('dashboard_card_total_leads')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('dashboard_card_assigned_leads')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('dashboard_card_unassigned_leads')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('dashboard_card_manual_leads')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('dashboard_card_excel_leads')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('dashboard_card_csv_leads')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }
        },
      );

      testWidgets(
        'dark theme renders all six clickable summary cards cleanly',
        (tester) async {
          repository.leads = fixtureLeads;
          final cubit = LeadDashboardCubit(repository);
          await cubit.loadDashboard();

          await tester.pumpWidget(
            buildTestWidget(
              cubit: cubit,
              theme: ThemeData.dark(useMaterial3: true),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('dashboard_card_total_leads')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('dashboard_card_assigned_leads')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('dashboard_card_unassigned_leads')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('dashboard_card_manual_leads')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('dashboard_card_excel_leads')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('dashboard_card_csv_leads')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    });
  });
}
