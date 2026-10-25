import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/lead_comment_repository.dart';
import 'lead_comments_state.dart';

/// Cubit managing loading and appending timestamp-enabled comments on a specific lead.
class LeadCommentsCubit extends Cubit<LeadCommentsState> {
  final LeadCommentRepository _repository;
  final String leadId;

  LeadCommentsCubit({
    required LeadCommentRepository repository,
    required this.leadId,
  })  : _repository = repository,
        super(const LeadCommentsInitial());

  /// Loads comments for this lead.
  Future<void> loadComments() async {
    emit(const LeadCommentsLoading());
    try {
      final comments = await _repository.getComments(leadId);
      emit(LeadCommentsLoaded(comments));
    } catch (e) {
      emit(LeadCommentsFailure(e.toString()));
    }
  }

  /// Appends a new timestamped comment.
  ///
  /// Returns `true` if the comment was successfully saved, `false` otherwise.
  Future<bool> addComment({
    required String content,
    required String authorName,
    String? authorId,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;

    final currentState = state;
    if (currentState is LeadCommentsLoaded) {
      emit(currentState.copyWith(isSubmitting: true, clearError: true));
    }

    try {
      final created = await _repository.addComment(
        leadId: leadId,
        authorName: authorName,
        authorId: authorId,
        content: trimmed,
      );

      if (state is LeadCommentsLoaded) {
        final existing = (state as LeadCommentsLoaded).comments;
        emit(
          LeadCommentsLoaded(
            [created, ...existing.where((c) => c.id != created.id)],
            isSubmitting: false,
          ),
        );
      } else {
        emit(LeadCommentsLoaded([created], isSubmitting: false));
      }
      return true;
    } catch (e) {
      if (state is LeadCommentsLoaded) {
        emit(
          (state as LeadCommentsLoaded).copyWith(
            isSubmitting: false,
            error: e.toString(),
          ),
        );
      } else {
        emit(LeadCommentsFailure(e.toString()));
      }
      return false;
    }
  }
}
