import 'package:flutter/foundation.dart';
import '../../domain/entities/lead_comment.dart';

@immutable
sealed class LeadCommentsState {
  const LeadCommentsState();
}

final class LeadCommentsInitial extends LeadCommentsState {
  const LeadCommentsInitial();
}

final class LeadCommentsLoading extends LeadCommentsState {
  const LeadCommentsLoading();
}

final class LeadCommentsLoaded extends LeadCommentsState {
  final List<LeadComment> comments;
  final bool isSubmitting;
  final String? error;

  const LeadCommentsLoaded(
    this.comments, {
    this.isSubmitting = false,
    this.error,
  });

  LeadCommentsLoaded copyWith({
    List<LeadComment>? comments,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) {
    return LeadCommentsLoaded(
      comments ?? this.comments,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadCommentsLoaded &&
          runtimeType == other.runtimeType &&
          listEquals(comments, other.comments) &&
          isSubmitting == other.isSubmitting &&
          error == other.error;

  @override
  int get hashCode => Object.hash(Object.hashAll(comments), isSubmitting, error);
}

final class LeadCommentsFailure extends LeadCommentsState {
  final String message;

  const LeadCommentsFailure(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadCommentsFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}
