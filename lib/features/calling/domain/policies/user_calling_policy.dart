import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../leads/domain/entities/lead.dart';

/// Centralized authorization policy for standard CRM User calling workflows.
///
/// Admin workflows remain separate and do not traverse this standard-user policy.
abstract final class UserCallingPolicy {
  /// Returns whether [user] is authorized to access the Calling module.
  ///
  /// Requires standard user account, [CrmModule.calling] assigned,
  /// and [CrmPermissions.callingUse] granted.
  static bool canUseCalling(CurrentUser user) {
    if (user.isAdmin) return false;

    return AccessPolicy.canAccessModule(user, CrmModule.calling) &&
        AccessPolicy.hasPermission(user, CrmPermissions.callingUse);
  }

  /// Returns whether [user] is authorized to record a call outcome on [lead].
  ///
  /// Requires:
  /// 1. Calling module + `calling.use` permission.
  /// 2. Lead Management module + `lead.view_assigned` permission.
  /// 3. Valid identity link mapping to a non-empty [linkedAssigneeId].
  /// 4. Strict ownership: [lead] is assigned to [linkedAssigneeId].
  ///
  /// NOTE: `lead.update` is NOT required to record a call outcome.
  static bool canRecordActivityForLead({
    required CurrentUser user,
    required Lead lead,
    required String? linkedAssigneeId,
  }) {
    if (!canUseCalling(user)) return false;

    if (!AccessPolicy.canAccessModule(user, CrmModule.leadManagement)) {
      return false;
    }

    if (!AccessPolicy.hasPermission(user, CrmPermissions.leadViewAssigned)) {
      return false;
    }

    final sanitizedLink = linkedAssigneeId?.trim();
    if (sanitizedLink == null || sanitizedLink.isEmpty) {
      return false;
    }

    if (!lead.isAssigned || lead.assignedUserId != sanitizedLink) {
      return false;
    }

    return true;
  }

  /// Returns whether [user] is authorized to view call history for [lead].
  ///
  /// For CALL-1A, exposes history only when the user is authorized for Calling
  /// and strictly owns the lead.
  static bool canViewLeadHistory({
    required CurrentUser user,
    required Lead lead,
    required String? linkedAssigneeId,
  }) {
    return canRecordActivityForLead(
      user: user,
      lead: lead,
      linkedAssigneeId: linkedAssigneeId,
    );
  }
}
