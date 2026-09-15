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
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_filter_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/widgets/lead_active_filters.dart';
import 'package:enterprise_crm/features/leads/presentation/widgets/lead_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  Future<void> assignLead({
    required String leadId,
    required String assigneeId,
  }) async {}

  @override
  Future<void> assignLeads(LeadAssignmentRequest request) async {}

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) async {}

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
  late LeadFilterCubit filterCubit;

  final mockAssignees = [
    const LeadAssignee(id: 'u1', displayName: 'Mock Agent One'),
    const LeadAssignee(id: 'u2', displayName: 'Mock Agent Two'),
  ];

  setUp(() {
    repository = _FakeLeadRepository();
    repository.assignees = mockAssignees;
    filterCubit = LeadFilterCubit(repository);
  });

  tearDown(() {
    filterCubit.close();
  });

  Widget buildFilterSheetWidget({
    LeadQuery query = const LeadQuery(),
    required ValueChanged<LeadQuery> onApply,
    Size size = const Size(800, 700),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Scaffold(
            body: BlocProvider.value(
              value: filterCubit,
              child: LeadFilterSheet(initialQuery: query, onApply: onApply),
            ),
          ),
        ),
      ),
    );
  }

  group('LeadFilterSheet - UI & Selection', () {
    testWidgets('renders all sections and loads assignees', (tester) async {
      await tester.pumpWidget(buildFilterSheetWidget(onApply: (_) {}));
      await tester.pumpAndSettle();

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Lead Source'), findsOneWidget);
      expect(find.text('Assignment'), findsOneWidget);
      expect(find.text('Assigned User'), findsOneWidget);
      expect(find.byKey(const Key('filter_clear_button')), findsOneWidget);
      expect(find.byKey(const Key('filter_apply_button')), findsOneWidget);

      // Verify assignees dropdown loaded
      expect(find.byKey(const Key('filter_assignee_dropdown')), findsOneWidget);
      expect(find.text('All Assignees'), findsOneWidget);
    });

    testWidgets('applies source filter correctly and resets page to 1', (
      tester,
    ) async {
      LeadQuery? applied;
      await tester.pumpWidget(
        buildFilterSheetWidget(
          query: const LeadQuery(page: 3, searchText: 'Alice'),
          onApply: (q) => applied = q,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Manual source
      await tester.tap(find.byKey(const Key('filter_source_manual')));
      await tester.pumpAndSettle();

      // Ensure apply button is visible and tap
      final applyButton = find.byKey(const Key('filter_apply_button'));
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.source, equals(LeadSource.manual));
      expect(applied!.page, equals(1));
      expect(applied!.searchText, equals('Alice'));
    });

    testWidgets('applies assignment state correctly', (tester) async {
      LeadQuery? applied;
      await tester.pumpWidget(
        buildFilterSheetWidget(onApply: (q) => applied = q),
      );
      await tester.pumpAndSettle();

      // Tap Assigned
      await tester.tap(find.byKey(const Key('filter_assignment_assigned')));
      await tester.pumpAndSettle();

      final applyButton = find.byKey(const Key('filter_apply_button'));
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.isAssigned, isTrue);
      expect(applied!.page, equals(1));
    });

    testWidgets('selecting an assignee automatically sets isAssigned to true', (
      tester,
    ) async {
      LeadQuery? applied;
      await tester.pumpWidget(
        buildFilterSheetWidget(onApply: (q) => applied = q),
      );
      await tester.pumpAndSettle();

      // Select Mock Agent One
      await tester.tap(find.byKey(const Key('filter_assignee_dropdown')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mock Agent One').last);
      await tester.pumpAndSettle();

      final applyButton = find.byKey(const Key('filter_apply_button'));
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.assignedUserId, equals('u1'));
      expect(applied!.isAssigned, isTrue);
    });

    testWidgets('selecting Unassigned clears assignedUserId', (tester) async {
      LeadQuery? applied;
      await tester.pumpWidget(
        buildFilterSheetWidget(onApply: (q) => applied = q),
      );
      await tester.pumpAndSettle();

      // Select Mock Agent One first
      await tester.tap(find.byKey(const Key('filter_assignee_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mock Agent One').last);
      await tester.pumpAndSettle();

      // Then tap Unassigned
      await tester.tap(find.byKey(const Key('filter_assignment_unassigned')));
      await tester.pumpAndSettle();

      final applyButton = find.byKey(const Key('filter_apply_button'));
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.isAssigned, isFalse);
      expect(applied!.assignedUserId, isNull);
    });

    testWidgets(
      'selecting All on Assignment preserves assignee and normalizes isAssigned=true on apply',
      (tester) async {
        LeadQuery? applied;
        await tester.pumpWidget(
          buildFilterSheetWidget(onApply: (q) => applied = q),
        );
        await tester.pumpAndSettle();

        // Select Mock Agent One first
        await tester.tap(find.byKey(const Key('filter_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent One').last);
        await tester.pumpAndSettle();

        // Tap All on Assignment
        await tester.tap(find.byKey(const Key('filter_assignment_all')));
        await tester.pumpAndSettle();

        final applyButton = find.byKey(const Key('filter_apply_button'));
        await tester.ensureVisible(applyButton);
        await tester.tap(applyButton);
        await tester.pumpAndSettle();

        expect(applied, isNotNull);
        expect(applied!.assignedUserId, equals('u1'));
        expect(applied!.isAssigned, isTrue);
      },
    );

    testWidgets('preserves searchText, status, and pageSize on apply', (
      tester,
    ) async {
      LeadQuery? applied;
      const initial = LeadQuery(
        searchText: 'Alice',
        status: LeadStatus('Sample New'),
        pageSize: 50,
        page: 4,
      );

      await tester.pumpWidget(
        buildFilterSheetWidget(query: initial, onApply: (q) => applied = q),
      );
      await tester.pumpAndSettle();

      // Select Excel
      await tester.tap(find.byKey(const Key('filter_source_excel')));
      await tester.pumpAndSettle();

      final applyButton = find.byKey(const Key('filter_apply_button'));
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.searchText, equals('Alice'));
      expect(applied!.status, equals(const LeadStatus('Sample New')));
      expect(applied!.pageSize, equals(50));
      expect(applied!.page, equals(1));
      expect(applied!.source, equals(LeadSource.excel));
    });

    testWidgets(
      'Clear Filters clears source, assignment, assignee but preserves search and status',
      (tester) async {
        LeadQuery? applied;
        const initial = LeadQuery(
          searchText: 'SearchQuery',
          status: LeadStatus('Sample Review'),
          source: LeadSource.manual,
          isAssigned: true,
          assignedUserId: 'u1',
          page: 5,
          pageSize: 20,
        );

        await tester.pumpWidget(
          buildFilterSheetWidget(query: initial, onApply: (q) => applied = q),
        );
        await tester.pumpAndSettle();

        final clearButton = find.byKey(const Key('filter_clear_button'));
        await tester.ensureVisible(clearButton);
        await tester.tap(clearButton);
        await tester.pumpAndSettle();

        expect(applied, isNotNull);
        expect(applied!.source, isNull);
        expect(applied!.isAssigned, isNull);
        expect(applied!.assignedUserId, isNull);
        expect(applied!.page, equals(1));
        expect(applied!.searchText, equals('SearchQuery'));
        expect(applied!.status, equals(const LeadStatus('Sample Review')));
        expect(applied!.pageSize, equals(20));
      },
    );

    testWidgets('tapping cancel / close does NOT invoke onApply', (
      tester,
    ) async {
      var applyInvoked = false;
      await tester.pumpWidget(
        buildFilterSheetWidget(onApply: (_) => applyInvoked = true),
      );
      await tester.pumpAndSettle();

      // Select Manual
      await tester.tap(find.byKey(const Key('filter_source_manual')));
      await tester.pumpAndSettle();

      // Tap Close button
      await tester.tap(find.byKey(const Key('filter_close_button')));
      await tester.pumpAndSettle();

      expect(applyInvoked, isFalse);
    });

    testWidgets('handles assignee loading failure gracefully with retry', (
      tester,
    ) async {
      repository.shouldThrow = true;
      final failingCubit = LeadFilterCubit(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: failingCubit,
              child: LeadFilterSheet(
                initialQuery: const LeadQuery(),
                onApply: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to fetch assignable users'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Verify other filters still work
      expect(find.byKey(const Key('filter_source_manual')), findsOneWidget);

      // Retry
      repository.shouldThrow = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('All Assignees'), findsOneWidget);
      failingCubit.close();
    });
  });

  group('LeadActiveFilters', () {
    testWidgets(
      'renders active chips correctly and triggers remove callbacks',
      (tester) async {
        var removeSourceCalled = false;
        var removeAssignmentCalled = false;
        var removeAssigneeCalled = false;
        var clearAllCalled = false;

        const query = LeadQuery(
          source: LeadSource.manual,
          isAssigned: true,
          assignedUserId: 'u1',
          status: LeadStatus('Sample Status'), // status should NOT be rendered
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LeadActiveFilters(
                query: query,
                assignees: mockAssignees,
                onRemoveSource: () => removeSourceCalled = true,
                onRemoveAssignment: () => removeAssignmentCalled = true,
                onRemoveAssignee: () => removeAssigneeCalled = true,
                onClearAll: () => clearAllCalled = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Source chip
        expect(
          find.byKey(const Key('active_filter_source_chip')),
          findsOneWidget,
        );
        expect(find.text('Manual'), findsOneWidget);

        // Assignment chip
        expect(
          find.byKey(const Key('active_filter_assignment_chip')),
          findsOneWidget,
        );
        expect(find.text('Assigned'), findsOneWidget);

        // Assignee chip
        expect(
          find.byKey(const Key('active_filter_assignee_chip')),
          findsOneWidget,
        );
        expect(find.text('Mock Agent One'), findsOneWidget);

        // Status should NOT be displayed
        expect(find.text('Sample Status'), findsNothing);

        // Tap delete on Source
        final deleteSource = find.descendant(
          of: find.byKey(const Key('active_filter_source_chip')),
          matching: find.byIcon(Icons.close),
        );
        await tester.tap(deleteSource);
        expect(removeSourceCalled, isTrue);

        // Tap delete on Assignment
        final deleteAssignment = find.descendant(
          of: find.byKey(const Key('active_filter_assignment_chip')),
          matching: find.byIcon(Icons.close),
        );
        await tester.tap(deleteAssignment);
        expect(removeAssignmentCalled, isTrue);

        // Tap delete on Assignee
        final deleteAssignee = find.descendant(
          of: find.byKey(const Key('active_filter_assignee_chip')),
          matching: find.byIcon(Icons.close),
        );
        await tester.tap(deleteAssignee);
        expect(removeAssigneeCalled, isTrue);

        // Tap Clear all
        await tester.tap(find.byKey(const Key('active_filters_clear_all')));
        expect(clearAllCalled, isTrue);
      },
    );

    testWidgets('renders nothing when no filters are active', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeadActiveFilters(
              query: const LeadQuery(),
              assignees: mockAssignees,
              onRemoveSource: () {},
              onRemoveAssignment: () {},
              onRemoveAssignee: () {},
              onClearAll: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InputChip), findsNothing);
      expect(find.byKey(const Key('active_filters_clear_all')), findsNothing);
    });
  });
}
