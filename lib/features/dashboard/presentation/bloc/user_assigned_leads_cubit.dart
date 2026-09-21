import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../leads/domain/entities/lead_query.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import 'user_assigned_leads_state.dart';

/// Cubit that owns the full authorization and identity-resolution pipeline for
/// a standard user's read-only assigned lead view.
///
/// Pipeline (strictly ordered — each step may short-circuit to a terminal state):
///   1. [AccessPolicy.canAccessModule] — Lead Management module gate
///   2. [AccessPolicy.hasPermission]   — lead.view_assigned permission gate
///   3. [UserLeadLinkRepository.getLinkForUser] — resolve CRM→assignee mapping
///   4. [LeadRepository.getAssignableUsers]      — validate assignee exists
///   5. [LeadRepository.getLeads] with mandatory assignedUserId scope
///
/// [LeadRepository.getLeads] is called **only** when all prior checks pass.
class UserAssignedLeadsCubit extends Cubit<UserAssignedLeadsState> {
  final CurrentUser _user;
  final UserLeadLinkRepository _linkRepository;
  final LeadRepository _leadRepository;

  UserAssignedLeadsCubit({
    required CurrentUser user,
    required UserLeadLinkRepository linkRepository,
    required LeadRepository leadRepository,
  }) : _user = user,
       _linkRepository = linkRepository,
       _leadRepository = leadRepository,
       super(const UserAssignedLeadsLoading());

  /// Runs the full authorization + resolution pipeline and emits the
  /// appropriate terminal state.
  ///
  /// Callers should invoke this once when the workspace becomes visible and on
  /// explicit retry.
  Future<void> load() async {
    emit(const UserAssignedLeadsLoading());

    // 1. Module access guard — no repository calls if module is not assigned.
    if (!AccessPolicy.canAccessModule(_user, CrmModule.leadManagement)) {
      // This path is normally blocked at the widget level; Cubit is defensive.
      emit(
        const UserAssignedLeadsFailure('Lead Management module not assigned.'),
      );
      return;
    }

    // 2. Permission guard — link + lead repos must not be touched without view.
    if (!AccessPolicy.hasPermission(_user, CrmPermissions.leadViewAssigned)) {
      emit(
        const UserAssignedLeadsFailure(
          'lead.view_assigned permission not granted.',
        ),
      );
      return;
    }

    try {
      // 3. Resolve CRM user → assignee link.
      final link = await _linkRepository.getLinkForUser(_user.id);
      if (link == null) {
        emit(const UserAssignedLeadsNoLink());
        return;
      }

      // 4. Validate that the mapped assignee exists in the Lead domain.
      final assignees = await _leadRepository.getAssignableUsers();
      final assigneeExists = assignees.any((a) => a.id == link.leadAssigneeId);
      if (!assigneeExists) {
        emit(UserAssignedLeadsInvalidLink(link.leadAssigneeId));
        return;
      }

      // 5. Scoped lead query — mandatory assignedUserId filter.
      final page = await _leadRepository.getLeads(
        LeadQuery(assignedUserId: link.leadAssigneeId),
      );

      if (page.items.isEmpty) {
        emit(UserAssignedLeadsEmpty(link.leadAssigneeId));
      } else {
        emit(
          UserAssignedLeadsLoaded(
            leads: page.items,
            leadAssigneeId: link.leadAssigneeId,
          ),
        );
      }
    } catch (e) {
      emit(
        UserAssignedLeadsFailure(e.toString().replaceAll('Exception: ', '')),
      );
    }
  }

  /// Re-runs the full pipeline. Useful for explicit retry in failure states.
  Future<void> retry() => load();
}
