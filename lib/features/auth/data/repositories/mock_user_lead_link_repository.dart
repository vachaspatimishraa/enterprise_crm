import '../../domain/entities/user_lead_link.dart';
import '../../domain/repositories/user_lead_link_repository.dart';

/// In-memory mock implementation of [UserLeadLinkRepository].
///
/// Seeded with one link: the Standard User account (`usr_standard`) is mapped
/// to Lead assignee `agent-1`. All other CRM users are unmapped by default.
///
/// Tests may inject a custom [links] map to exercise alternative states.
class MockUserLeadLinkRepository implements UserLeadLinkRepository {
  final Map<String, String> _links;

  MockUserLeadLinkRepository({Map<String, String>? links})
    : _links = links ?? const {'usr_standard': 'agent-1', 'user': 'agent-1'};

  @override
  Future<UserLeadLink?> getLinkForUser(String crmUserId) {
    final assigneeId = _links[crmUserId];
    if (assigneeId == null) return Future.value(null);
    return Future.value(
      UserLeadLink(crmUserId: crmUserId, leadAssigneeId: assigneeId),
    );
  }
}
