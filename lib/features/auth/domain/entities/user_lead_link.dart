/// An explicit identity mapping between a CRM user account and a Lead assignee
/// identity.
///
/// These two IDs belong to completely different namespaces:
/// - [crmUserId] matches [CurrentUser.id] / [ManagedUser.id]
/// - [leadAssigneeId] matches [LeadAssignee.id] / [Lead.assignedUserId]
///
/// A link must be explicitly created and validated before any scoped Lead query
/// is issued on behalf of the user.
class UserLeadLink {
  final String crmUserId;
  final String leadAssigneeId;

  const UserLeadLink({
    required this.crmUserId,
    required this.leadAssigneeId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLeadLink &&
          runtimeType == other.runtimeType &&
          crmUserId == other.crmUserId &&
          leadAssigneeId == other.leadAssigneeId;

  @override
  int get hashCode => Object.hash(crmUserId, leadAssigneeId);

  @override
  String toString() =>
      'UserLeadLink(crmUserId: $crmUserId, leadAssigneeId: $leadAssigneeId)';
}
