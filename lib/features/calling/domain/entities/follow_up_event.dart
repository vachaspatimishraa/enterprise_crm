import 'package:flutter/foundation.dart';

/// Types of lifecycle events recorded for a scheduled follow-up.
enum FollowUpEventType {
  created,
  rescheduled,
  completed,
  cancelled,
}

/// Pure immutable domain event recording a lifecycle transition of a [LeadFollowUp].
@immutable
class FollowUpEvent {
  /// Unique identifier of this lifecycle event (e.g. `follow-up-event-1`).
  final String id;

  /// Foreign key referencing the parent [LeadFollowUp].
  final String followUpId;

  /// The type of lifecycle event.
  final FollowUpEventType type;

  /// CRM User ID of the user who performed this lifecycle action.
  final String performedByUserId;

  /// Timestamp when this event occurred.
  final DateTime createdAt;

  /// The previous scheduled date/time (populated when rescheduled; null otherwise).
  final DateTime? previousScheduledAt;

  /// The new scheduled date/time (populated when created or rescheduled; null otherwise).
  final DateTime? newScheduledAt;

  const FollowUpEvent({
    required this.id,
    required this.followUpId,
    required this.type,
    required this.performedByUserId,
    required this.createdAt,
    this.previousScheduledAt,
    this.newScheduledAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowUpEvent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          followUpId == other.followUpId &&
          type == other.type &&
          performedByUserId == other.performedByUserId &&
          createdAt == other.createdAt &&
          previousScheduledAt == other.previousScheduledAt &&
          newScheduledAt == other.newScheduledAt;

  @override
  int get hashCode => Object.hash(
        id,
        followUpId,
        type,
        performedByUserId,
        createdAt,
        previousScheduledAt,
        newScheduledAt,
      );

  @override
  String toString() =>
      'FollowUpEvent(id: $id, followUpId: $followUpId, type: $type, performedByUserId: $performedByUserId, createdAt: $createdAt, previousScheduledAt: $previousScheduledAt, newScheduledAt: $newScheduledAt)';
}
