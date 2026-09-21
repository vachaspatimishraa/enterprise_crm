import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import '../../domain/repositories/lead_follow_up_repository.dart';
import 'lead_follow_up_history_state.dart';

/// Cubit managing authorization and loading of follow-up lifecycle history for a Lead.
///
/// Enforces: Calling module -> calling.use -> Lead module -> lead.view_assigned -> link -> assignee validation -> fresh Lead -> ownership.
class LeadFollowUpHistoryCubit extends Cubit<LeadFollowUpHistoryState> {
  final CurrentUser _user;
  final String _leadId;
  final UserLeadLinkRepository _linkRepository;
  final LeadRepository _leadRepository;
  final LeadFollowUpRepository _followUpRepository;

  LeadFollowUpHistoryCubit({
    required CurrentUser user,
    required String leadId,
    required UserLeadLinkRepository linkRepository,
    required LeadRepository leadRepository,
    required LeadFollowUpRepository followUpRepository,
  }) : _user = user,
       _leadId = leadId,
       _linkRepository = linkRepository,
       _leadRepository = leadRepository,
       _followUpRepository = followUpRepository,
       super(const LeadFollowUpHistoryInitial());

  Future<void> loadHistory() async {
    emit(const LeadFollowUpHistoryLoading());

    // 1. Calling module guard
    if (!AccessPolicy.canAccessModule(_user, CrmModule.calling)) {
      emit(const LeadFollowUpHistoryAccessDenied('Calling module not assigned.'));
      return;
    }

    // 2. calling.use permission guard
    if (!AccessPolicy.hasPermission(_user, CrmPermissions.callingUse)) {
      emit(const LeadFollowUpHistoryAccessDenied('calling.use permission not granted.'));
      return;
    }

    // 3. Lead Management module guard
    if (!AccessPolicy.canAccessModule(_user, CrmModule.leadManagement)) {
      emit(const LeadFollowUpHistoryAccessDenied('Lead Management module not assigned.'));
      return;
    }

    // 4. lead.view_assigned permission guard
    if (!AccessPolicy.hasPermission(_user, CrmPermissions.leadViewAssigned)) {
      emit(const LeadFollowUpHistoryAccessDenied('lead.view_assigned permission not granted.'));
      return;
    }

    try {
      // 5. Resolve identity link
      final link = await _linkRepository.getLinkForUser(_user.id);
      if (link == null) {
        emit(const LeadFollowUpHistoryAccessDenied('User is not linked to an assignee identity.'));
        return;
      }

      // 6. Validate assignee identity exists
      final assignees = await _leadRepository.getAssignableUsers();
      final assigneeExists = assignees.any((a) => a.id == link.leadAssigneeId);
      if (!assigneeExists) {
        emit(const LeadFollowUpHistoryAccessDenied('Assigned identity is invalid.'));
        return;
      }

      // 7. Retrieve fresh lead
      final lead = await _leadRepository.getLeadById(_leadId);
      if (lead == null) {
        emit(const LeadFollowUpHistoryAccessDenied('Lead not found.'));
        return;
      }

      // 8. Strict ownership check
      if (lead.assignedUserId != link.leadAssigneeId) {
        emit(const LeadFollowUpHistoryAccessDenied('Access restricted to assigned leads only.'));
        return;
      }

      // 9. Query follow-ups
      final followUps = await _followUpRepository.getFollowUpsForLeadIds({_leadId});
      if (followUps.isEmpty) {
        emit(const LeadFollowUpHistoryEmpty());
        return;
      }

      // 10. Query events for each follow-up
      final items = <FollowUpWithEvents>[];
      for (final fu in followUps) {
        final events = await _followUpRepository.getEventsForFollowUp(fu.id);
        items.add(FollowUpWithEvents(followUp: fu, events: events));
      }

      // Sort newest scheduledAt first
      items.sort((a, b) => b.followUp.scheduledAt.compareTo(a.followUp.scheduledAt));

      emit(LeadFollowUpHistoryLoaded(items));
    } catch (_) {
      emit(const LeadFollowUpHistoryFailure('Unable to load follow-up history.'));
    }
  }
}
