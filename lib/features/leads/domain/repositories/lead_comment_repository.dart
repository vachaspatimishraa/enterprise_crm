import '../entities/lead_comment.dart';

/// Repository interface for retrieving and adding timestamp-enabled comments on leads.
abstract interface class LeadCommentRepository {
  /// Retrieves all comments associated with [leadId], ordered chronologically (newest first).
  Future<List<LeadComment>> getComments(String leadId);

  /// Appends a new timestamp-enabled comment to [leadId].
  Future<LeadComment> addComment({
    required String leadId,
    required String authorName,
    String? authorId,
    required String content,
  });
}
