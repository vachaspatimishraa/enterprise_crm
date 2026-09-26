import 'package:flutter/foundation.dart';
import 'follow_up_status.dart';

/// Pure immutable domain entity representing actionable scheduled work created from a Call Activity.
@immutable
class LeadFollowUp {
  /// Unique identifier of the follow-up (e.g. `follow-up-1`).
  final String id;

  /// Foreign key referencing the Lead this follow-up is scheduled for.
  final String leadId;

  /// Historical Call Activity that originally scheduled this work.
  final String sourceCallActivityId;

  /// The timestamp when this follow-up is currently scheduled to take place.
  final DateTime scheduledAt;

  /// The current lifecycle status (`pending`, `completed`, or `cancelled`).
  final FollowUpStatus status;

  /// When this follow-up record was created.
  final DateTime createdAt;

  /// When this follow-up record was last updated.
  final DateTime updatedAt;

  /// When this follow-up was completed (if completed).
  final DateTime? completedAt;

  /// When this follow-up was cancelled (if cancelled).
  final DateTime? cancelledAt;

  const LeadFollowUp({
    required this.id,
    required this.leadId,
    required this.sourceCallActivityId,
    required this.scheduledAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.cancelledAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadFollowUp &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          leadId == other.leadId &&
          sourceCallActivityId == other.sourceCallActivityId &&
          scheduledAt == other.scheduledAt &&
          status == other.status &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          completedAt == other.completedAt &&
          cancelledAt == other.cancelledAt;

  @override
  int get hashCode => Object.hash(
    id,
    leadId,
    sourceCallActivityId,
    scheduledAt,
    status,
    createdAt,
    updatedAt,
    completedAt,
    cancelledAt,
  );

  @override
  String toString() =>
      'LeadFollowUp(id: $id, leadId: $leadId, sourceCallActivityId: $sourceCallActivityId, scheduledAt: $scheduledAt, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, completedAt: $completedAt, cancelledAt: $cancelledAt)';
}
