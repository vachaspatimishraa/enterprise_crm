import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_follow_up_repository.dart';
import 'package:enterprise_crm/features/calling/domain/entities/call_outcome.dart';
import 'package:enterprise_crm/features/calling/domain/entities/follow_up_status.dart';
import 'package:enterprise_crm/features/calling/presentation/screens/user_calling_workspace_screen.dart';
import 'package:enterprise_crm/features/calling/presentation/widgets/lead_follow_up_history_section.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_lead_details_screen.dart';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedNow = DateTime(2026, 9, 21, 10, 0, 0);

  const authorizedUser = CurrentUser(
    id: 'usr_standard',
    displayName: 'Caller Rep',
    accountType: AccountType.user,
    modules: {CrmModule.calling, CrmModule.leadManagement},
    permissions: {CrmPermissions.callingUse, CrmPermissions.leadViewAssigned},
  );

  final testLead = Lead(
    id: 'mock-lead-1',
    name: 'Rahul Verma',
    phone: '+91 9123456780',
    email: 'rahul@example.com',
    status: const LeadStatus('Contacted'),
    source: LeadSource.manual,
    assignedUserId: 'agent-1',
    assignedUserName: 'Sarah Jenkins',
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );

  late MockLeadRepository leadRepo;
  late MockUserLeadLinkRepository linkRepo;
  late MockLeadCallActivityRepository callActivityRepo;
  late MockLeadFollowUpRepository followUpRepo;

  setUp(() {
    leadRepo = MockLeadRepository(
      dataSource: MockLeadDataSource(initialLeads: [testLead]),
    );
    linkRepo = MockUserLeadLinkRepository(links: {'usr_standard': 'agent-1'});
    callActivityRepo = MockLeadCallActivityRepository();
    followUpRepo = MockLeadFollowUpRepository(now: () => fixedNow);
  });

  Widget buildCallingWorkspaceApp() {
    return MaterialApp(
      home: UserCallingWorkspaceScreen(
        user: authorizedUser,
        leadRepository: leadRepo,
        linkRepository: linkRepo,
        callActivityRepository: callActivityRepo,
        leadFollowUpRepository: followUpRepo,
        now: () => fixedNow,
      ),
    );
  }

  Widget buildLeadDetailsApp({required String leadId}) {
    return MaterialApp(
      home: UserLeadDetailsScreen(
        user: authorizedUser,
        leadId: leadId,
        leadRepository: leadRepo,
        linkRepository: linkRepo,
        callActivityRepository: callActivityRepo,
        leadFollowUpRepository: followUpRepo,
      ),
    );
  }

  group('UserCallingWorkspaceScreen - Follow-Up Actions UI', () {
    testWidgets(
      'tapping Complete button completes follow-up and refreshes queue',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final act = await callActivityRepo.recordActivity(
          leadId: 'mock-lead-1',
          performedByUserId: 'usr_standard',
          outcome: CallOutcome.followUp,
          rescheduleAt: DateTime(2026, 9, 22, 14, 0),
        );

        final fu = await followUpRepo.createFollowUp(
          leadId: 'mock-lead-1',
          sourceCallActivityId: act.id,
          scheduledAt: DateTime(2026, 9, 22, 14, 0),
          performedByUserId: 'usr_standard',
        );

        await tester.pumpWidget(buildCallingWorkspaceApp());
        await tester.pumpAndSettle();

        final completeBtn = find.byKey(
          Key('calling_queue_item_complete_button_${fu.id}'),
        );
        expect(completeBtn, findsOneWidget);

        await tester.ensureVisible(completeBtn);
        await tester.tap(completeBtn);
        await tester.pumpAndSettle();

        // Verify SnackBar
        expect(find.text('Follow-up updated successfully.'), findsOneWidget);

        // Verify follow-up is completed in repository
        final updatedFu = await followUpRepo.getFollowUpById(fu.id);
        expect(updatedFu!.status, FollowUpStatus.completed);

        // Verify queue is now empty of pending items
        expect(find.text('No scheduled follow-ups.'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Cancel button shows dialog; dismissing keeps follow-up pending; confirming cancels it',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final act = await callActivityRepo.recordActivity(
          leadId: 'mock-lead-1',
          performedByUserId: 'usr_standard',
          outcome: CallOutcome.followUp,
          rescheduleAt: DateTime(2026, 9, 22, 14, 0),
        );

        final fu = await followUpRepo.createFollowUp(
          leadId: 'mock-lead-1',
          sourceCallActivityId: act.id,
          scheduledAt: DateTime(2026, 9, 22, 14, 0),
          performedByUserId: 'usr_standard',
        );

        await tester.pumpWidget(buildCallingWorkspaceApp());
        await tester.pumpAndSettle();

        final cancelBtn = find.byKey(
          Key('calling_queue_item_cancel_button_${fu.id}'),
        );
        expect(cancelBtn, findsOneWidget);

        // Tap cancel to open dialog
        await tester.ensureVisible(cancelBtn);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        expect(find.text('Cancel Follow-Up'), findsOneWidget);
        expect(find.text('Cancel this scheduled follow-up?'), findsOneWidget);

        // Dismiss dialog
        await tester.tap(
          find.byKey(const Key('calling_cancel_dialog_dismiss')),
        );
        await tester.pumpAndSettle();

        // In repository: still pending
        var inRepo = await followUpRepo.getFollowUpById(fu.id);
        expect(inRepo!.status, FollowUpStatus.pending);

        // Tap cancel again and confirm
        await tester.ensureVisible(cancelBtn);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('calling_cancel_dialog_confirm')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Follow-up updated successfully.'), findsOneWidget);

        inRepo = await followUpRepo.getFollowUpById(fu.id);
        expect(inRepo!.status, FollowUpStatus.cancelled);
      },
    );

    testWidgets(
      'tapping Reschedule button opens dialog with date and time pickers',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final act = await callActivityRepo.recordActivity(
          leadId: 'mock-lead-1',
          performedByUserId: 'usr_standard',
          outcome: CallOutcome.followUp,
          rescheduleAt: DateTime(2026, 9, 22, 14, 0),
        );

        final fu = await followUpRepo.createFollowUp(
          leadId: 'mock-lead-1',
          sourceCallActivityId: act.id,
          scheduledAt: DateTime(2026, 9, 22, 14, 0),
          performedByUserId: 'usr_standard',
        );

        await tester.pumpWidget(buildCallingWorkspaceApp());
        await tester.pumpAndSettle();

        final rescheduleBtn = find.byKey(
          Key('calling_queue_item_reschedule_button_${fu.id}'),
        );
        expect(rescheduleBtn, findsOneWidget);

        await tester.ensureVisible(rescheduleBtn);
        await tester.tap(rescheduleBtn);
        await tester.pumpAndSettle();

        expect(find.text('Reschedule Follow-Up'), findsOneWidget);
        expect(
          find.byKey(const Key('calling_reschedule_pick_date_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('calling_reschedule_pick_time_button')),
          findsOneWidget,
        );

        // Tap Cancel in dialog
        await tester.tap(
          find.byKey(const Key('calling_reschedule_dialog_dismiss')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Reschedule Follow-Up'), findsNothing);
      },
    );
  });

  group('UserLeadDetailsScreen - Follow-Up History Integration', () {
    testWidgets(
      'renders LeadFollowUpHistorySection with follow-ups and events',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final act = await callActivityRepo.recordActivity(
          leadId: 'mock-lead-1',
          performedByUserId: 'usr_standard',
          outcome: CallOutcome.followUp,
          rescheduleAt: DateTime(2026, 9, 22, 14, 0),
        );

        final fu = await followUpRepo.createFollowUp(
          leadId: 'mock-lead-1',
          sourceCallActivityId: act.id,
          scheduledAt: DateTime(2026, 9, 22, 14, 0),
          performedByUserId: 'usr_standard',
        );

        await followUpRepo.rescheduleFollowUp(
          followUpId: fu.id,
          scheduledAt: DateTime(2026, 9, 25, 11, 0),
          performedByUserId: 'usr_standard',
        );

        await tester.pumpWidget(buildLeadDetailsApp(leadId: 'mock-lead-1'));
        await tester.pumpAndSettle();

        expect(find.byType(LeadFollowUpHistorySection), findsOneWidget);
        expect(
          find.byKey(Key('lead_follow_up_history_card_${fu.id}')),
          findsOneWidget,
        );
        expect(find.text('Follow-Up History'), findsOneWidget);
        expect(find.textContaining('Created •'), findsOneWidget);
        expect(find.textContaining('Rescheduled to'), findsOneWidget);
      },
    );

    testWidgets('empty follow-up history renders empty message', (
      tester,
    ) async {
      await tester.pumpWidget(buildLeadDetailsApp(leadId: 'mock-lead-1'));
      await tester.pumpAndSettle();

      expect(find.byType(LeadFollowUpHistorySection), findsOneWidget);
      expect(
        find.byKey(const Key('lead_follow_up_history_empty_message')),
        findsOneWidget,
      );
      expect(
        find.text('No follow-ups recorded for this lead.'),
        findsOneWidget,
      );
    });
  });
}
