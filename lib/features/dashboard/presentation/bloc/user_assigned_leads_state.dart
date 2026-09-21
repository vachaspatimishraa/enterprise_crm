import '../../../leads/domain/entities/lead.dart';

/// States emitted by [UserAssignedLeadsCubit].
///
/// Ordering of the authorization / resolution pipeline:
///   1. [UserAssignedLeadsLoading]   — resolution in progress
///   2. [UserAssignedLeadsNoLink]    — no link configured for this user
///   3. [UserAssignedLeadsInvalidLink] — link exists but assignee not found in lead domain
///   4. [UserAssignedLeadsEmpty]     — valid link, zero leads assigned
///   5. [UserAssignedLeadsLoaded]    — valid link, leads returned
///   6. [UserAssignedLeadsFailure]   — unexpected repository error
sealed class UserAssignedLeadsState {
  const UserAssignedLeadsState();
}

final class UserAssignedLeadsLoading extends UserAssignedLeadsState {
  const UserAssignedLeadsLoading();
}

/// No link has been configured for the authenticated CRM user.
final class UserAssignedLeadsNoLink extends UserAssignedLeadsState {
  const UserAssignedLeadsNoLink();
}

/// A link exists but the referenced [leadAssigneeId] is not a valid assignee
/// in the Lead domain. The mapping is stale or misconfigured.
final class UserAssignedLeadsInvalidLink extends UserAssignedLeadsState {
  final String leadAssigneeId;
  const UserAssignedLeadsInvalidLink(this.leadAssigneeId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAssignedLeadsInvalidLink &&
          leadAssigneeId == other.leadAssigneeId;

  @override
  int get hashCode => leadAssigneeId.hashCode;
}

/// Valid link resolved; no leads are currently assigned.
final class UserAssignedLeadsEmpty extends UserAssignedLeadsState {
  final String leadAssigneeId;
  const UserAssignedLeadsEmpty(this.leadAssigneeId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAssignedLeadsEmpty && leadAssigneeId == other.leadAssigneeId;

  @override
  int get hashCode => leadAssigneeId.hashCode;
}

/// Valid link resolved; [leads] contains the scoped results.
final class UserAssignedLeadsLoaded extends UserAssignedLeadsState {
  final List<Lead> leads;
  final String leadAssigneeId;

  const UserAssignedLeadsLoaded({
    required this.leads,
    required this.leadAssigneeId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAssignedLeadsLoaded &&
          leadAssigneeId == other.leadAssigneeId &&
          _listEquals(leads, other.leads);

  @override
  int get hashCode => Object.hash(leadAssigneeId, Object.hashAll(leads));

  static bool _listEquals(List<Lead> a, List<Lead> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Unexpected error during link resolution or lead fetch.
final class UserAssignedLeadsFailure extends UserAssignedLeadsState {
  final String message;
  const UserAssignedLeadsFailure(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAssignedLeadsFailure && message == other.message;

  @override
  int get hashCode => message.hashCode;
}
