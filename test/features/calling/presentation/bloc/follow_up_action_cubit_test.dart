import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_follow_up_repository.dart';
import 'package:enterprise_crm/features/calling/domain/entities/follow_up_status.dart';
import 'package:enterprise_crm/features/calling/presentation/bloc/follow_up_action_cubit.dart';
import 'package:enterprise_crm/features/calling/presentation/bloc/follow_up_action_state.dart';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedClock = DateTime(2026, 9, 21, 10, 0, 0);

  const authorizedUser = CurrentUser(
    id: 'usr-agent-1',
    displayName: 'Agent One User',
    accountType: AccountType.user,
    modules: {CrmModule.calling, CrmModule.leadManagement},
    permissions: {CrmPermissions.callingUse, CrmPermissions.leadViewAssigned},
  );

  final testLead = Lead(
    id: 'lead-1',
    name: 'Aarav Sharma',
    phone: '+91 9876543210',
    email: 'aarav@example.com',
    status: const LeadStatus('Contacted'),
    source: LeadSource.manual,
    assignedUserId: 'agent-1',
    assignedUserName: 'Agent One',
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );

  late MockLeadRepository leadRepo;
  late MockUserLeadLinkRepository linkRepo;
  late MockLeadFollowUpRepository followUpRepo;

  setUp(() {
    leadRepo = MockLeadRepository(
      dataSource: MockLeadDataSource(initialLeads: [testLead]),
    );
    linkRepo = MockUserLeadLinkRepository(links: {'usr-agent-1': 'agent-1'});
    followUpRepo = MockLeadFollowUpRepository(now: () => fixedClock);
  });

  group('FollowUpActionCubit - Lifecycle Operations', () {
    test('completeFollowUp transitions to completed and emits Success', () async {
      final followUp = await followUpRepo.createFollowUp(
        leadId: 'lead-1',
        sourceCallActivityId: 'call-act-1',
        scheduledAt: DateTime(2026, 9, 22, 14, 0),
        performedByUserId: 'usr-agent-1',
      );

      final cubit = FollowUpActionCubit(
        user: authorizedUser,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
        now: () => fixedClock,
      );

      final states = <FollowUpActionState>[];
      cubit.stream.listen(states.add);

      await cubit.completeFollowUp(followUpId: followUp.id, leadId: 'lead-1');
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0], isA<FollowUpActionSubmitting>());
      expect(states[1], isA<FollowUpActionSuccess>());

      final success = cubit.state as FollowUpActionSuccess;
      expect(success.followUp.id, followUp.id);
      expect(success.followUp.status, FollowUpStatus.completed);

      // Verify in repository
      final inRepo = await followUpRepo.getFollowUpById(followUp.id);
      expect(inRepo!.status, FollowUpStatus.completed);
    });

    test('cancelFollowUp transitions to cancelled and emits Success', () async {
      final followUp = await followUpRepo.createFollowUp(
        leadId: 'lead-1',
        sourceCallActivityId: 'call-act-1',
        scheduledAt: DateTime(2026, 9, 22, 14, 0),
        performedByUserId: 'usr-agent-1',
      );

      final cubit = FollowUpActionCubit(
        user: authorizedUser,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
        now: () => fixedClock,
      );

      final states = <FollowUpActionState>[];
      cubit.stream.listen(states.add);

      await cubit.cancelFollowUp(followUpId: followUp.id, leadId: 'lead-1');
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0], isA<FollowUpActionSubmitting>());
      expect(states[1], isA<FollowUpActionSuccess>());

      final success = cubit.state as FollowUpActionSuccess;
      expect(success.followUp.id, followUp.id);
      expect(success.followUp.status, FollowUpStatus.cancelled);

      final inRepo = await followUpRepo.getFollowUpById(followUp.id);
      expect(inRepo!.status, FollowUpStatus.cancelled);
    });

    test('rescheduleFollowUp updates scheduledAt, status remains pending, and emits Success', () async {
      final followUp = await followUpRepo.createFollowUp(
        leadId: 'lead-1',
        sourceCallActivityId: 'call-act-1',
        scheduledAt: DateTime(2026, 9, 22, 14, 0),
        performedByUserId: 'usr-agent-1',
      );

      final cubit = FollowUpActionCubit(
        user: authorizedUser,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
        now: () => fixedClock,
      );

      final states = <FollowUpActionState>[];
      cubit.stream.listen(states.add);

      final newSchedule = DateTime(2026, 9, 25, 16, 0);
      await cubit.rescheduleFollowUp(
        followUpId: followUp.id,
        leadId: 'lead-1',
        scheduledAt: newSchedule,
      );
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0], isA<FollowUpActionSubmitting>());
      expect(states[1], isA<FollowUpActionSuccess>());

      final success = cubit.state as FollowUpActionSuccess;
      expect(success.followUp.id, followUp.id);
      expect(success.followUp.scheduledAt, newSchedule);
      // Invariant: status remains pending
      expect(success.followUp.status, FollowUpStatus.pending);

      final inRepo = await followUpRepo.getFollowUpById(followUp.id);
      expect(inRepo!.status, FollowUpStatus.pending);
      expect(inRepo.scheduledAt, newSchedule);
    });

    test('rescheduleFollowUp rejects past date with immediate Failure and 0 writes', () async {
      final followUp = await followUpRepo.createFollowUp(
        leadId: 'lead-1',
        sourceCallActivityId: 'call-act-1',
        scheduledAt: DateTime(2026, 9, 22, 14, 0),
        performedByUserId: 'usr-agent-1',
      );

      final cubit = FollowUpActionCubit(
        user: authorizedUser,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
        now: () => fixedClock,
      );

      final states = <FollowUpActionState>[];
      cubit.stream.listen(states.add);

      final pastDate = fixedClock.subtract(const Duration(hours: 1));
      await cubit.rescheduleFollowUp(
        followUpId: followUp.id,
        leadId: 'lead-1',
        scheduledAt: pastDate,
      );

      expect(states.length, 1);
      expect(states[0], isA<FollowUpActionFailure>());
      expect(
        (states[0] as FollowUpActionFailure).message,
        'Reschedule date and time must be in the future.',
      );

      // Follow-up remains untouched
      final inRepo = await followUpRepo.getFollowUpById(followUp.id);
      expect(inRepo!.scheduledAt, DateTime(2026, 9, 22, 14, 0));
    });
  });

  group('FollowUpActionCubit - Security Gates & Anti-Reassignment Guards', () {
    test('ANTI-REASSIGNMENT GUARD: reassigned lead blocks complete with AccessDenied', () async {
      final followUp = await followUpRepo.createFollowUp(
        leadId: 'lead-1',
        sourceCallActivityId: 'call-act-1',
        scheduledAt: DateTime(2026, 9, 22, 14, 0),
        performedByUserId: 'usr-agent-1',
      );

      // Lead is reassigned to agent-2
      await leadRepo.assignLead(leadId: 'lead-1', assigneeId: 'agent-2');

      final cubit = FollowUpActionCubit(
        user: authorizedUser,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
        now: () => fixedClock,
      );

      await cubit.completeFollowUp(followUpId: followUp.id, leadId: 'lead-1');

      expect(cubit.state, isA<FollowUpActionAccessDenied>());
      final state = cubit.state as FollowUpActionAccessDenied;
      expect(state.reason, contains('Lead ownership has changed'));

      // Follow-up must still be pending in repo (not completed)
      final inRepo = await followUpRepo.getFollowUpById(followUp.id);
      expect(inRepo!.status, FollowUpStatus.pending);
    });

    test('terminal follow-up check: attempting to complete already-completed follow-up blocks with AccessDenied', () async {
      final followUp = await followUpRepo.createFollowUp(
        leadId: 'lead-1',
        sourceCallActivityId: 'call-act-1',
        scheduledAt: DateTime(2026, 9, 22, 14, 0),
        performedByUserId: 'usr-agent-1',
      );

      // Already completed beforehand
      await followUpRepo.completeFollowUp(
        followUpId: followUp.id,
        performedByUserId: 'usr-agent-1',
      );

      final cubit = FollowUpActionCubit(
        user: authorizedUser,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
        now: () => fixedClock,
      );

      await cubit.completeFollowUp(followUpId: followUp.id, leadId: 'lead-1');

      expect(cubit.state, isA<FollowUpActionAccessDenied>());
      final state = cubit.state as FollowUpActionAccessDenied;
      expect(state.reason, contains('Follow-up is no longer pending'));
    });

    test('missing identity link blocks with AccessDenied', () async {
      final followUp = await followUpRepo.createFollowUp(
        leadId: 'lead-1',
        sourceCallActivityId: 'call-act-1',
        scheduledAt: DateTime(2026, 9, 22, 14, 0),
        performedByUserId: 'usr-agent-1',
      );

      final emptyLinkRepo = MockUserLeadLinkRepository();
      final cubit = FollowUpActionCubit(
        user: authorizedUser,
        linkRepository: emptyLinkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
        now: () => fixedClock,
      );

      await cubit.cancelFollowUp(followUpId: followUp.id, leadId: 'lead-1');

      expect(cubit.state, isA<FollowUpActionAccessDenied>());
    });

    test('revoked permission blocks with AccessDenied', () async {
      const revokedUser = CurrentUser(
        id: 'usr-agent-1',
        displayName: 'Revoked User',
        accountType: AccountType.user,
        modules: {CrmModule.calling},
        permissions: {}, // missing callingUse and leadViewAssigned
      );

      final followUp = await followUpRepo.createFollowUp(
        leadId: 'lead-1',
        sourceCallActivityId: 'call-act-1',
        scheduledAt: DateTime(2026, 9, 22, 14, 0),
        performedByUserId: 'usr-agent-1',
      );

      final cubit = FollowUpActionCubit(
        user: revokedUser,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
        followUpRepository: followUpRepo,
        now: () => fixedClock,
      );

      await cubit.completeFollowUp(followUpId: followUp.id, leadId: 'lead-1');

      expect(cubit.state, isA<FollowUpActionAccessDenied>());
    });
  });
}
