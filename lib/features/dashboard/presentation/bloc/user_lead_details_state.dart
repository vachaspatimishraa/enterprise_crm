import 'package:flutter/foundation.dart';
import '../../../leads/domain/entities/lead.dart';

@immutable
sealed class UserLeadDetailsState {
  const UserLeadDetailsState();
}

final class UserLeadDetailsInitial extends UserLeadDetailsState {
  const UserLeadDetailsInitial();
}

final class UserLeadDetailsLoading extends UserLeadDetailsState {
  const UserLeadDetailsLoading();
}

final class UserLeadDetailsAccessDenied extends UserLeadDetailsState {
  final String reason;
  const UserLeadDetailsAccessDenied(this.reason);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLeadDetailsAccessDenied && reason == other.reason;

  @override
  int get hashCode => reason.hashCode;
}

final class UserLeadDetailsLoaded extends UserLeadDetailsState {
  final Lead lead;
  final String linkedAssigneeId;
  final bool canEdit;

  const UserLeadDetailsLoaded({
    required this.lead,
    required this.linkedAssigneeId,
    required this.canEdit,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLeadDetailsLoaded &&
          lead == other.lead &&
          linkedAssigneeId == other.linkedAssigneeId &&
          canEdit == other.canEdit;

  @override
  int get hashCode => Object.hash(lead, linkedAssigneeId, canEdit);
}

final class UserLeadDetailsFailure extends UserLeadDetailsState {
  final String message;
  const UserLeadDetailsFailure(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLeadDetailsFailure && message == other.message;

  @override
  int get hashCode => message.hashCode;
}
