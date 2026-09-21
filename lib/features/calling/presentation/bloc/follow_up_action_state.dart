import 'package:flutter/foundation.dart';
import '../../domain/entities/lead_follow_up.dart';

@immutable
sealed class FollowUpActionState {
  const FollowUpActionState();
}

final class FollowUpActionInitial extends FollowUpActionState {
  const FollowUpActionInitial();
}

final class FollowUpActionSubmitting extends FollowUpActionState {
  const FollowUpActionSubmitting();
}

final class FollowUpActionSuccess extends FollowUpActionState {
  final LeadFollowUp followUp;
  const FollowUpActionSuccess(this.followUp);
}

final class FollowUpActionFailure extends FollowUpActionState {
  final String message;
  const FollowUpActionFailure(this.message);
}

final class FollowUpActionAccessDenied extends FollowUpActionState {
  final String reason;
  const FollowUpActionAccessDenied(this.reason);
}
