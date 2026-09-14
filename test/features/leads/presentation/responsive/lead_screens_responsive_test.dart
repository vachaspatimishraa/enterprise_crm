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
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_dashboard_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_details_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_form_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_list_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/add_lead_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/edit_lead_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_dashboard_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_details_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements LeadRepository {
  final List<Lead> sampleLeads;

  _FakeRepository({required this.sampleLeads});

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async =>
      LeadPage(
        items: sampleLeads,
        currentPage: 1,
        pageSize: 20,
        totalItems: sampleLeads.length,
        hasNext: false,
      );

  @override
  Future<LeadSummary> getLeadSummary() async => LeadSummary(
    totalLeads: sampleLeads.length,
    assignedLeads: sampleLeads.where((l) => l.isAssigned).length,
    unassignedLeads: sampleLeads.where((l) => !l.isAssigned).length,
    manualLeads: sampleLeads.where((l) => l.source == LeadSource.manual).length,
    excelLeads: sampleLeads.where((l) => l.source == LeadSource.excel).length,
    csvLeads: sampleLeads.where((l) => l.source == LeadSource.csv).length,
  );

  @override
  Future<Lead?> getLeadById(String leadId) async => sampleLeads
      .cast<Lead?>()
      .firstWhere((l) => l?.id == leadId, orElse: () => null);

  @override
  Future<Lead> createLead(CreateLeadInput input) async => Lead(
    id: 'created-id',
    name: input.draft.name,
    phone: input.draft.phone,
    email: input.draft.email,
    source: input.draft.source ?? LeadSource.manual,
    status: input.draft.status,
  );

  @override
  Future<Lead> updateLead(UpdateLeadInput input) async => Lead(
    id: input.leadId,
    name: input.draft.name,
    phone: input.draft.phone,
    email: input.draft.email,
    source: input.draft.source ?? LeadSource.manual,
    status: input.draft.status,
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
}

void main() {
  final sampleLeads = [
    const Lead(
      id: 'lead-1',
      name:
          'Long Name Corporation With Extremely Verbose Customer Title Contact',
      phone: '+91 9876543210-extension-1234',
      email:
          'very.long.enterprise.executive.email.address@company-domain.example.com',
      source: LeadSource.manual,
      status: LeadStatus('Enterprise Comprehensive Evaluation Phase'),
      assignedUserId: 'u1',
      assignedUserName: 'Senior Regional Portfolio Manager Specialist',
      createdAt: null,
      updatedAt: null,
    ),
    const Lead(
      id: 'lead-2',
      name: null,
      phone: null,
      email: null,
      source: LeadSource.excel,
      status: null,
      assignedUserId: null,
      assignedUserName: null,
      createdAt: null,
      updatedAt: null,
    ),
  ];

  late _FakeRepository repository;

  setUp(() {
    repository = _FakeRepository(sampleLeads: sampleLeads);
  });

  Widget wrapWithThemeAndSize({
    required Widget child,
    required Size size,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      themeMode: themeMode,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    );
  }

  const testBreakpoints = [
    Size(320, 568), // Compact mobile
    Size(360, 640), // Standard mobile
    Size(600, 800), // Breakpoint threshold
    Size(768, 1024), // Tablet portrait
    Size(1200, 800), // Desktop / Web wide
  ];

  group('L2.7 Responsive Review - LeadDashboardScreen', () {
    for (final size in testBreakpoints) {
      testWidgets('renders cleanly at ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final cubit = LeadDashboardCubit(repository);
        await cubit.loadDashboard();

        await tester.pumpWidget(
          wrapWithThemeAndSize(
            child: LeadDashboardScreen(cubit: cubit),
            size: size,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Overview & Summary'), findsOneWidget);
        expect(find.text('Total Leads'), findsOneWidget);
      });
    }
  });

  group('L2.7 Responsive Review - LeadListScreen', () {
    for (final size in testBreakpoints) {
      testWidgets('renders cleanly at ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final cubit = LeadListCubit(repository);
        await cubit.loadLeads();

        await tester.pumpWidget(
          wrapWithThemeAndSize(
            child: LeadListScreen(cubit: cubit),
            size: size,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Leads'), findsOneWidget);
      });
    }
  });

  group('L2.7 Responsive Review - LeadDetailsScreen', () {
    for (final size in testBreakpoints) {
      testWidgets('renders cleanly at ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final cubit = LeadDetailsCubit(repository);
        await cubit.loadLead('lead-1');

        await tester.pumpWidget(
          wrapWithThemeAndSize(
            child: LeadDetailsScreen(leadId: 'lead-1', cubit: cubit),
            size: size,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Basic Information'), findsOneWidget);
        expect(find.text('Contact Information'), findsOneWidget);
      });
    }
  });

  group('L2.7 Responsive Review - AddLeadScreen', () {
    for (final size in testBreakpoints) {
      testWidgets('renders cleanly at ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final cubit = LeadFormCubit(repository);

        await tester.pumpWidget(
          wrapWithThemeAndSize(
            child: AddLeadScreen(cubit: cubit),
            size: size,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Add Lead'), findsOneWidget);
        expect(find.text('Create Lead'), findsOneWidget);
      });
    }
  });

  group('L2.7 Responsive Review - EditLeadScreen', () {
    for (final size in testBreakpoints) {
      testWidgets('renders cleanly at ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final cubit = LeadFormCubit(repository);

        await tester.pumpWidget(
          wrapWithThemeAndSize(
            child: EditLeadScreen(lead: sampleLeads[0], cubit: cubit),
            size: size,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Edit Lead'), findsOneWidget);
        expect(find.text('Save Changes'), findsOneWidget);
      });
    }
  });

  group('L2.7 Theme Consistency - Dark Mode', () {
    testWidgets('all screens render cleanly in dark mode', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final formCubit = LeadFormCubit(repository);
      await tester.pumpWidget(
        wrapWithThemeAndSize(
          child: EditLeadScreen(lead: sampleLeads[0], cubit: formCubit),
          size: const Size(800, 600),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Lead Details'), findsOneWidget);
    });
  });
}
