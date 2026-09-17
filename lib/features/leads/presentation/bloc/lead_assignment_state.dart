import '../../domain/entities/lead_assignee.dart';

/// Loading status of assignable users.
enum AssigneeLoadStatus { initial, loading, success, failure }

/// Submission status of a lead assignment operation.
enum AssignmentSubmissionStatus { idle, submitting, success, failure }

/// State for lead assignment and distribution.
class LeadAssignmentState {
  final AssigneeLoadStatus loadStatus;
  final AssignmentSubmissionStatus submissionStatus;
  final List<LeadAssignee> assignees;
  final LeadAssignee? selectedAssignee;
  final String? loadErrorMessage;
  final String? submissionErrorMessage;

  const LeadAssignmentState({
    this.loadStatus = AssigneeLoadStatus.initial,
    this.submissionStatus = AssignmentSubmissionStatus.idle,
    this.assignees = const [],
    this.selectedAssignee,
    this.loadErrorMessage,
    this.submissionErrorMessage,
  });

  bool get isLoadingAssignees => loadStatus == AssigneeLoadStatus.loading;
  bool get hasLoadError => loadStatus == AssigneeLoadStatus.failure;
  bool get isSubmitting =>
      submissionStatus == AssignmentSubmissionStatus.submitting;
  bool get isSubmissionSuccess =>
      submissionStatus == AssignmentSubmissionStatus.success;
  bool get hasSubmissionError =>
      submissionStatus == AssignmentSubmissionStatus.failure;
  bool get canSubmit => selectedAssignee != null && !isSubmitting;

  LeadAssignmentState copyWith({
    AssigneeLoadStatus? loadStatus,
    AssignmentSubmissionStatus? submissionStatus,
    List<LeadAssignee>? assignees,
    LeadAssignee? selectedAssignee,
    bool clearSelectedAssignee = false,
    String? loadErrorMessage,
    bool clearLoadErrorMessage = false,
    String? submissionErrorMessage,
    bool clearSubmissionErrorMessage = false,
  }) {
    return LeadAssignmentState(
      loadStatus: loadStatus ?? this.loadStatus,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      assignees: assignees ?? this.assignees,
      selectedAssignee: clearSelectedAssignee
          ? null
          : (selectedAssignee ?? this.selectedAssignee),
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
      other is LeadAssignmentState &&
          runtimeType == other.runtimeType &&
          loadStatus == other.loadStatus &&
          submissionStatus == other.submissionStatus &&
          _listEquals(assignees, other.assignees) &&
          selectedAssignee == other.selectedAssignee &&
          loadErrorMessage == other.loadErrorMessage &&
          submissionErrorMessage == other.submissionErrorMessage;

  @override
  int get hashCode => Object.hash(
    loadStatus,
    submissionStatus,
    Object.hashAll(assignees),
    selectedAssignee,
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
