import 'package:flutter/foundation.dart';
import '../../../leads/domain/entities/lead.dart';

@immutable
sealed class UserLeadEditState {
  const UserLeadEditState();
}

final class UserLeadEditInitial extends UserLeadEditState {
  const UserLeadEditInitial();
}

final class UserLeadEditLoading extends UserLeadEditState {
  const UserLeadEditLoading();
}

final class UserLeadEditAccessDenied extends UserLeadEditState {
  final String reason;
  const UserLeadEditAccessDenied(this.reason);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLeadEditAccessDenied && reason == other.reason;

  @override
  int get hashCode => reason.hashCode;
}

final class UserLeadEditReady extends UserLeadEditState {
  final Lead lead;
  final String linkedAssigneeId;

  const UserLeadEditReady({required this.lead, required this.linkedAssigneeId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLeadEditReady &&
          lead == other.lead &&
          linkedAssigneeId == other.linkedAssigneeId;

  @override
  int get hashCode => Object.hash(lead, linkedAssigneeId);
}

final class UserLeadEditSubmitting extends UserLeadEditState {
  final Lead lead;
  final String linkedAssigneeId;

  const UserLeadEditSubmitting({
    required this.lead,
    required this.linkedAssigneeId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLeadEditSubmitting &&
          lead == other.lead &&
          linkedAssigneeId == other.linkedAssigneeId;

  @override
  int get hashCode => Object.hash(lead, linkedAssigneeId);
}

final class UserLeadEditSuccess extends UserLeadEditState {
  final Lead updatedLead;
  const UserLeadEditSuccess(this.updatedLead);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLeadEditSuccess && updatedLead == other.updatedLead;

  @override
  int get hashCode => updatedLead.hashCode;
}

final class UserLeadEditFailure extends UserLeadEditState {
  final String message;
  final Lead lead;
  final String linkedAssigneeId;

  const UserLeadEditFailure({
    required this.message,
    required this.lead,
    required this.linkedAssigneeId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLeadEditFailure &&
          message == other.message &&
          lead == other.lead &&
          linkedAssigneeId == other.linkedAssigneeId;

  @override
  int get hashCode => Object.hash(message, lead, linkedAssigneeId);
}
