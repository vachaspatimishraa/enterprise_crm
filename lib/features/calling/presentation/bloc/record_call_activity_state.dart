import 'package:flutter/foundation.dart';
import '../../../leads/domain/entities/lead.dart';
import '../../domain/entities/lead_call_activity.dart';

@immutable
sealed class RecordCallActivityState {
  const RecordCallActivityState();
}

final class RecordCallActivityInitial extends RecordCallActivityState {
  const RecordCallActivityInitial();
}

final class RecordCallActivityLoading extends RecordCallActivityState {
  const RecordCallActivityLoading();
}

final class RecordCallActivityAccessDenied extends RecordCallActivityState {
  final String reason;
  const RecordCallActivityAccessDenied(this.reason);
}

final class RecordCallActivityReady extends RecordCallActivityState {
  final Lead lead;
  final String linkedAssigneeId;
  const RecordCallActivityReady({
    required this.lead,
    required this.linkedAssigneeId,
  });
}

final class RecordCallActivitySubmitting extends RecordCallActivityState {
  final Lead lead;
  final String linkedAssigneeId;
  const RecordCallActivitySubmitting({
    required this.lead,
    required this.linkedAssigneeId,
  });
}

final class RecordCallActivitySuccess extends RecordCallActivityState {
  final LeadCallActivity activity;
  const RecordCallActivitySuccess(this.activity);
}

final class RecordCallActivityFailure extends RecordCallActivityState {
  final Lead lead;
  final String linkedAssigneeId;
  final String message;
  const RecordCallActivityFailure({
    required this.lead,
    required this.linkedAssigneeId,
    required this.message,
  });
}
