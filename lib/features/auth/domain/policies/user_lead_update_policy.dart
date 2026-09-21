import '../../../leads/domain/entities/lead.dart';
import '../../../leads/domain/entities/lead_draft.dart';
import '../entities/crm_module.dart';
import '../entities/current_user.dart';
import 'access_policy.dart';
import 'crm_permissions.dart';

/// Centralized frontend authorization and mutation policy for standard CRM Users
/// interacting with assigned Leads.
///
/// Principles:
/// 1. Standard users must have `leadManagement` module access and `lead.view_assigned`
///    permission to view any assigned Lead data.
/// 2. Standard users must additionally hold `lead.update` permission and be linked
///    to the exact assignee of the Lead (`lead.assignedUserId == linkedAssigneeId`)
///    to edit a Lead.
/// 3. Standard users can only mutate safe fields (`name`, `phone`, `email`).
///    Protected fields (`id`, `status`, `source`, `assignedUserId`, `assignedUserName`, `createdAt`)
///    are strictly immutable in the user mutation workflow.
/// 4. This policy is strictly User-scoped; Admin Lead operations use unrestricted
///    Admin Lead workflows.
abstract final class UserLeadUpdatePolicy {
  /// Allowed fields a standard user may modify.
  static const Set<String> allowedFields = {'name', 'phone', 'email'};

  /// Protected fields that must never be altered by a standard user.
  static const Set<String> protectedFields = {
    'id',
    'status',
    'source',
    'assignedUserId',
    'assignedUserName',
    'createdAt',
  };

  /// Checks whether [user] has prerequisite permissions to view assigned leads.
  static bool canViewAssignedLeads(CurrentUser user) {
    return AccessPolicy.canAccessModule(user, CrmModule.leadManagement) &&
        AccessPolicy.hasPermission(user, CrmPermissions.leadViewAssigned);
  }

  /// Checks whether [user] has prerequisite permissions to edit assigned leads.
  ///
  /// `lead.update` without `lead.view_assigned` or without module access is invalid.
  static bool canEditAssignedLeads(CurrentUser user) {
    return canViewAssignedLeads(user) &&
        AccessPolicy.hasPermission(user, CrmPermissions.leadUpdate);
  }

  /// Checks whether [user] may view [lead].
  ///
  /// Requires module access, `lead.view_assigned`, a valid [linkedAssigneeId],
  /// and that the lead belongs to that assignee (`lead.assignedUserId == linkedAssigneeId`).
  static bool canViewLead({
    required CurrentUser user,
    required Lead lead,
    required String? linkedAssigneeId,
  }) {
    if (!canViewAssignedLeads(user)) return false;
    if (linkedAssigneeId == null || linkedAssigneeId.isEmpty) return false;
    return lead.assignedUserId == linkedAssigneeId;
  }

  /// Checks whether [user] may edit [lead].
  ///
  /// Requires module access, `lead.view_assigned`, `lead.update`, a valid
  /// [linkedAssigneeId], and that the lead belongs to that assignee.
  static bool canEditLead({
    required CurrentUser user,
    required Lead lead,
    required String? linkedAssigneeId,
  }) {
    if (!canEditAssignedLeads(user)) return false;
    if (linkedAssigneeId == null || linkedAssigneeId.isEmpty) return false;
    return lead.assignedUserId == linkedAssigneeId;
  }

  /// Constructs a sanitized [UpdateLeadInput] for a standard user mutation.
  ///
  /// Strictly modifies only `name`, `phone`, and `email`.
  /// Preserves `existing.id`, `existing.status`, and `existing.source`.
  static UpdateLeadInput buildUserUpdateInput({
    required Lead existing,
    required String? name,
    required String? phone,
    required String? email,
  }) {
    final sanitizedName = name?.trim();
    final trimmedPhone = phone?.trim();
    final sanitizedPhone = (trimmedPhone?.isEmpty ?? true)
        ? null
        : trimmedPhone;
    final trimmedEmail = email?.trim();
    final sanitizedEmail = (trimmedEmail?.isEmpty ?? true)
        ? null
        : trimmedEmail;

    return UpdateLeadInput(
      leadId: existing.id,
      draft: LeadDraft(
        name: sanitizedName,
        phone: sanitizedPhone,
        email: sanitizedEmail,
        status: existing.status,
        source: existing.source,
      ),
    );
  }
}
