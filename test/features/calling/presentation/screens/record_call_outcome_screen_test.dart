import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/domain/entities/call_outcome.dart';
import 'package:enterprise_crm/features/calling/presentation/screens/record_call_outcome_screen.dart';
import 'package:enterprise_crm/features/calling/presentation/utils/calling_display_formatters.dart';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedClock = DateTime(2025, 6, 1, 10, 0);

  final testLead = Lead(
    id: 'lead-test-1',
    name: 'Jane Doe',
    phone: '+1 555-4321',
    email: 'jane@example.com',
    status: const LeadStatus('Contacted'),
    source: LeadSource.manual,
    assignedUserId: 'agent-1',
    assignedUserName: 'Sarah Jenkins',
    createdAt: DateTime(2025, 1, 1),
  );

  const callingUser = CurrentUser(
    id: 'usr_caller',
    displayName: 'Caller Rep',
    accountType: AccountType.user,
    modules: {CrmModule.calling, CrmModule.leadManagement},
    permissions: {CrmPermissions.callingUse, CrmPermissions.leadViewAssigned},
  );

  late MockLeadRepository leadRepo;
  late MockUserLeadLinkRepository linkRepo;
  late MockLeadCallActivityRepository callActivityRepo;

  setUp(() {
    leadRepo = MockLeadRepository(
      dataSource: MockLeadDataSource(initialLeads: [testLead]),
    );
    linkRepo = MockUserLeadLinkRepository(links: {'usr_caller': 'agent-1'});
    callActivityRepo = MockLeadCallActivityRepository(now: () => fixedClock);
  });

  Widget buildTestApp({
    CurrentUser? user,
    String? leadId,
    Lead? initialLead,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
      home: RecordCallOutcomeScreen(
        user: user ?? callingUser,
        leadId: leadId ?? testLead.id,
        initialLead: initialLead ?? testLead,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        callActivityRepository: callActivityRepo,
        now: () => fixedClock,
      ),
    );
  }

  group('RecordCallOutcomeScreen - Form Presentation & Outcome Selection', () {
    testWidgets('renders all 8 outcomes in dropdown and allows selection', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Record Call Outcome'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('+1 555-4321'), findsOneWidget);

      // Verify all 8 outcomes exist in dropdown
      await tester.tap(find.byKey(const Key('record_call_outcome_dropdown')));
      await tester.pumpAndSettle();

      for (final outcome in CallOutcome.values) {
        expect(find.text(formatCallOutcome(outcome)).last, findsOneWidget);
      }

      // Select 'Visit Scheduled'
      await tester.tap(
        find.text(formatCallOutcome(CallOutcome.visitScheduled)).last,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(formatCallOutcome(CallOutcome.visitScheduled)),
        findsWidgets,
      );
    });

    testWidgets('cancelling pops without recording activity', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecordCallOutcomeScreen(
                      user: callingUser,
                      leadId: testLead.id,
                      initialLead: testLead,
                      linkRepository: linkRepo,
                      leadRepository: leadRepo,
                      callActivityRepository: callActivityRepo,
                      now: () => fixedClock,
                    ),
                  ),
                ),
                child: const Text('Open Record Screen'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Record Screen'));
      await tester.pumpAndSettle();

      expect(find.byType(RecordCallOutcomeScreen), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.byKey(const Key('record_call_outcome_cancel')));
      await tester.pumpAndSettle();

      expect(find.byType(RecordCallOutcomeScreen), findsNothing);
      expect(callActivityRepo.recordedActivities, isEmpty);
    });
  });

  group('RecordCallOutcomeScreen - Atomic Reschedule Validation', () {
    testWidgets(
      'submitting without outcome shows validation error and 0 activities saved',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('record_call_outcome_save')));
        await tester.pumpAndSettle();

        expect(find.text('Please select a call outcome.'), findsOneWidget);
        expect(callActivityRepo.recordedActivities, isEmpty);
      },
    );

    testWidgets(
      'neither date nor time selected saves with rescheduleAt = null',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Select outcome 'Sales Done'
        await tester.tap(find.byKey(const Key('record_call_outcome_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(formatCallOutcome(CallOutcome.salesDone)).last,
        );
        await tester.pumpAndSettle();

        // Submit
        await tester.tap(find.byKey(const Key('record_call_outcome_save')));
        await tester.pumpAndSettle();

        // Activity recorded with rescheduleAt == null
        expect(callActivityRepo.recordedActivities.length, 1);
        final recorded = callActivityRepo.recordedActivities.first;
        expect(recorded.outcome, CallOutcome.salesDone);
        expect(recorded.rescheduleAt, isNull);
        expect(recorded.performedByUserId, 'usr_caller');
        expect(recorded.leadId, testLead.id);
      },
    );

    testWidgets(
      'only date selected without time shows atomic reschedule error and 0 activities saved',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Select outcome 'Follow-up'
        await tester.tap(find.byKey(const Key('record_call_outcome_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(formatCallOutcome(CallOutcome.followUp)).last,
        );
        await tester.pumpAndSettle();

        // Select Date only
        await tester.tap(
          find.byKey(const Key('record_call_outcome_date_button')),
        );
        await tester.pumpAndSettle();
        // Select OK in date picker dialog
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(find.text('Pick Date'), findsNothing);

        // Submit without selecting time
        await tester.tap(find.byKey(const Key('record_call_outcome_save')));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Please select both date and time for reschedule, or clear the schedule.',
          ),
          findsOneWidget,
        );
        expect(callActivityRepo.recordedActivities, isEmpty);
      },
    );

    testWidgets(
      'only time selected without date shows atomic reschedule error and 0 activities saved',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Select outcome 'Follow-up'
        await tester.tap(find.byKey(const Key('record_call_outcome_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(formatCallOutcome(CallOutcome.followUp)).last,
        );
        await tester.pumpAndSettle();

        // Select Time only
        await tester.tap(
          find.byKey(const Key('record_call_outcome_time_button')),
        );
        await tester.pumpAndSettle();
        // Select OK in time picker dialog
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(find.text('Pick Time'), findsNothing);

        // Submit without selecting date
        await tester.tap(find.byKey(const Key('record_call_outcome_save')));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Please select both date and time for reschedule, or clear the schedule.',
          ),
          findsOneWidget,
        );
        expect(callActivityRepo.recordedActivities, isEmpty);
      },
    );

    testWidgets(
      'both date and time selected in the future saves with atomic reschedule DateTime',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Select outcome 'Follow-up'
        await tester.tap(find.byKey(const Key('record_call_outcome_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(formatCallOutcome(CallOutcome.followUp)).last,
        );
        await tester.pumpAndSettle();

        // Select Date (pick day 15)
        await tester.tap(
          find.byKey(const Key('record_call_outcome_date_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('15'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // Select Time
        await tester.tap(
          find.byKey(const Key('record_call_outcome_time_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // Submit
        await tester.tap(find.byKey(const Key('record_call_outcome_save')));
        await tester.pumpAndSettle();

        expect(callActivityRepo.recordedActivities.length, 1);
        final recorded = callActivityRepo.recordedActivities.first;
        expect(recorded.outcome, CallOutcome.followUp);
        expect(recorded.rescheduleAt, isNotNull);
        expect(recorded.rescheduleAt!.isAfter(fixedClock), isTrue);
      },
    );

    testWidgets(
      'clear button resets both date and time and allows saving with rescheduleAt = null',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Select outcome 'Not Interested'
        await tester.tap(find.byKey(const Key('record_call_outcome_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(formatCallOutcome(CallOutcome.notInterested)).last,
        );
        await tester.pumpAndSettle();

        // Select Date
        await tester.tap(
          find.byKey(const Key('record_call_outcome_date_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // Clear schedule
        expect(
          find.byKey(const Key('record_call_outcome_clear_schedule')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('record_call_outcome_clear_schedule')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pick Date'), findsOneWidget);
        expect(find.text('Pick Time'), findsOneWidget);

        // Submit
        await tester.tap(find.byKey(const Key('record_call_outcome_save')));
        await tester.pumpAndSettle();

        expect(callActivityRepo.recordedActivities.length, 1);
        expect(callActivityRepo.recordedActivities.first.rescheduleAt, isNull);
      },
    );
  });

  group('RecordCallOutcomeScreen - Save-Time Anti-Reassignment Guard', () {
    testWidgets(
      'reassignment while form open blocks submission with Access Restricted message and 0 calls',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Select outcome
        await tester.tap(find.byKey(const Key('record_call_outcome_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(formatCallOutcome(CallOutcome.notConnected)).last,
        );
        await tester.pumpAndSettle();

        // Admin reassigns lead to agent-2 while user is viewing the form
        await leadRepo.assignLead(leadId: testLead.id, assigneeId: 'agent-2');

        // User attempts to save
        await tester.tap(find.byKey(const Key('record_call_outcome_save')));
        await tester.pumpAndSettle();

        // Verified: blocked with access restricted screen
        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(callActivityRepo.recordedActivities, isEmpty);
      },
    );

    testWidgets(
      'unauthorized user direct navigation renders AccessRestrictedScreen',
      (tester) async {
        const unauthorizedUser = CurrentUser(
          id: 'usr_no_perms',
          displayName: 'No Calling Perms',
          accountType: AccountType.user,
          modules: {CrmModule.leadManagement},
          permissions: {CrmPermissions.leadViewAssigned},
        );

        await tester.pumpWidget(buildTestApp(user: unauthorizedUser));
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(
          find.byKey(const Key('record_call_outcome_screen')),
          findsNothing,
        );
      },
    );
  });

  group('RecordCallOutcomeScreen - Responsive Layout & Dark Mode', () {
    testWidgets(
      'renders cleanly across 4 viewports without RenderFlex overflow',
      (tester) async {
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

          await tester.pumpWidget(buildTestApp());
          await tester.pumpAndSettle();

          expect(find.text('Record Call Outcome'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets('renders cleanly in dark theme', (tester) async {
      await tester.pumpWidget(buildTestApp(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(find.text('Record Call Outcome'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
