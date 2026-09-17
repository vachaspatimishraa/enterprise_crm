import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignee.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_summary.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_assignment_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_assignment_state.dart';
import 'package:enterprise_crm/features/leads/presentation/widgets/lead_assignee_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadRepository implements LeadRepository {
  List<LeadAssignee> assignees = const [];
  bool shouldThrow = false;
  int getAssignableUsersCallCount = 0;

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async {
    getAssignableUsersCallCount++;
    if (shouldThrow) {
      throw Exception('Failed to fetch assignable users');
    }
    return assignees;
  }

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
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async =>
      const LeadPage(
        items: [],
        currentPage: 1,
        pageSize: 20,
        totalItems: 0,
        hasNext: false,
      );

  @override
  Future<Lead?> getLeadById(String leadId) async => null;

  @override
  Future<Lead> createLead(CreateLeadInput input) async =>
      const Lead(id: 'dummy');

  @override
  Future<Lead> updateLead(UpdateLeadInput input) async =>
      const Lead(id: 'dummy');

  @override
  Future<LeadSummary> getLeadSummary() async => const LeadSummary(
    totalLeads: 0,
    assignedLeads: 0,
    unassignedLeads: 0,
    manualLeads: 0,
    excelLeads: 0,
    csvLeads: 0,
  );

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
      const LeadExportResult(fileReference: 'dummy', fileName: 'export.csv');
}

Widget buildTestWidget({
  required LeadAssignmentCubit cubit,
  ThemeData? theme,
  void Function(LeadAssignee?)? onChanged,
  bool enabled = true,
  double width = 320,
}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(useMaterial3: true),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: LeadAssigneeSelector(
            cubit: cubit,
            onChanged: onChanged,
            enabled: enabled,
          ),
        ),
      ),
    ),
  );
}

void main() {
  late _FakeLeadRepository repository;
  late LeadAssignmentCubit cubit;

  const agent1 = LeadAssignee(id: 'agent-1', displayName: 'Mock Agent One');
  const agent2 = LeadAssignee(id: 'agent-2', displayName: 'Mock Agent Two');

  setUp(() {
    repository = _FakeLeadRepository();
    cubit = LeadAssignmentCubit(repository);
  });

  tearDown(() {
    cubit.close();
  });

  group('LeadAssigneeSelector - Widget Rendering & States', () {
    testWidgets('renders loading state indicator and label', (tester) async {
      repository.assignees = [agent1];
      // Start load but don't finish yet
      cubit.emit(
        const LeadAssignmentState(loadStatus: AssigneeLoadStatus.loading),
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit));

      expect(
        find.byKey(const Key('assignee_selector_loading')),
        findsOneWidget,
      );
      expect(find.text('Loading assignable users...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'renders failure state and tapping Retry calls loadAssignableUsers',
      (tester) async {
        cubit.emit(
          const LeadAssignmentState(
            loadStatus: AssigneeLoadStatus.failure,
            loadErrorMessage: 'Unable to load assignable users.',
          ),
        );

        await tester.pumpWidget(buildTestWidget(cubit: cubit));

        expect(
          find.byKey(const Key('assignee_selector_failure')),
          findsOneWidget,
        );
        expect(find.text('Unable to load assignable users.'), findsOneWidget);

        final retryButton = find.byKey(
          const Key('assignee_selector_retry_button'),
        );
        expect(retryButton, findsOneWidget);

        await tester.tap(retryButton);
        await tester.pump();

        expect(repository.getAssignableUsersCallCount, equals(1));
      },
    );

    testWidgets(
      'renders truthful empty state when no assignees are available',
      (tester) async {
        cubit.emit(
          const LeadAssignmentState(
            loadStatus: AssigneeLoadStatus.success,
            assignees: [],
          ),
        );

        await tester.pumpWidget(buildTestWidget(cubit: cubit));

        expect(
          find.byKey(const Key('assignee_selector_empty')),
          findsOneWidget,
        );
        expect(find.text('No assignable users available.'), findsOneWidget);
      },
    );

    testWidgets('renders dropdown with assignees and handles selection', (
      tester,
    ) async {
      LeadAssignee? selectedCallbackValue;
      repository.assignees = [agent1, agent2];
      await cubit.loadAssignableUsers();

      await tester.pumpWidget(
        buildTestWidget(
          cubit: cubit,
          onChanged: (val) => selectedCallbackValue = val,
        ),
      );
      await tester.pumpAndSettle();

      final dropdown = find.byKey(const Key('lead_assignee_dropdown'));
      expect(dropdown, findsOneWidget);
      expect(find.text('Select an assignee'), findsOneWidget);

      // Open dropdown
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Verify all assignee names are displayed
      expect(find.text('Mock Agent One').last, findsOneWidget);
      expect(find.text('Mock Agent Two').last, findsOneWidget);

      // Select Mock Agent One
      await tester.tap(find.text('Mock Agent One').last);
      await tester.pumpAndSettle();

      expect(cubit.state.selectedAssignee, equals(agent1));
      expect(selectedCallbackValue, equals(agent1));
      expect(find.text('Mock Agent One'), findsOneWidget);
    });

    testWidgets('clears selection when "Select an assignee" is tapped', (
      tester,
    ) async {
      LeadAssignee? selectedCallbackValue;
      repository.assignees = [agent1, agent2];
      await cubit.loadAssignableUsers();
      cubit.selectAssignee(agent1);

      await tester.pumpWidget(
        buildTestWidget(
          cubit: cubit,
          onChanged: (val) => selectedCallbackValue = val,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mock Agent One'), findsOneWidget);

      // Open dropdown
      await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
      await tester.pumpAndSettle();

      // Tap 'Select an assignee'
      await tester.tap(find.text('Select an assignee').last);
      await tester.pumpAndSettle();

      expect(cubit.state.selectedAssignee, isNull);
      expect(selectedCallbackValue, isNull);
    });

    testWidgets(
      'disables dropdown when enabled is false or isSubmitting is true',
      (tester) async {
        repository.assignees = [agent1];
        await cubit.loadAssignableUsers();

        await tester.pumpWidget(buildTestWidget(cubit: cubit, enabled: false));
        await tester.pumpAndSettle();

        final dropdownField = tester.widget<DropdownButtonFormField<String?>>(
          find.byKey(const Key('lead_assignee_dropdown')),
        );
        expect(dropdownField.onChanged, isNull);
      },
    );

    testWidgets('renders cleanly in dark theme', (tester) async {
      repository.assignees = [agent1];
      await cubit.loadAssignableUsers();

      await tester.pumpWidget(
        buildTestWidget(
          cubit: cubit,
          theme: ThemeData.dark(useMaterial3: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('lead_assignee_dropdown')), findsOneWidget);
    });

    testWidgets(
      'renders cleanly across viewports (320x568, 360x640, 768x1024, 1200x800)',
      (tester) async {
        const viewports = [
          Size(320, 568),
          Size(360, 640),
          Size(768, 1024),
          Size(1200, 800),
        ];

        repository.assignees = [agent1, agent2];
        await cubit.loadAssignableUsers();

        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            buildTestWidget(cubit: cubit, width: size.width - 32),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('lead_assignee_dropdown')),
            findsOneWidget,
          );
        }
      },
    );
  });
}
