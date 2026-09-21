import 'package:flutter/foundation.dart';
import 'call_outcome.dart';

/// Pure immutable domain entity representing a recorded call activity against a Lead.
@immutable
class LeadCallActivity {
  /// Unique identifier of the activity record (e.g. `call-act-1`).
  final String id;

  /// ID of the Lead this call activity belongs to.
  final String leadId;

  /// CRM User ID of the user who performed and recorded this call activity.
  final String performedByUserId;

  /// The outcome of the call.
  final CallOutcome outcome;

  /// Optional scheduled follow-up or visit date/time, stored separately from outcome.
  final DateTime? rescheduleAt;

  /// Timestamp when this activity record was created.
  final DateTime createdAt;

  const LeadCallActivity({
    required this.id,
    required this.leadId,
    required this.performedByUserId,
    required this.outcome,
    this.rescheduleAt,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadCallActivity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          leadId == other.leadId &&
          performedByUserId == other.performedByUserId &&
          outcome == other.outcome &&
          rescheduleAt == other.rescheduleAt &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    leadId,
    performedByUserId,
    outcome,
    rescheduleAt,
    createdAt,
  );

  @override
  String toString() =>
      'LeadCallActivity(id: $id, leadId: $leadId, performedByUserId: $performedByUserId, outcome: $outcome, rescheduleAt: $rescheduleAt, createdAt: $createdAt)';
}
