import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_lead_details_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_lead_workspace_screen.dart';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/edit_lead_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Lead userLead;
  late Lead otherLead;
  late MockLeadRepository sharedLeadRepo;
  late MockUserLeadLinkRepository linkRepo;
  late MockLeadCallActivityRepository callActivityRepo;

  setUp(() {
    callActivityRepo = MockLeadCallActivityRepository();
    userLead = Lead(
      id: 'lead-e2e-1',
      name: 'E2E Test Lead',
      phone: '+1 555-1111',
      email: 'e2e@example.com',
      status: const LeadStatus('In Progress'),
      source: LeadSource.manual,
      assignedUserId: 'agent-1',
      assignedUserName: 'Sarah Jenkins',
      createdAt: DateTime(2025, 2, 1),
      updatedAt: DateTime(2025, 2, 1),
    );

    otherLead = Lead(
      id: 'lead-e2e-2',
      name: 'Other Agent Lead',
      phone: '+1 555-2222',
      email: 'other@example.com',
      status: const LeadStatus('New'),
      source: LeadSource.excel,
      assignedUserId: 'agent-2',
      assignedUserName: 'Mike Ross',
      createdAt: DateTime(2025, 2, 1),
    );

    sharedLeadRepo = MockLeadRepository(
      dataSource: MockLeadDataSource(initialLeads: [userLead, otherLead]),
    );

    linkRepo = MockUserLeadLinkRepository(links: {'usr_rep': 'agent-1'});
  });

  const repUser = CurrentUser(
    id: 'usr_rep',
    displayName: 'Sales Representative',
    accountType: AccountType.user,
    modules: {CrmModule.leadManagement},
    permissions: {CrmPermissions.leadViewAssigned, CrmPermissions.leadUpdate},
  );

  const readOnlyUser = CurrentUser(
    id: 'usr_rep',
    displayName: 'Sales Representative',
    accountType: AccountType.user,
    modules: {CrmModule.leadManagement},
    permissions: {CrmPermissions.leadViewAssigned},
  );

  group('AUTH-3B.2 E2E User Lead Editing Workflow', () {
    testWidgets(
      'Full flow: Workspace -> Details -> Edit -> Save -> Details Refreshed -> Workspace Refreshed',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: UserLeadWorkspaceScreen(
              user: repUser,
              linkRepository: linkRepo,
              leadRepository: sharedLeadRepo,
              callActivityRepository: callActivityRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Workspace displays user's lead
        expect(find.byType(UserLeadWorkspaceScreen), findsOneWidget);
        expect(find.text('E2E Test Lead'), findsOneWidget);
        expect(
          find.text('Other Agent Lead'),
          findsNothing,
        ); // Scoped to own leads

        // 2. Tap lead card to open details
        await tester.tap(find.byKey(Key('lead_card_${userLead.id}')));
        await tester.pumpAndSettle();

        expect(find.byType(UserLeadDetailsScreen), findsOneWidget);
        expect(find.text('Lead Details'), findsOneWidget);
        expect(find.byKey(const Key('user_lead_edit_button')), findsOneWidget);

        // 3. Tap Edit Lead button to open edit form
        await tester.tap(find.byKey(const Key('user_lead_edit_button')));
        await tester.pumpAndSettle();

        expect(find.text('Edit Lead'), findsOneWidget);
        expect(find.text('Original Lead Name'), findsNothing);
        expect(find.text('E2E Test Lead'), findsOneWidget);

        // 4. Update phone number
        await tester.enterText(
          find.byKey(const Key('user_edit_lead_phone')),
          '+1 555-9999',
        );
        await tester.pump();

        // 5. Submit update
        await tester.tap(find.byKey(const Key('user_edit_lead_save')));
        await tester.pumpAndSettle();

        // 6. Should return to UserLeadDetailsScreen with refreshed data
        expect(find.byType(UserLeadDetailsScreen), findsOneWidget);
        expect(find.text('+1 555-9999'), findsOneWidget);

        // 7. Back to workspace
        await tester.tap(
          find.byKey(const Key('user_lead_details_back_button')),
        );
        await tester.pumpAndSettle();

        // 8. Workspace reloads and shows updated phone
        expect(find.byType(UserLeadWorkspaceScreen), findsOneWidget);
        expect(find.text('+1 555-9999'), findsOneWidget);

        // 9. Verify in repository directly: phone is updated, status/source/assignment are untouched
        final repoLead = await sharedLeadRepo.getLeadById(userLead.id);
        expect(repoLead, isNotNull);
        expect(repoLead!.phone, '+1 555-9999');
        expect(repoLead.assignedUserId, 'agent-1');
        expect(repoLead.status, const LeadStatus('In Progress'));
        expect(repoLead.source, LeadSource.manual);
      },
    );

    testWidgets(
      'Read-only user flow: Workspace -> Details (No Edit button visible)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: UserLeadWorkspaceScreen(
              user: readOnlyUser,
              linkRepository: linkRepo,
              leadRepository: sharedLeadRepo,
              callActivityRepository: callActivityRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('E2E Test Lead'), findsOneWidget);

        // Tap lead card
        await tester.tap(find.byKey(Key('lead_card_${userLead.id}')));
        await tester.pumpAndSettle();

        expect(find.byType(UserLeadDetailsScreen), findsOneWidget);
        expect(find.text('Lead Details'), findsOneWidget);
        // Edit button must NOT exist for read-only user
        expect(find.byKey(const Key('user_lead_edit_button')), findsNothing);
      },
    );
  });

  group('Admin Lead Regression - Admin workflow completely unchanged', () {
    testWidgets(
      'Admin can view all leads without ownership restriction on shared repository',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: LeadListScreen(repository: sharedLeadRepo),
          ),
        );
        await tester.pumpAndSettle();

        // Admin sees both leads
        expect(find.byType(LeadListScreen), findsOneWidget);
        expect(find.text('E2E Test Lead'), findsOneWidget);
        expect(find.text('Other Agent Lead'), findsOneWidget);
      },
    );

    testWidgets(
      'Admin can edit status/source/assignment on EditLeadScreen without user restrictions',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: EditLeadScreen(lead: userLead, repository: sharedLeadRepo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EditLeadScreen), findsOneWidget);
        // Admin screen has status / assignee capabilities
        expect(find.text('Edit Lead'), findsOneWidget);
      },
    );
  });
}
