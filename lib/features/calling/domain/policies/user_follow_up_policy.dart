import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../leads/domain/entities/lead.dart';
import '../entities/follow_up_status.dart';
import '../entities/lead_follow_up.dart';

/// Central policy governing standard-user authorization to view and act upon scheduled follow-ups.
///
/// Follow-up actions require Calling access and Lead view access, but do NOT require `lead.update`.
class UserFollowUpPolicy {
  const UserFollowUpPolicy._();

  /// Verifies top-level module and permission grants required to manage follow-up work.
  ///
  /// Requires:
  /// - Calling module assigned
  /// - `calling.use` permission
  /// - Lead Management module assigned
  /// - `lead.view_assigned` permission
  ///
  /// Does NOT require `lead.update`.
  static bool canManageFollowUps(CurrentUser user) {
    return AccessPolicy.canAccessModule(user, CrmModule.calling) &&
        AccessPolicy.hasPermission(user, CrmPermissions.callingUse) &&
        AccessPolicy.canAccessModule(user, CrmModule.leadManagement) &&
        AccessPolicy.hasPermission(user, CrmPermissions.leadViewAssigned);
  }

  /// Verifies that the user is authorized to perform a lifecycle mutation (`complete`, `cancel`, `reschedule`)
  /// on the specific [followUp] associated with [lead].
  ///
  /// Criteria:
  /// 1. General follow-up management access is granted.
  /// 2. [lead] is currently assigned to the user's [linkedAssigneeId].
  /// 3. [followUp] is currently in [FollowUpStatus.pending] state.
  static bool canActOnFollowUp({
    required CurrentUser user,
    required Lead lead,
    required String linkedAssigneeId,
    required LeadFollowUp followUp,
  }) {
    if (!canManageFollowUps(user)) {
      return false;
    }

    if (lead.assignedUserId != linkedAssigneeId) {
      return false;
    }

    if (followUp.status != FollowUpStatus.pending) {
      return false;
    }

    return true;
  }
}
