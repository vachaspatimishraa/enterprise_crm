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
  final String? Function(String crmUserId)? _dynamicLinkResolver;

  MockUserLeadLinkRepository({
    Map<String, String>? links,
    String? Function(String crmUserId)? dynamicLinkResolver,
  }) : _links =
           links ??
           const {
             'usr_standard': 'agent-1',
             'user': 'agent-1',
             'usr_admin': 'agent-1',
             'admin': 'agent-1',
           },
       _dynamicLinkResolver = dynamicLinkResolver;

  @override
  Future<UserLeadLink?> getLinkForUser(String crmUserId) {
    final assigneeId =
        _dynamicLinkResolver?.call(crmUserId) ?? _links[crmUserId];
    if (assigneeId == null) return Future.value(null);
    return Future.value(
      UserLeadLink(crmUserId: crmUserId, leadAssigneeId: assigneeId),
    );
  }
}
