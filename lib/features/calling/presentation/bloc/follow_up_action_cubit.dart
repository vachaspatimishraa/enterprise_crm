import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import '../../data/repositories/mock_lead_call_activity_repository.dart';
import '../../domain/entities/follow_up_status.dart';
import '../../domain/policies/user_follow_up_policy.dart';
import '../../domain/repositories/lead_follow_up_repository.dart';
import 'follow_up_action_state.dart';

/// Cubit managing authorization, validation, and lifecycle mutation of a [LeadFollowUp].
///
/// Enforces complete gate chain on every mutation:
/// Calling module -> calling.use -> Lead module -> lead.view_assigned -> link -> assignee validation -> fresh Lead ownership -> fresh Follow-Up pending check.
class FollowUpActionCubit extends Cubit<FollowUpActionState> {
  final CurrentUser _user;
  final UserLeadLinkRepository _linkRepository;
  final LeadRepository _leadRepository;
  final LeadFollowUpRepository _followUpRepository;
  final NowProvider _now;

  FollowUpActionCubit({
    required CurrentUser user,
    required UserLeadLinkRepository linkRepository,
    required LeadRepository leadRepository,
    required LeadFollowUpRepository followUpRepository,
    NowProvider? now,
  }) : _user = user,
       _linkRepository = linkRepository,
       _leadRepository = leadRepository,
       _followUpRepository = followUpRepository,
       _now = now ?? DateTime.now,
       super(const FollowUpActionInitial());

  /// Completes a pending follow-up after fresh ownership and state verification.
  Future<void> completeFollowUp({
    required String followUpId,
    required String leadId,
  }) async {
    if (state is FollowUpActionSubmitting) return;

    emit(const FollowUpActionSubmitting());

    final gateResult = await _verifyAccess(followUpId: followUpId, leadId: leadId);
    if (!gateResult.isSuccess) {
      emit(FollowUpActionAccessDenied(gateResult.errorMessage!));
      return;
    }

    try {
      final updated = await _followUpRepository.completeFollowUp(
        followUpId: followUpId,
        performedByUserId: _user.id,
      );
      emit(FollowUpActionSuccess(updated));
    } catch (_) {
      emit(const FollowUpActionFailure('Unable to complete follow-up.'));
    }
  }

  /// Cancels a pending follow-up after fresh ownership and state verification.
  Future<void> cancelFollowUp({
    required String followUpId,
    required String leadId,
  }) async {
    if (state is FollowUpActionSubmitting) return;

    emit(const FollowUpActionSubmitting());

    final gateResult = await _verifyAccess(followUpId: followUpId, leadId: leadId);
    if (!gateResult.isSuccess) {
      emit(FollowUpActionAccessDenied(gateResult.errorMessage!));
      return;
    }

    try {
      final updated = await _followUpRepository.cancelFollowUp(
        followUpId: followUpId,
        performedByUserId: _user.id,
      );
      emit(FollowUpActionSuccess(updated));
    } catch (_) {
      emit(const FollowUpActionFailure('Unable to cancel follow-up.'));
    }
  }

  /// Reschedules a pending follow-up to a new future [scheduledAt] after fresh ownership and state verification.
  Future<void> rescheduleFollowUp({
    required String followUpId,
    required String leadId,
    required DateTime scheduledAt,
  }) async {
    if (state is FollowUpActionSubmitting) return;

    // Reschedule validation: must be in the future
    if (!scheduledAt.isAfter(_now())) {
      emit(const FollowUpActionFailure('Reschedule date and time must be in the future.'));
      return;
    }

    emit(const FollowUpActionSubmitting());

    final gateResult = await _verifyAccess(followUpId: followUpId, leadId: leadId);
    if (!gateResult.isSuccess) {
      emit(FollowUpActionAccessDenied(gateResult.errorMessage!));
      return;
    }

    try {
      final updated = await _followUpRepository.rescheduleFollowUp(
        followUpId: followUpId,
        scheduledAt: scheduledAt,
        performedByUserId: _user.id,
      );
      emit(FollowUpActionSuccess(updated));
    } catch (_) {
      emit(const FollowUpActionFailure('Unable to reschedule follow-up.'));
    }
  }

  /// Runs the 8-gate security and ownership verification chain immediately before repository write.
  Future<({bool isSuccess, String? errorMessage})> _verifyAccess({
    required String followUpId,
    required String leadId,
  }) async {
    // 1. Module and permission guard
    if (!UserFollowUpPolicy.canManageFollowUps(_user)) {
      return (isSuccess: false, errorMessage: 'Calling or Lead permissions revoked.');
    }

    try {
      // 2. Re-resolve UserLeadLink
      final link = await _linkRepository.getLinkForUser(_user.id);
      if (link == null) {
        return (isSuccess: false, errorMessage: 'Identity link is no longer valid.');
      }

      // 3. Validate assignee exists
      final assignees = await _leadRepository.getAssignableUsers();
      final assigneeExists = assignees.any((a) => a.id == link.leadAssigneeId);
      if (!assigneeExists) {
        return (isSuccess: false, errorMessage: 'Assigned identity is invalid.');
      }

      // 4. Re-fetch fresh lead
      final freshLead = await _leadRepository.getLeadById(leadId);
      if (freshLead == null) {
        return (isSuccess: false, errorMessage: 'Lead not found.');
      }

      // 5. Strict current ownership check (anti-reassignment guard)
      if (freshLead.assignedUserId != link.leadAssigneeId) {
        return (
          isSuccess: false,
          errorMessage: 'Lead ownership has changed or is no longer accessible.',
        );
      }

      // 6. Re-fetch fresh follow-up
      final freshFollowUp = await _followUpRepository.getFollowUpById(followUpId);
      if (freshFollowUp == null) {
        return (isSuccess: false, errorMessage: 'Follow-up not found.');
      }

      // 7. Strict pending status check
      if (freshFollowUp.status != FollowUpStatus.pending) {
        return (isSuccess: false, errorMessage: 'Follow-up is no longer pending.');
      }

      return (isSuccess: true, errorMessage: null);
    } catch (_) {
      return (isSuccess: false, errorMessage: 'Unable to verify follow-up access.');
    }
  }
}
