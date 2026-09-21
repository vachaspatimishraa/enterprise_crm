import '../../domain/entities/follow_up_event.dart';
import '../../domain/entities/follow_up_status.dart';
import '../../domain/entities/lead_follow_up.dart';
import '../../domain/repositories/lead_follow_up_repository.dart';
import 'mock_lead_call_activity_repository.dart';

/// In-memory implementation of [LeadFollowUpRepository] for tests and local application runtime.
class MockLeadFollowUpRepository implements LeadFollowUpRepository {
  final NowProvider _now;
  final List<LeadFollowUp> _followUps = [];
  final List<FollowUpEvent> _events = [];
  int _followUpIdCounter = 1;
  int _eventIdCounter = 1;

  MockLeadFollowUpRepository({
    NowProvider? now,
    List<LeadFollowUp>? initialFollowUps,
    List<FollowUpEvent>? initialEvents,
  }) : _now = now ?? DateTime.now {
    if (initialFollowUps != null) {
      _followUps.addAll(initialFollowUps);
      _followUpIdCounter = _followUps.length + 1;
    }
    if (initialEvents != null) {
      _events.addAll(initialEvents);
      _eventIdCounter = _events.length + 1;
    }
  }

  /// Direct inspection of all follow-ups for test assertions.
  List<LeadFollowUp> get recordedFollowUps => List.unmodifiable(_followUps);

  /// Direct inspection of all recorded events for test assertions.
  List<FollowUpEvent> get recordedEvents => List.unmodifiable(_events);

  @override
  Future<LeadFollowUp> createFollowUp({
    required String leadId,
    required String sourceCallActivityId,
    required DateTime scheduledAt,
    required String performedByUserId,
  }) async {
    if (leadId.trim().isEmpty) {
      throw ArgumentError.value(leadId, 'leadId', 'Lead ID cannot be empty');
    }
    if (sourceCallActivityId.trim().isEmpty) {
      throw ArgumentError.value(
        sourceCallActivityId,
        'sourceCallActivityId',
        'Source Call Activity ID cannot be empty',
      );
    }

    // Enforce exactly one Follow-Up per sourceCallActivityId
    final alreadyExists = _followUps.any(
      (f) => f.sourceCallActivityId == sourceCallActivityId,
    );
    if (alreadyExists) {
      throw StateError(
        'A follow-up already exists for source call activity $sourceCallActivityId',
      );
    }

    final followUpId = 'follow-up-$_followUpIdCounter';
    _followUpIdCounter++;

    final now = _now();
    final followUp = LeadFollowUp(
      id: followUpId,
      leadId: leadId,
      sourceCallActivityId: sourceCallActivityId,
      scheduledAt: scheduledAt,
      status: FollowUpStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    _followUps.add(followUp);

    final eventId = 'follow-up-event-$_eventIdCounter';
    _eventIdCounter++;
    final event = FollowUpEvent(
      id: eventId,
      followUpId: followUpId,
      type: FollowUpEventType.created,
      performedByUserId: performedByUserId,
      createdAt: now,
      newScheduledAt: scheduledAt,
    );
    _events.add(event);

    return followUp;
  }

  @override
  Future<List<LeadFollowUp>> getFollowUpsForLeadIds(
    Set<String> leadIds,
  ) async {
    if (leadIds.isEmpty) {
      return const [];
    }

    final matching =
        _followUps.where((f) => leadIds.contains(f.leadId)).toList();

    // Sort earliest scheduledAt first. Tie-break by ID ascending.
    matching.sort((a, b) {
      final cmp = a.scheduledAt.compareTo(b.scheduledAt);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    return List<LeadFollowUp>.unmodifiable(matching);
  }

  @override
  Future<LeadFollowUp?> getFollowUpById(String id) async {
    final index = _followUps.indexWhere((f) => f.id == id);
    if (index == -1) return null;
    return _followUps[index];
  }

  @override
  Future<LeadFollowUp> completeFollowUp({
    required String followUpId,
    required String performedByUserId,
  }) async {
    final index = _followUps.indexWhere((f) => f.id == followUpId);
    if (index == -1) {
      throw StateError('Follow-up with ID $followUpId not found');
    }

    final existing = _followUps[index];
    if (existing.status != FollowUpStatus.pending) {
      throw StateError(
        'Cannot complete follow-up in ${existing.status.name} state',
      );
    }

    final now = _now();
    final updated = LeadFollowUp(
      id: existing.id,
      leadId: existing.leadId,
      sourceCallActivityId: existing.sourceCallActivityId,
      scheduledAt: existing.scheduledAt,
      status: FollowUpStatus.completed,
      createdAt: existing.createdAt,
      updatedAt: now,
      completedAt: now,
      cancelledAt: existing.cancelledAt,
    );

    _followUps[index] = updated;

    final eventId = 'follow-up-event-$_eventIdCounter';
    _eventIdCounter++;
    final event = FollowUpEvent(
      id: eventId,
      followUpId: existing.id,
      type: FollowUpEventType.completed,
      performedByUserId: performedByUserId,
      createdAt: now,
    );
    _events.add(event);

    return updated;
  }

  @override
  Future<LeadFollowUp> cancelFollowUp({
    required String followUpId,
    required String performedByUserId,
  }) async {
    final index = _followUps.indexWhere((f) => f.id == followUpId);
    if (index == -1) {
      throw StateError('Follow-up with ID $followUpId not found');
    }

    final existing = _followUps[index];
    if (existing.status != FollowUpStatus.pending) {
      throw StateError(
        'Cannot cancel follow-up in ${existing.status.name} state',
      );
    }

    final now = _now();
    final updated = LeadFollowUp(
      id: existing.id,
      leadId: existing.leadId,
      sourceCallActivityId: existing.sourceCallActivityId,
      scheduledAt: existing.scheduledAt,
      status: FollowUpStatus.cancelled,
      createdAt: existing.createdAt,
      updatedAt: now,
      completedAt: existing.completedAt,
      cancelledAt: now,
    );

    _followUps[index] = updated;

    final eventId = 'follow-up-event-$_eventIdCounter';
    _eventIdCounter++;
    final event = FollowUpEvent(
      id: eventId,
      followUpId: existing.id,
      type: FollowUpEventType.cancelled,
      performedByUserId: performedByUserId,
      createdAt: now,
    );
    _events.add(event);

    return updated;
  }

  @override
  Future<LeadFollowUp> rescheduleFollowUp({
    required String followUpId,
    required DateTime scheduledAt,
    required String performedByUserId,
  }) async {
    final index = _followUps.indexWhere((f) => f.id == followUpId);
    if (index == -1) {
      throw StateError('Follow-up with ID $followUpId not found');
    }

    final existing = _followUps[index];
    if (existing.status != FollowUpStatus.pending) {
      throw StateError(
        'Cannot reschedule follow-up in ${existing.status.name} state',
      );
    }

    final now = _now();
    if (!scheduledAt.isAfter(now)) {
      throw ArgumentError.value(
        scheduledAt,
        'scheduledAt',
        'Reschedule date and time must be in the future',
      );
    }

    final previousScheduledAt = existing.scheduledAt;
    final updated = LeadFollowUp(
      id: existing.id,
      leadId: existing.leadId,
      sourceCallActivityId: existing.sourceCallActivityId,
      scheduledAt: scheduledAt,
      status: FollowUpStatus.pending,
      createdAt: existing.createdAt,
      updatedAt: now,
      completedAt: existing.completedAt,
      cancelledAt: existing.cancelledAt,
    );

    _followUps[index] = updated;

    final eventId = 'follow-up-event-$_eventIdCounter';
    _eventIdCounter++;
    final event = FollowUpEvent(
      id: eventId,
      followUpId: existing.id,
      type: FollowUpEventType.rescheduled,
      performedByUserId: performedByUserId,
      createdAt: now,
      previousScheduledAt: previousScheduledAt,
      newScheduledAt: scheduledAt,
    );
    _events.add(event);

    return updated;
  }

  @override
  Future<List<FollowUpEvent>> getEventsForFollowUp(
    String followUpId,
  ) async {
    final matching =
        _events.where((e) => e.followUpId == followUpId).toList();

    // Sort chronological ascending
    matching.sort((a, b) {
      final cmp = a.createdAt.compareTo(b.createdAt);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    return List<FollowUpEvent>.unmodifiable(matching);
  }
}
