import '../../domain/entities/call_outcome.dart';
import '../../domain/entities/lead_call_activity.dart';
import '../../domain/repositories/lead_call_activity_repository.dart';

/// Function signature for providing the current timestamp deterministically.
typedef NowProvider = DateTime Function();

/// In-memory implementation of [LeadCallActivityRepository] for testing and local runtime.
class MockLeadCallActivityRepository implements LeadCallActivityRepository {
  final NowProvider _now;
  final List<LeadCallActivity> _activities = [];
  int _idCounter = 1;

  MockLeadCallActivityRepository({
    NowProvider? now,
    List<LeadCallActivity>? initialActivities,
  }) : _now = now ?? DateTime.now {
    if (initialActivities != null) {
      _activities.addAll(initialActivities);
      _idCounter = _activities.length + 1;
    }
  }

  /// Direct inspection of all recorded activities in mock for testing assertions.
  List<LeadCallActivity> get recordedActivities =>
      List.unmodifiable(_activities);

  @override
  Future<List<LeadCallActivity>> getActivitiesForLead(String leadId) async {
    final matching = _activities.where((a) => a.leadId == leadId).toList();

    // Sort newest-first. Tie-break by ID descending if timestamps are identical.
    matching.sort((a, b) {
      final cmp = b.createdAt.compareTo(a.createdAt);
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    });

    return List<LeadCallActivity>.unmodifiable(matching);
  }

  @override
  Future<List<LeadCallActivity>> getScheduledActivitiesForLeadIds(
    Set<String> leadIds,
  ) async {
    if (leadIds.isEmpty) {
      return const [];
    }

    final matching = _activities
        .where((a) => leadIds.contains(a.leadId) && a.rescheduleAt != null)
        .toList();

    // Sort earliest rescheduleAt first. Tie-break by ID ascending.
    matching.sort((a, b) {
      final cmp = a.rescheduleAt!.compareTo(b.rescheduleAt!);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    return List<LeadCallActivity>.unmodifiable(matching);
  }

  @override
  Future<LeadCallActivity> recordActivity({
    required String leadId,
    required String performedByUserId,
    required CallOutcome outcome,
    DateTime? rescheduleAt,
  }) async {
    if (leadId.trim().isEmpty) {
      throw ArgumentError.value(leadId, 'leadId', 'Lead ID cannot be empty');
    }

    final id = 'call-act-$_idCounter';
    _idCounter++;

    final activity = LeadCallActivity(
      id: id,
      leadId: leadId,
      performedByUserId: performedByUserId,
      outcome: outcome,
      rescheduleAt: rescheduleAt,
      createdAt: _now(),
    );

    _activities.add(activity);
    return activity;
  }

  /// Internal mock-only compensation mechanism to undo uncommitted call activity
  /// if downstream follow-up creation fails in [MockCallingWorkflowService].
  ///
  /// This is not part of the domain [LeadCallActivityRepository] interface.
  void rollbackActivityForMockAtomicity(String activityId) {
    _activities.removeWhere((a) => a.id == activityId);
  }
}
