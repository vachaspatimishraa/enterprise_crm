import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../auth/domain/policies/user_lead_update_policy.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../leads/domain/entities/lead.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import 'user_lead_details_state.dart';

/// Cubit managing authorization and data loading for [UserLeadDetailsScreen].
///
/// Enforces the frozen AUTH-3B security chain before emitting lead data:
/// Module -> View Permission -> Identity Link -> Assignee Validation -> Lead Retrieval -> Strict Ownership.
class UserLeadDetailsCubit extends Cubit<UserLeadDetailsState> {
  final CurrentUser _user;
  final UserLeadLinkRepository _linkRepository;
  final LeadRepository _leadRepository;
  final String _leadId;

  UserLeadDetailsCubit({
    required CurrentUser user,
    required UserLeadLinkRepository linkRepository,
    required LeadRepository leadRepository,
    required String leadId,
  }) : _user = user,
       _linkRepository = linkRepository,
       _leadRepository = leadRepository,
       _leadId = leadId,
       super(const UserLeadDetailsInitial());

  Future<void> loadLead() async {
    emit(const UserLeadDetailsLoading());

    // 1. Module guard
    if (!AccessPolicy.canAccessModule(_user, CrmModule.leadManagement)) {
      emit(
        const UserLeadDetailsAccessDenied(
          'Lead Management module not assigned.',
        ),
      );
      return;
    }

    // 2. View permission guard
    if (!AccessPolicy.hasPermission(_user, CrmPermissions.leadViewAssigned)) {
      emit(
        const UserLeadDetailsAccessDenied(
          'lead.view_assigned permission not granted.',
        ),
      );
      return;
    }

    try {
      // 3. Resolve identity link
      final link = await _linkRepository.getLinkForUser(_user.id);
      if (link == null) {
        emit(
          const UserLeadDetailsAccessDenied(
            'User is not linked to an assignee identity.',
          ),
        );
        return;
      }

      // 4. Validate assignee identity exists
      final assignees = await _leadRepository.getAssignableUsers();
      final assigneeExists = assignees.any((a) => a.id == link.leadAssigneeId);
      if (!assigneeExists) {
        emit(
          const UserLeadDetailsAccessDenied('Assigned identity is invalid.'),
        );
        return;
      }

      // 5. Retrieve lead
      final lead = await _leadRepository.getLeadById(_leadId);
      if (lead == null) {
        emit(const UserLeadDetailsAccessDenied('Lead not found.'));
        return;
      }

      // 6. Strict ownership check (cross-assignee or unassigned -> access denied)
      if (!UserLeadUpdatePolicy.canViewLead(
        user: _user,
        lead: lead,
        linkedAssigneeId: link.leadAssigneeId,
      )) {
        emit(
          const UserLeadDetailsAccessDenied(
            'Access restricted to assigned leads only.',
          ),
        );
        return;
      }

      // 7. Success
      final canEdit = UserLeadUpdatePolicy.canEditLead(
        user: _user,
        lead: lead,
        linkedAssigneeId: link.leadAssigneeId,
      );

      emit(
        UserLeadDetailsLoaded(
          lead: lead,
          linkedAssigneeId: link.leadAssigneeId,
          canEdit: canEdit,
        ),
      );
    } catch (e) {
      emit(UserLeadDetailsFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Updates the displayed lead directly when refreshed from an edit flow.
  void refreshLead(Lead updatedLead) {
    final currentState = state;
    if (currentState is UserLeadDetailsLoaded) {
      final canEdit = UserLeadUpdatePolicy.canEditLead(
        user: _user,
        lead: updatedLead,
        linkedAssigneeId: currentState.linkedAssigneeId,
      );
      emit(
        UserLeadDetailsLoaded(
          lead: updatedLead,
          linkedAssigneeId: currentState.linkedAssigneeId,
          canEdit: canEdit,
        ),
      );
    } else {
      loadLead();
    }
  }
}
