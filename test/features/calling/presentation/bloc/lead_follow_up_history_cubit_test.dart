import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_follow_up_repository.dart';
import 'package:enterprise_crm/features/calling/domain/entities/follow_up_status.dart';
import 'package:enterprise_crm/features/calling/presentation/bloc/lead_follow_up_history_cubit.dart';
import 'package:enterprise_crm/features/calling/presentation/bloc/lead_follow_up_history_state.dart';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedClock = DateTime(2026, 9, 21, 10, 0, 0);

  final testLead = Lead(
    id: 'lead-own-1',
    name: 'Alice Johnson',
    status: const LeadStatus('Contacted'),
    source: LeadSource.manual,
    assignedUserId: 'agent-1',
    assignedUserName: 'Sarah Jenkins',
    createdAt: DateTime(2025, 1, 1),
  );

  final crossLead = Lead(
    id: 'lead-cross-1',
    name: 'Bob Smith',
    status: const LeadStatus('New'),
    source: LeadSource.excel,
    assignedUserId: 'agent-2',
    createdAt: DateTime(2025, 1, 1),
  );

  const authorizedUser = CurrentUser(
    id: 'usr-standard-1',
    displayName: 'Sales Rep',
    accountType: AccountType.user,
    modules: {CrmModule.calling, CrmModule.leadManagement},
    permissions: {CrmPermissions.callingUse, CrmPermissions.leadViewAssigned},
  );

  late MockLeadRepository leadRepo;
  late MockUserLeadLinkRepository linkRepo;
  late MockLeadFollowUpRepository followUpRepo;

  setUp(() {
    leadRepo = MockLeadRepository(
      dataSource: MockLeadDataSource(initialLeads: [testLead, crossLead]),
    );
    linkRepo = MockUserLeadLinkRepository(links: {'usr-standard-1': 'agent-1'});
    followUpRepo = MockLeadFollowUpRepository(now: () => fixedClock);
  });

  group('LeadFollowUpHistoryCubit - Security & Authorization Guards', () {
    test('missing Calling module emits AccessDenied', () async {
      const user = CurrentUser(
        id: 'usr-standard-1',
        displayName: 'No Calling',
        accountType: AccountType.user,
        modules: {CrmModule.leadManagement},
        permissions: {
          CrmPermissions.callingUse,
          CrmPermissions.leadViewAssigned,
        },
      );

      final cubit = LeadFollowUpHistoryCubit(
        user: user,
        leadId: testLead.id,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
      );

      await cubit.loadHistory();
      expect(cubit.state, isA<LeadFollowUpHistoryAccessDenied>());
    });

    test('missing calling.use permission emits AccessDenied', () async {
      const user = CurrentUser(
        id: 'usr-standard-1',
        displayName: 'No Calling Perm',
        accountType: AccountType.user,
        modules: {CrmModule.calling, CrmModule.leadManagement},
        permissions: {CrmPermissions.leadViewAssigned},
      );

      final cubit = LeadFollowUpHistoryCubit(
        user: user,
        leadId: testLead.id,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
      );

      await cubit.loadHistory();
      expect(cubit.state, isA<LeadFollowUpHistoryAccessDenied>());
    });

    test('missing Lead Management module emits AccessDenied', () async {
      const user = CurrentUser(
        id: 'usr-standard-1',
        displayName: 'No Lead Mod',
        accountType: AccountType.user,
        modules: {CrmModule.calling},
        permissions: {
          CrmPermissions.callingUse,
          CrmPermissions.leadViewAssigned,
        },
      );

      final cubit = LeadFollowUpHistoryCubit(
        user: user,
        leadId: testLead.id,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
      );

      await cubit.loadHistory();
      expect(cubit.state, isA<LeadFollowUpHistoryAccessDenied>());
    });

    test('missing lead.view_assigned permission emits AccessDenied', () async {
      const user = CurrentUser(
        id: 'usr-standard-1',
        displayName: 'No View Perm',
        accountType: AccountType.user,
        modules: {CrmModule.calling, CrmModule.leadManagement},
        permissions: {CrmPermissions.callingUse},
      );

      final cubit = LeadFollowUpHistoryCubit(
        user: user,
        leadId: testLead.id,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
      );

      await cubit.loadHistory();
      expect(cubit.state, isA<LeadFollowUpHistoryAccessDenied>());
    });

    test('cross-assignee lead emits AccessDenied', () async {
      final cubit = LeadFollowUpHistoryCubit(
        user: authorizedUser,
        leadId: crossLead.id,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
      );

      await cubit.loadHistory();
      expect(cubit.state, isA<LeadFollowUpHistoryAccessDenied>());
    });

    test('missing user link emits AccessDenied', () async {
      final emptyLinkRepo = MockUserLeadLinkRepository(links: {});
      final cubit = LeadFollowUpHistoryCubit(
        user: authorizedUser,
        leadId: testLead.id,
        linkRepository: emptyLinkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
      );

      await cubit.loadHistory();
      expect(cubit.state, isA<LeadFollowUpHistoryAccessDenied>());
    });
  });

  group('LeadFollowUpHistoryCubit - Loading, Empty, Loaded, and Failure', () {
    test('authorized user with 0 follow-ups emits Empty state', () async {
      final cubit = LeadFollowUpHistoryCubit(
        user: authorizedUser,
        leadId: testLead.id,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
      );

      await cubit.loadHistory();
      expect(cubit.state, isA<LeadFollowUpHistoryEmpty>());
    });

    test(
      'authorized user with follow-ups and events emits Loaded state',
      () async {
        final fu = await followUpRepo.createFollowUp(
          leadId: testLead.id,
          sourceCallActivityId: 'act-1',
          scheduledAt: DateTime(2026, 9, 22, 11, 0),
          performedByUserId: 'usr-standard-1',
        );

        await followUpRepo.rescheduleFollowUp(
          followUpId: fu.id,
          scheduledAt: DateTime(2026, 9, 23, 15, 0),
          performedByUserId: 'usr-standard-1',
        );

        final cubit = LeadFollowUpHistoryCubit(
          user: authorizedUser,
          leadId: testLead.id,
          linkRepository: linkRepo,
          leadRepository: leadRepo,
          followUpRepository: followUpRepo,
        );

        await cubit.loadHistory();

        expect(cubit.state, isA<LeadFollowUpHistoryLoaded>());
        final loaded = cubit.state as LeadFollowUpHistoryLoaded;
        expect(loaded.items.length, 1);
        expect(loaded.items.first.followUp.id, fu.id);
        expect(loaded.items.first.followUp.status, FollowUpStatus.pending);
        expect(loaded.items.first.events.length, 2);
      },
    );
  });
}
