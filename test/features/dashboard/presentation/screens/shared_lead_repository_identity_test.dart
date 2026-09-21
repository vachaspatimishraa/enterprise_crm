import 'package:enterprise_crm/app/crm_app.dart';
import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_dashboard_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_lead_workspace_screen.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/user_management/data/mock/mock_account_store.dart';
import 'package:enterprise_crm/features/user_management/data/repositories/mock_user_management_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Shared LeadRepository Identity & Scoping Invariant', () {
    testWidgets(
      'Admin Lead Management and User My Assigned Leads share the exact same LeadRepository instance',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // 1. Instantiate ONE application-scoped LeadRepository and ONE UserLeadLinkRepository
        final sharedLeadRepository = MockLeadRepository();
        final sharedLinkRepository = MockUserLeadLinkRepository();
        final accountStore = MockAccountStore.seeded();
        final authRepository = MockAuthRepository(accountStore: accountStore);
        final userManagementRepository = MockUserManagementRepository(
          accountStore: accountStore,
        );

        // Mutate shared repository: add a lead and assign to agent-1
        final createdLead = await sharedLeadRepository.createLead(
          const CreateLeadInput(
            draft: LeadDraft(
              name: 'Shared Repo Test Lead',
              source: LeadSource.manual,
            ),
          ),
        );
        await sharedLeadRepository.assignLead(
          leadId: createdLead.id,
          assigneeId: 'agent-1',
        );

        // 2. Launch CrmApp with the shared repository
        await tester.pumpWidget(
          CrmApp(
            leadRepository: sharedLeadRepository,
            authRepository: authRepository,
            userManagementRepository: userManagementRepository,
            userLeadLinkRepository: sharedLinkRepository,
          ),
        );
        await tester.pumpAndSettle();

        // 3. User logs in (usr_standard -> agent-1)
        await tester.enterText(
          find.byKey(const Key('login_user_id_field')),
          'user',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'user123',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byType(UserDashboardScreen), findsOneWidget);

        // 4. Open User Lead Workspace
        await tester.tap(find.byKey(const Key('module_card_leadManagement')));
        await tester.pumpAndSettle();

        expect(find.byType(UserLeadWorkspaceScreen), findsOneWidget);

        // 5. Verify the mutated lead from shared repository is visible in My Assigned Leads
        expect(find.text('Shared Repo Test Lead'), findsOneWidget);
      },
    );
  });
}
