import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/domain/entities/call_outcome.dart';
import 'package:enterprise_crm/features/calling/domain/entities/lead_call_activity.dart';
import 'package:enterprise_crm/features/calling/presentation/screens/record_call_outcome_screen.dart';
import 'package:enterprise_crm/features/calling/presentation/utils/calling_display_formatters.dart';
import 'package:enterprise_crm/features/calling/presentation/widgets/lead_call_history_section.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_lead_details_screen.dart';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpyCallActivityRepository extends MockLeadCallActivityRepository {
  int getActivitiesCallCount = 0;
  bool shouldFail = false;

  _SpyCallActivityRepository({super.initialActivities});

  @override
  Future<List<LeadCallActivity>> getActivitiesForLead(String leadId) async {
    getActivitiesCallCount++;
    if (shouldFail) {
      throw Exception('Failed to fetch call history');
    }
    return super.getActivitiesForLead(leadId);
  }
}

void main() {
  final ownLead = Lead(
    id: 'lead-own-1',
    name: 'Alice Johnson',
    phone: '+1 555-0100',
    email: 'alice@example.com',
    status: const LeadStatus('Contacted'),
    source: LeadSource.manual,
    assignedUserId: 'agent-1',
    assignedUserName: 'Sarah Jenkins',
    createdAt: DateTime(2025, 1, 15),
  );

  const callingUserNoUpdate = CurrentUser(
    id: 'usr_caller',
    displayName: 'Calling Only Rep',
    accountType: AccountType.user,
    modules: {CrmModule.calling, CrmModule.leadManagement},
    permissions: {CrmPermissions.callingUse, CrmPermissions.leadViewAssigned},
  );

  const editorUserNoCalling = CurrentUser(
    id: 'usr_editor',
    displayName: 'Editor Only Rep',
    accountType: AccountType.user,
    modules: {CrmModule.leadManagement},
    permissions: {CrmPermissions.leadViewAssigned, CrmPermissions.leadUpdate},
  );

  const fullCallingAndEditorUser = CurrentUser(
    id: 'usr_full',
    displayName: 'Full Access Rep',
    accountType: AccountType.user,
    modules: {CrmModule.calling, CrmModule.leadManagement},
    permissions: {
      CrmPermissions.callingUse,
      CrmPermissions.leadViewAssigned,
      CrmPermissions.leadUpdate,
    },
  );

  late MockLeadRepository leadRepo;
  late MockUserLeadLinkRepository linkRepo;
  late _SpyCallActivityRepository spyCallRepo;

  setUp(() {
    leadRepo = MockLeadRepository(
      dataSource: MockLeadDataSource(initialLeads: [ownLead]),
    );
    linkRepo = MockUserLeadLinkRepository(
      links: {
        'usr_caller': 'agent-1',
        'usr_editor': 'agent-1',
        'usr_full': 'agent-1',
      },
    );
    spyCallRepo = _SpyCallActivityRepository();
  });

  Widget buildTestApp({
    required CurrentUser user,
    required String leadId,
    _SpyCallActivityRepository? callRepo,
  }) {
    return MaterialApp(
      home: UserLeadDetailsScreen(
        user: user,
        leadId: leadId,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        callActivityRepository: callRepo ?? spyCallRepo,
      ),
    );
  }

  group('UserLeadDetailsScreen - Calling & Update Permission Independence', () {
    testWidgets(
      'Calling user without lead.update sees Record Call Outcome button but NO Edit button',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(user: callingUserNoUpdate, leadId: ownLead.id),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserLeadDetailsScreen), findsOneWidget);
        // Record Call Outcome button present
        expect(
          find.byKey(const Key('user_lead_record_call_outcome_button')),
          findsOneWidget,
        );
        // Edit button NOT present
        expect(find.byKey(const Key('user_lead_edit_button')), findsNothing);
      },
    );

    testWidgets(
      'Editor user without calling sees Edit button but NO Record Call Outcome button and NO Call History',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(user: editorUserNoCalling, leadId: ownLead.id),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserLeadDetailsScreen), findsOneWidget);
        // Edit button present
        expect(find.byKey(const Key('user_lead_edit_button')), findsOneWidget);
        // Record Call Outcome button NOT present
        expect(
          find.byKey(const Key('user_lead_record_call_outcome_button')),
          findsNothing,
        );
        // Call history section NOT rendered
        expect(find.byType(LeadCallHistorySection), findsNothing);
        // Crucial (User Correction 3): 0 calls to call history repo!
        expect(spyCallRepo.getActivitiesCallCount, 0);
      },
    );

    testWidgets(
      'Full user with both permissions sees both Edit and Record Call Outcome buttons',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(user: fullCallingAndEditorUser, leadId: ownLead.id),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('user_lead_edit_button')), findsOneWidget);
        expect(
          find.byKey(const Key('user_lead_record_call_outcome_button')),
          findsOneWidget,
        );
        expect(find.byType(LeadCallHistorySection), findsOneWidget);
      },
    );
  });

  group('UserLeadDetailsScreen - Call History Presentation States', () {
    testWidgets('renders empty history state when 0 activities recorded', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(user: callingUserNoUpdate, leadId: ownLead.id),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LeadCallHistorySection), findsOneWidget);
      expect(
        find.byKey(const Key('lead_call_history_empty_message')),
        findsOneWidget,
      );
      expect(
        find.text('No call activity recorded for this lead.'),
        findsOneWidget,
      );
    });

    testWidgets('renders list of activity cards when activities exist', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialActivities = [
        LeadCallActivity(
          id: 'act-1',
          leadId: ownLead.id,
          performedByUserId: 'usr_caller',
          outcome: CallOutcome.visitScheduled,
          rescheduleAt: DateTime(2025, 6, 15, 14, 30),
          createdAt: DateTime(2025, 6, 1, 10, 0),
        ),
        LeadCallActivity(
          id: 'act-2',
          leadId: ownLead.id,
          performedByUserId: 'usr_caller',
          outcome: CallOutcome.followUp,
          rescheduleAt: null,
          createdAt: DateTime(2025, 5, 20, 9, 15),
        ),
      ];

      final customRepo = _SpyCallActivityRepository(
        initialActivities: initialActivities,
      );

      await tester.pumpWidget(
        buildTestApp(
          user: callingUserNoUpdate,
          leadId: ownLead.id,
          callRepo: customRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lead_call_history_list')), findsOneWidget);
      expect(find.text('Visit scheduled'), findsOneWidget);
      expect(find.text('Follow up'), findsOneWidget);
      expect(
        find.text(
          'Rescheduled: ${formatActivityDateTime(DateTime(2025, 6, 15, 14, 30))}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders failure state on repository error and allows retry', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      spyCallRepo.shouldFail = true;

      await tester.pumpWidget(
        buildTestApp(user: callingUserNoUpdate, leadId: ownLead.id),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('lead_call_history_failure_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('lead_call_history_retry_button')),
        findsOneWidget,
      );

      // Resolve error and tap Retry
      spyCallRepo.shouldFail = false;
      await tester.tap(find.byKey(const Key('lead_call_history_retry_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('lead_call_history_empty_message')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('lead_call_history_failure_card')),
        findsNothing,
      );
    });
  });

  group('UserLeadDetailsScreen - Record Call Outcome Flow & Refresh', () {
    testWidgets(
      'tapping Record Call Outcome navigates to form and refreshes history on return',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(user: callingUserNoUpdate, leadId: ownLead.id),
        );
        await tester.pumpAndSettle();

        // 1. Initially empty history
        expect(
          find.byKey(const Key('lead_call_history_empty_message')),
          findsOneWidget,
        );

        // 2. Scroll into view and tap Record Call Outcome button
        await tester.ensureVisible(
          find.byKey(const Key('user_lead_record_call_outcome_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('user_lead_record_call_outcome_button')),
        );
        await tester.pumpAndSettle();

        // 3. RecordCallOutcomeScreen is open
        expect(find.byType(RecordCallOutcomeScreen), findsOneWidget);

        // 4. Select outcome 'Dispatched'
        await tester.tap(find.byKey(const Key('record_call_outcome_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dispatched').last);
        await tester.pumpAndSettle();

        // 5. Submit activity
        await tester.tap(find.byKey(const Key('record_call_outcome_save')));
        await tester.pumpAndSettle();

        // 6. Returns to UserLeadDetailsScreen and history is refreshed with Dispatched
        expect(find.byType(UserLeadDetailsScreen), findsOneWidget);
        expect(find.byKey(const Key('lead_call_history_list')), findsOneWidget);
        expect(find.text('Dispatched'), findsOneWidget);
      },
    );
  });
}
