import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_assignee.dart';
import '../../domain/entities/lead_assignment_request.dart';
import '../../domain/repositories/lead_repository.dart';
import 'lead_reassignment_state.dart';

/// Cubit managing assignable user loading and single lead reassignment.
class LeadReassignmentCubit extends Cubit<LeadReassignmentState> {
  final LeadRepository _repository;

  LeadReassignmentCubit(this._repository)
    : super(const LeadReassignmentState());

  /// Loads the list of assignable users from the repository.
  Future<void> loadAssignableUsers() async {
    emit(
      state.copyWith(
        loadStatus: AssigneeLoadStatus.loading,
        clearLoadErrorMessage: true,
      ),
    );

    try {
      final users = await _repository.getAssignableUsers();
      final userList = List<LeadAssignee>.unmodifiable(users);

      // Verify whether the currently selected assignee is still in the loaded list
      final selectedStillValid =
          state.selectedAssignee != null &&
          userList.any((u) => u.id == state.selectedAssignee!.id);

      emit(
        state.copyWith(
          loadStatus: AssigneeLoadStatus.success,
          assignees: userList,
          clearSelectedAssignee:
              !selectedStillValid && state.selectedAssignee != null,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          loadStatus: AssigneeLoadStatus.failure,
          loadErrorMessage: 'Unable to load assignable users.',
        ),
      );
    }
  }

  /// Selects a replacement assignee from the loaded assignable-user list.
  /// Rejects / ignores unknown assignees not present in the loaded list.
  void selectAssignee(LeadAssignee assignee) {
    final matchedIndex = state.assignees.indexWhere((a) => a.id == assignee.id);
    if (matchedIndex != -1) {
      emit(
        state.copyWith(
          selectedAssignee: state.assignees[matchedIndex],
          clearSubmissionErrorMessage: true,
        ),
      );
    }
  }

  /// Clears the current replacement selection without altering the lead repository.
  void clearSelectedAssignee() {
    emit(state.copyWith(clearSelectedAssignee: true));
  }

  /// Updates the optional reassignment reason.
  void updateReason(String? reason) {
    emit(state.copyWith(reason: reason, clearReason: reason == null));
  }

  /// Resets the submission status back to idle.
  void resetSubmission() {
    emit(
      state.copyWith(
        submissionStatus: ReassignmentSubmissionStatus.idle,
        clearSubmissionErrorMessage: true,
      ),
    );
  }

  /// Reassigns an already assigned lead to the selected replacement assignee.
  Future<void> reassignLead({required Lead lead, String? reason}) async {
    if (state.isSubmitting) return;

    // Unassigned Lead Guard
    if (!lead.isAssigned) {
      emit(
        state.copyWith(
          submissionStatus: ReassignmentSubmissionStatus.failure,
          submissionErrorMessage: 'This Lead is not currently assigned.',
        ),
      );
      return;
    }

    // Replacement Assignee Selection Guard
    if (state.selectedAssignee == null) {
      emit(
        state.copyWith(
          submissionStatus: ReassignmentSubmissionStatus.failure,
          submissionErrorMessage: 'Select a replacement assignee first.',
        ),
      );
      return;
    }

    // Same-Assignee Guard (Client-side no-op guard, not a frozen backend policy)
    if (state.selectedAssignee!.id == lead.assignedUserId) {
      emit(
        state.copyWith(
          submissionStatus: ReassignmentSubmissionStatus.failure,
          submissionErrorMessage: 'Select a different assignee.',
        ),
      );
      return;
    }

    // Assignee Safety Guard
    final isKnown = state.assignees.any(
      (a) => a.id == state.selectedAssignee!.id,
    );
    if (!isKnown) {
      emit(
        state.copyWith(
          submissionStatus: ReassignmentSubmissionStatus.failure,
          submissionErrorMessage: 'Select a valid assignable user.',
        ),
      );
      return;
    }

    // Reason normalization: trim whitespace, blank -> null
    final rawReason = reason ?? state.reason;
    final trimmed = rawReason?.trim();
    final normalizedReason = (trimmed != null && trimmed.isNotEmpty)
        ? trimmed
        : null;

    emit(
      state.copyWith(
        submissionStatus: ReassignmentSubmissionStatus.submitting,
        clearSubmissionErrorMessage: true,
        reason: normalizedReason,
      ),
    );

    try {
      await _repository.reassignLead(
        LeadReassignmentRequest(
          leadId: lead.id,
          newAssigneeId: state.selectedAssignee!.id,
          reason: normalizedReason,
        ),
      );
      emit(
        state.copyWith(submissionStatus: ReassignmentSubmissionStatus.success),
      );
    } catch (_) {
      emit(
        state.copyWith(
          submissionStatus: ReassignmentSubmissionStatus.failure,
          submissionErrorMessage: 'Unable to reassign the Lead.',
        ),
      );
    }
  }
}
