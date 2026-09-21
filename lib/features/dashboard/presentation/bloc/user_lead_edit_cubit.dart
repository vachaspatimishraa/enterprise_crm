import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../auth/domain/policies/user_lead_update_policy.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../leads/domain/entities/lead.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import 'user_lead_edit_state.dart';

/// Cubit managing authorization, ownership verification, anti-stale checks,
/// and safe mutation for [UserEditLeadScreen].
class UserLeadEditCubit extends Cubit<UserLeadEditState> {
  final CurrentUser _user;
  final UserLeadLinkRepository _linkRepository;
  final LeadRepository _leadRepository;
  final String _leadId;
  final Lead? _initialLead;

  UserLeadEditCubit({
    required CurrentUser user,
    required UserLeadLinkRepository linkRepository,
    required LeadRepository leadRepository,
    required String leadId,
    Lead? initialLead,
  }) : _user = user,
       _linkRepository = linkRepository,
       _leadRepository = leadRepository,
       _leadId = leadId,
       _initialLead = initialLead,
       super(const UserLeadEditInitial());

  /// Runs the full authorization + ownership pipeline before opening the form.
  Future<void> load() async {
    emit(const UserLeadEditLoading());

    // 1. Module guard
    if (!AccessPolicy.canAccessModule(_user, CrmModule.leadManagement)) {
      emit(
        const UserLeadEditAccessDenied('Lead Management module not assigned.'),
      );
      return;
    }

    // 2. View permission guard
    if (!AccessPolicy.hasPermission(_user, CrmPermissions.leadViewAssigned)) {
      emit(
        const UserLeadEditAccessDenied(
          'lead.view_assigned permission not granted.',
        ),
      );
      return;
    }

    // 3. Update permission guard
    if (!AccessPolicy.hasPermission(_user, CrmPermissions.leadUpdate)) {
      emit(
        const UserLeadEditAccessDenied('lead.update permission not granted.'),
      );
      return;
    }

    try {
      // 4. Resolve identity link
      final link = await _linkRepository.getLinkForUser(_user.id);
      if (link == null) {
        emit(
          const UserLeadEditAccessDenied(
            'User is not linked to an assignee identity.',
          ),
        );
        return;
      }

      // 5. Validate assignee identity
      final assignees = await _leadRepository.getAssignableUsers();
      final assigneeExists = assignees.any((a) => a.id == link.leadAssigneeId);
      if (!assigneeExists) {
        emit(const UserLeadEditAccessDenied('Assigned identity is invalid.'));
        return;
      }

      // 6. Fetch lead
      final lead = _initialLead ?? await _leadRepository.getLeadById(_leadId);
      if (lead == null) {
        emit(const UserLeadEditAccessDenied('Lead not found.'));
        return;
      }

      // 7. Verify ownership
      if (!UserLeadUpdatePolicy.canEditLead(
        user: _user,
        lead: lead,
        linkedAssigneeId: link.leadAssigneeId,
      )) {
        emit(
          const UserLeadEditAccessDenied(
            'Access restricted to assigned leads only.',
          ),
        );
        return;
      }

      emit(
        UserLeadEditReady(lead: lead, linkedAssigneeId: link.leadAssigneeId),
      );
    } catch (e) {
      emit(
        UserLeadEditFailure(
          message: 'Unable to load lead.',
          lead: _initialLead ?? Lead(id: _leadId),
          linkedAssigneeId: '',
        ),
      );
    }
  }

  /// Submits safe field mutations.
  ///
  /// Re-resolves identity and re-fetches the lead from repository to prevent
  /// mutating a lead whose assignment changed while the edit screen was open.
  Future<void> submitUpdate({
    required String? name,
    required String? phone,
    required String? email,
  }) async {
    final currentState = state;
    if (currentState is UserLeadEditSubmitting) {
      // Double submit protection
      return;
    }

    Lead currentLead;
    String currentAssigneeId;
    if (currentState is UserLeadEditReady) {
      currentLead = currentState.lead;
      currentAssigneeId = currentState.linkedAssigneeId;
    } else if (currentState is UserLeadEditFailure) {
      currentLead = currentState.lead;
      currentAssigneeId = currentState.linkedAssigneeId;
    } else {
      return;
    }

    emit(
      UserLeadEditSubmitting(
        lead: currentLead,
        linkedAssigneeId: currentAssigneeId,
      ),
    );

    // Re-check module & permissions at save time
    if (!UserLeadUpdatePolicy.canEditAssignedLeads(_user)) {
      emit(const UserLeadEditAccessDenied('Permission revoked.'));
      return;
    }

    try {
      // 1. Re-resolve link at save time
      final link = await _linkRepository.getLinkForUser(_user.id);
      if (link == null) {
        emit(
          const UserLeadEditAccessDenied('Identity link is no longer valid.'),
        );
        return;
      }

      // 2. Validate assignee exists
      final assignees = await _leadRepository.getAssignableUsers();
      final assigneeExists = assignees.any((a) => a.id == link.leadAssigneeId);
      if (!assigneeExists) {
        emit(const UserLeadEditAccessDenied('Assigned identity is invalid.'));
        return;
      }

      // 3. Re-fetch fresh lead from repository
      final freshLead = await _leadRepository.getLeadById(_leadId);
      if (freshLead == null) {
        emit(const UserLeadEditAccessDenied('Lead not found.'));
        return;
      }

      // 4. Verify fresh ownership (if admin reassigned while edit was open -> blocked!)
      if (!UserLeadUpdatePolicy.canEditLead(
        user: _user,
        lead: freshLead,
        linkedAssigneeId: link.leadAssigneeId,
      )) {
        emit(
          const UserLeadEditAccessDenied(
            'Lead ownership has changed or is no longer accessible.',
          ),
        );
        return;
      }

      // 5. Build sanitized UpdateLeadInput preserving all protected attributes
      final input = UserLeadUpdatePolicy.buildUserUpdateInput(
        existing: freshLead,
        name: name,
        phone: phone,
        email: email,
      );

      // 6. Mutate via shared LeadRepository
      final updatedLead = await _leadRepository.updateLead(input);
      emit(UserLeadEditSuccess(updatedLead));
    } catch (e) {
      emit(
        UserLeadEditFailure(
          message: 'Unable to update lead.',
          lead: currentLead,
          linkedAssigneeId: currentAssigneeId,
        ),
      );
    }
  }
}
