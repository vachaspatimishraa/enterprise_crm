import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignee.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_dashboard_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadRepository implements LeadRepository {
  List<Lead> leads = [];
  bool shouldThrow = false;

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async {
    if (shouldThrow) throw Exception('Unable to load leads');
    return LeadPage(
      items: leads,
      currentPage: 1,
      pageSize: 100,
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
}

void main() {
  late _FakeLeadRepository repository;

  setUp(() {
    repository = _FakeLeadRepository();
  });

  Widget buildTestWidget({
    LeadDashboardCubit? cubit,
    VoidCallback? onViewLeads,
    VoidCallback? onAddLead,
    VoidCallback? onImportLeads,
    VoidCallback? onDistributeLeads,
    VoidCallback? onExportLeads,
    Size size = const Size(800, 600),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: LeadDashboardScreen(
          cubit: cubit,
          repository: cubit == null ? repository : null,
          onViewLeads: onViewLeads,
          onAddLead: onAddLead,
          onImportLeads: onImportLeads,
          onDistributeLeads: onDistributeLeads,
          onExportLeads: onExportLeads,
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
  });
}
