import '../../domain/entities/lead_assignee.dart';

/// Loading status of assignable users for reassignment.
enum AssigneeLoadStatus { initial, loading, success, failure }

/// Submission status of a lead reassignment operation.
enum ReassignmentSubmissionStatus { idle, submitting, success, failure }

/// State for lead reassignment.
class LeadReassignmentState {
  final AssigneeLoadStatus loadStatus;
  final ReassignmentSubmissionStatus submissionStatus;
  final List<LeadAssignee> assignees;
  final LeadAssignee? selectedAssignee;
  final String? reason;
  final String? loadErrorMessage;
  final String? submissionErrorMessage;

  const LeadReassignmentState({
    this.loadStatus = AssigneeLoadStatus.initial,
    this.submissionStatus = ReassignmentSubmissionStatus.idle,
    this.assignees = const [],
    this.selectedAssignee,
    this.reason,
    this.loadErrorMessage,
    this.submissionErrorMessage,
  });

  bool get isLoadingAssignees => loadStatus == AssigneeLoadStatus.loading;
  bool get hasLoadError => loadStatus == AssigneeLoadStatus.failure;
  bool get isSubmitting =>
      submissionStatus == ReassignmentSubmissionStatus.submitting;
  bool get isSubmissionSuccess =>
      submissionStatus == ReassignmentSubmissionStatus.success;
  bool get hasSubmissionError =>
      submissionStatus == ReassignmentSubmissionStatus.failure;
  bool get canSubmit => selectedAssignee != null && !isSubmitting;

  LeadReassignmentState copyWith({
    AssigneeLoadStatus? loadStatus,
    ReassignmentSubmissionStatus? submissionStatus,
    List<LeadAssignee>? assignees,
    LeadAssignee? selectedAssignee,
    bool clearSelectedAssignee = false,
    String? reason,
    bool clearReason = false,
    String? loadErrorMessage,
    bool clearLoadErrorMessage = false,
    String? submissionErrorMessage,
    bool clearSubmissionErrorMessage = false,
  }) {
    return LeadReassignmentState(
      loadStatus: loadStatus ?? this.loadStatus,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      assignees: assignees ?? this.assignees,
      selectedAssignee: clearSelectedAssignee
          ? null
          : (selectedAssignee ?? this.selectedAssignee),
      reason: clearReason ? null : (reason ?? this.reason),
      loadErrorMessage: clearLoadErrorMessage
          ? null
          : (loadErrorMessage ?? this.loadErrorMessage),
      submissionErrorMessage: clearSubmissionErrorMessage
          ? null
          : (submissionErrorMessage ?? this.submissionErrorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadReassignmentState &&
          runtimeType == other.runtimeType &&
          loadStatus == other.loadStatus &&
          submissionStatus == other.submissionStatus &&
          _listEquals(assignees, other.assignees) &&
          selectedAssignee == other.selectedAssignee &&
          reason == other.reason &&
          loadErrorMessage == other.loadErrorMessage &&
          submissionErrorMessage == other.submissionErrorMessage;

  @override
  int get hashCode => Object.hash(
    loadStatus,
    submissionStatus,
    Object.hashAll(assignees),
    selectedAssignee,
    reason,
    loadErrorMessage,
    submissionErrorMessage,
  );

  static bool _listEquals(List<LeadAssignee> a, List<LeadAssignee> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
