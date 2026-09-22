import 'package:flutter/foundation.dart';
import '../../domain/entities/follow_up_event.dart';
import '../../domain/entities/lead_follow_up.dart';

/// Container combining a [LeadFollowUp] and its lifecycle [FollowUpEvent] records.
@immutable
class FollowUpWithEvents {
  final LeadFollowUp followUp;
  final List<FollowUpEvent> events;

  const FollowUpWithEvents({required this.followUp, required this.events});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowUpWithEvents &&
          runtimeType == other.runtimeType &&
          followUp == other.followUp &&
          listEquals(events, other.events);

  @override
  int get hashCode => Object.hash(followUp, Object.hashAll(events));
}

@immutable
sealed class LeadFollowUpHistoryState {
  const LeadFollowUpHistoryState();
}

final class LeadFollowUpHistoryInitial extends LeadFollowUpHistoryState {
  const LeadFollowUpHistoryInitial();
}

final class LeadFollowUpHistoryLoading extends LeadFollowUpHistoryState {
  const LeadFollowUpHistoryLoading();
}

final class LeadFollowUpHistoryEmpty extends LeadFollowUpHistoryState {
  const LeadFollowUpHistoryEmpty();
}

final class LeadFollowUpHistoryLoaded extends LeadFollowUpHistoryState {
  final List<FollowUpWithEvents> items;
  const LeadFollowUpHistoryLoaded(this.items);
}

final class LeadFollowUpHistoryAccessDenied extends LeadFollowUpHistoryState {
  final String reason;
  const LeadFollowUpHistoryAccessDenied(this.reason);
}

final class LeadFollowUpHistoryFailure extends LeadFollowUpHistoryState {
  final String message;
  const LeadFollowUpHistoryFailure(this.message);
}
