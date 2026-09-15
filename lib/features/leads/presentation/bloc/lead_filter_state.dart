import '../../domain/entities/lead_assignee.dart';

sealed class LeadFilterState {
  const LeadFilterState();
}

final class LeadFilterInitial extends LeadFilterState {
  const LeadFilterInitial();
}

final class LeadFilterLoading extends LeadFilterState {
  const LeadFilterLoading();
}

final class LeadFilterReady extends LeadFilterState {
  final List<LeadAssignee> assignees;

  const LeadFilterReady(this.assignees);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadFilterReady &&
          runtimeType == other.runtimeType &&
          _listEquals(assignees, other.assignees);

  @override
  int get hashCode => Object.hashAll(assignees);

  static bool _listEquals(List<LeadAssignee> a, List<LeadAssignee> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final class LeadFilterFailure extends LeadFilterState {
  final String message;

  const LeadFilterFailure(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadFilterFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}
