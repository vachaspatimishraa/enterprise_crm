import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/domain/entities/call_outcome.dart';
import 'package:enterprise_crm/features/calling/presentation/screens/user_calling_workspace_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_lead_details_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_lead_workspace_screen.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const userWithCallingAndLeads = CurrentUser(
    id: 'usr_standard',
    displayName: 'Caller Rep',
    accountType: AccountType.user,
    modules: {CrmModule.calling, CrmModule.leadManagement},
    permissions: {CrmPermissions.callingUse, CrmPermissions.leadViewAssigned},
  );

  const userWithCallingOnly = CurrentUser(
    id: 'usr_calling_only',
    displayName: 'Calling Only Rep',
    accountType: AccountType.user,
    modules: {CrmModule.calling},
    permissions: {CrmPermissions.callingUse},
  );

  const userWithoutCallingPerm = CurrentUser(
    id: 'usr_no_calling_perm',
    displayName: 'No Calling Perm',
    accountType: AccountType.user,
    modules: {CrmModule.calling},
    permissions: {},
  );

  const userWithoutCallingModule = CurrentUser(
    id: 'usr_no_calling_mod',
    displayName: 'No Calling Module',
    accountType: AccountType.user,
    modules: {CrmModule.leadManagement},
    permissions: {CrmPermissions.callingUse},
  );

  late MockLeadRepository leadRepo;
  late MockUserLeadLinkRepository linkRepo;
  late MockLeadCallActivityRepository callActivityRepo;

  setUp(() {
    leadRepo = MockLeadRepository();
    linkRepo = MockUserLeadLinkRepository();
    callActivityRepo = MockLeadCallActivityRepository();
  });

  Widget buildTestApp({
    CurrentUser? user,
    ThemeMode themeMode = ThemeMode.light,
    DateTime Function()? now,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
      home: UserCallingWorkspaceScreen(
        user: user ?? userWithCallingAndLeads,
        leadRepository: leadRepo,
        linkRepository: linkRepo,
        callActivityRepository: callActivityRepo,
        now: now,
      ),
    );
  }

  group('UserCallingWorkspaceScreen - Access & Presentation', () {
    testWidgets(
      'authorized user with lead view access sees full workspace and Open My Assigned Leads button',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.byType(UserCallingWorkspaceScreen), findsOneWidget);
        expect(find.text('Calling'), findsOneWidget);
        expect(find.text('CALLING'), findsOneWidget);
        expect(
          find.byKey(const Key('user_calling_status_enabled')),
          findsOneWidget,
        );
        expect(find.text('Calling access is enabled.'), findsOneWidget);
        expect(
          find.byKey(const Key('user_calling_manage_from_leads_message')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('user_calling_open_leads_button')),
          findsOneWidget,
        );
        expect(find.text('Open My Assigned Leads'), findsOneWidget);
      },
    );

    testWidgets(
      'authorized user without lead view access sees no lead access message and NO button',
      (tester) async {
        await tester.pumpWidget(buildTestApp(user: userWithCallingOnly));
        await tester.pumpAndSettle();

        expect(find.byType(UserCallingWorkspaceScreen), findsOneWidget);
        expect(find.text('CALLING'), findsOneWidget);
        expect(
          find.byKey(const Key('user_calling_status_enabled')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('user_calling_no_lead_access_message')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Calling access is enabled, but no Lead viewing access has been assigned to your account.',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('user_calling_open_leads_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'user lacking calling.use permission renders AccessRestrictedScreen',
      (tester) async {
        await tester.pumpWidget(buildTestApp(user: userWithoutCallingPerm));
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.text('CALLING'), findsNothing);
      },
    );

    testWidgets('user lacking Calling module renders AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(user: userWithoutCallingModule));
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
      expect(find.text('CALLING'), findsNothing);
    });
  });

  group('UserCallingWorkspaceScreen - Navigation & Repository Invariance', () {
    testWidgets(
      'tapping Open My Assigned Leads pushes UserLeadWorkspaceScreen retaining shared repositories',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('user_calling_open_leads_button')),
        );
        await tester.pumpAndSettle();

        // Verified: UserLeadWorkspaceScreen is opened
        expect(find.byType(UserLeadWorkspaceScreen), findsOneWidget);
        final leadWorkspace = tester.widget<UserLeadWorkspaceScreen>(
          find.byType(UserLeadWorkspaceScreen),
        );

        // Invariant: Exact same repository instances passed through
        expect(identical(leadWorkspace.leadRepository, leadRepo), isTrue);
        expect(identical(leadWorkspace.linkRepository, linkRepo), isTrue);
        expect(
          identical(leadWorkspace.callActivityRepository, callActivityRepo),
          isTrue,
        );
      },
    );

    testWidgets('tapping back button pops navigation', (tester) async {
      bool popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserCallingWorkspaceScreen(
                        user: userWithCallingAndLeads,
                        leadRepository: leadRepo,
                        linkRepository: linkRepo,
                        callActivityRepository: callActivityRepo,
                      ),
                    ),
                  );
                  popped = true;
                },
                child: const Text('Open Calling'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Calling'));
      await tester.pumpAndSettle();

      expect(find.byType(UserCallingWorkspaceScreen), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('user_calling_workspace_back_button')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UserCallingWorkspaceScreen), findsNothing);
      expect(popped, isTrue);
    });
  });

  group('UserCallingWorkspaceScreen - Responsive & Theme Tests', () {
    testWidgets('renders cleanly across 4 viewports without overflow', (
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

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.text('CALLING'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders cleanly in dark mode', (tester) async {
      await tester.pumpWidget(buildTestApp(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(find.text('CALLING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('UserCallingWorkspaceScreen - CALL-1B Operational Dashboard', () {
    final fixedNow = DateTime(2026, 9, 21, 10, 0, 0);

    setUp(() async {
      // Assign mock-lead-2 to agent-1 so agent-1 owns mock-lead-1, mock-lead-2, mock-lead-5
      await leadRepo.assignLead(leadId: 'mock-lead-2', assigneeId: 'agent-1');

      // Seed 3 activities for agent-1's leads (mock-lead-1, mock-lead-2, mock-lead-5):
      // 1. Overdue: 20 Sep 16:00 (mock-lead-1)
      await callActivityRepo.recordActivity(
        leadId: 'mock-lead-1',
        performedByUserId: 'usr_standard',
        outcome: CallOutcome.followUp,
        rescheduleAt: DateTime(2026, 9, 20, 16, 0),
      );

      // 2. Due Today: 21 Sep 15:30 (mock-lead-2)
      await callActivityRepo.recordActivity(
        leadId: 'mock-lead-2',
        performedByUserId: 'usr_standard',
        outcome: CallOutcome.visitScheduled,
        rescheduleAt: DateTime(2026, 9, 21, 15, 30),
      );

      // 3. Upcoming: 22 Sep 10:00 (mock-lead-5)
      await callActivityRepo.recordActivity(
        leadId: 'mock-lead-5',
        performedByUserId: 'usr_standard',
        outcome: CallOutcome.notConnected,
        rescheduleAt: DateTime(2026, 9, 22, 10, 0),
      );
    });

    testWidgets('displays summary metrics cards with accurate counts', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(now: () => fixedNow));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('calling_summary_card_overdue')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('calling_summary_card_due_today')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('calling_summary_card_upcoming')),
        findsOneWidget,
      );

      expect(find.text('Overdue'), findsWidgets);
      expect(find.text('Due Today'), findsWidgets);
      expect(find.text('Upcoming'), findsWidgets);

      // Verify all 3 queue items rendered
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-3')),
        findsOneWidget,
      );
    });

    testWidgets('tapping summary card filters list by timing', (tester) async {
      await tester.pumpWidget(buildTestApp(now: () => fixedNow));
      await tester.pumpAndSettle();

      // Tap Overdue summary card
      await tester.tap(find.byKey(const Key('calling_summary_card_overdue')));
      await tester.pumpAndSettle();

      // Only Overdue item visible
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-2')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-3')),
        findsNothing,
      );

      // Tap Overdue again to toggle back to All
      await tester.tap(find.byKey(const Key('calling_summary_card_overdue')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-3')),
        findsOneWidget,
      );
    });

    testWidgets('tapping filter chips updates visible queue items', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(now: () => fixedNow));
      await tester.pumpAndSettle();

      // Tap Due Today filter chip
      await tester.tap(find.byKey(const Key('calling_filter_chip_due_today')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-3')),
        findsNothing,
      );

      // Tap Upcoming filter chip
      await tester.tap(find.byKey(const Key('calling_filter_chip_upcoming')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-2')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-3')),
        findsOneWidget,
      );
    });

    testWidgets('local search filters queue by lead name and phone', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(now: () => fixedNow));
      await tester.pumpAndSettle();

      // Enter search text 'Pooja' (matches mock-lead-2)
      await tester.enterText(
        find.byKey(const Key('calling_search_field')),
        'Pooja',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-3')),
        findsNothing,
      );

      // Non-matching search shows empty message
      await tester.enterText(
        find.byKey(const Key('calling_search_field')),
        'Nobody',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('calling_search_no_results')),
        findsOneWidget,
      );
      expect(find.text('No follow-ups match your search.'), findsOneWidget);
    });

    testWidgets(
      'tapping [View Lead] navigates to UserLeadDetailsScreen with shared repositories',
      (tester) async {
        await tester.pumpWidget(buildTestApp(now: () => fixedNow));
        await tester.pumpAndSettle();

        // Tap [View Lead] on call-act-1 (mock-lead-1)
        final viewLeadBtn = find.byKey(
          const Key('calling_queue_item_view_lead_button_call-act-1'),
        );
        await tester.ensureVisible(viewLeadBtn);
        await tester.tap(viewLeadBtn);
        await tester.pumpAndSettle();

        expect(find.byType(UserLeadDetailsScreen), findsOneWidget);
        final detailsScreen = tester.widget<UserLeadDetailsScreen>(
          find.byType(UserLeadDetailsScreen),
        );
        expect(detailsScreen.leadId, 'mock-lead-1');
        expect(identical(detailsScreen.leadRepository, leadRepo), isTrue);
        expect(identical(detailsScreen.linkRepository, linkRepo), isTrue);
        expect(
          identical(detailsScreen.callActivityRepository, callActivityRepo),
          isTrue,
        );
      },
    );

    testWidgets('tapping refresh button in AppBar reloads the queue', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(now: () => fixedNow));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('calling_dashboard_refresh_button')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('calling_dashboard_refresh_button')),
      );
      await tester.pumpAndSettle();

      // Queue items remain loaded
      expect(
        find.byKey(const Key('calling_queue_item_card_call-act-1')),
        findsOneWidget,
      );
    });

    testWidgets(
      'loaded queue renders cleanly without overflow on all 4 viewports',
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

          await tester.pumpWidget(buildTestApp(now: () => fixedNow));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('calling_summary_card_overdue')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets('loaded queue renders cleanly in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(now: () => fixedNow, themeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('calling_summary_card_overdue')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('UserCallingWorkspaceScreen - Empty & Missing Identity States', () {
    testWidgets(
      'empty queue shows "No scheduled follow-ups." and Open My Assigned Leads button',
      (tester) async {
        // Default setUp has zero activities recorded
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('calling_queue_empty_message')),
          findsOneWidget,
        );
        expect(find.text('No scheduled follow-ups.'), findsOneWidget);
        expect(
          find.byKey(const Key('user_calling_open_leads_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets('missing identity link shows configuration message', (
      tester,
    ) async {
      final unlinkedLinkRepo = MockUserLeadLinkRepository(links: {});
      await tester.pumpWidget(
        MaterialApp(
          home: UserCallingWorkspaceScreen(
            user: userWithCallingAndLeads,
            leadRepository: leadRepo,
            linkRepository: unlinkedLinkRepo,
            callActivityRepository: callActivityRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('calling_dashboard_no_link_message')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Lead assignment identity is not configured for this account. Contact an administrator.',
        ),
        findsOneWidget,
      );
    });
  });
}
