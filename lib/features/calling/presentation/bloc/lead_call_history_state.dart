import 'package:flutter/foundation.dart';
import '../../domain/entities/lead_call_activity.dart';

@immutable
sealed class LeadCallHistoryState {
  const LeadCallHistoryState();
}

final class LeadCallHistoryInitial extends LeadCallHistoryState {
  const LeadCallHistoryInitial();
}

final class LeadCallHistoryLoading extends LeadCallHistoryState {
  const LeadCallHistoryLoading();
}

final class LeadCallHistoryAccessDenied extends LeadCallHistoryState {
  final String reason;
  const LeadCallHistoryAccessDenied(this.reason);
}

final class LeadCallHistoryEmpty extends LeadCallHistoryState {
  const LeadCallHistoryEmpty();
}

final class LeadCallHistoryLoaded extends LeadCallHistoryState {
  final List<LeadCallActivity> activities;
  const LeadCallHistoryLoaded(this.activities);
}

final class LeadCallHistoryFailure extends LeadCallHistoryState {
  final String message;
  const LeadCallHistoryFailure(this.message);
}
