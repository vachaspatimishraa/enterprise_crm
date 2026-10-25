import '../../domain/entities/lead_comment.dart';
import '../../domain/repositories/lead_comment_repository.dart';

/// In-memory mock implementation of [LeadCommentRepository] with seed data and persistence across the app session.
class MockLeadCommentRepository implements LeadCommentRepository {
  static final MockLeadCommentRepository instance =
      MockLeadCommentRepository.seeded();

  final List<LeadComment> _comments = [];
  final DateTime Function() _now;
  int _idCounter = 1;

  MockLeadCommentRepository({
    List<LeadComment>? initialComments,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    if (initialComments != null) {
      _comments.addAll(initialComments);
      _idCounter = _comments.length + 1;
    }
  }

  factory MockLeadCommentRepository.seeded({DateTime Function()? now}) {
    final effectiveNow = now ?? DateTime.now;
    final currentTime = effectiveNow();

    return MockLeadCommentRepository(
      now: effectiveNow,
      initialComments: [
        LeadComment(
          id: 'lead-comm-1',
          leadId: 'mock-lead-1',
          authorName: 'Admin',
          authorId: 'admin-1',
          content: 'Prospect requested enterprise deployment quote and SLA details.',
          createdAt: currentTime.subtract(const Duration(days: 1, hours: 2)),
        ),
        LeadComment(
          id: 'lead-comm-2',
          leadId: 'mock-lead-1',
          authorName: 'Mock Agent One',
          authorId: 'agent-1',
          content: 'Follow-up call completed. Technical requirements shared with solution team.',
          createdAt: currentTime.subtract(const Duration(hours: 3, minutes: 15)),
        ),
        LeadComment(
          id: 'lead-comm-3',
          leadId: 'mock-lead-2',
          authorName: 'Admin',
          authorId: 'admin-1',
          content: 'Initial discovery meeting scheduled for next Monday.',
          createdAt: currentTime.subtract(const Duration(days: 2)),
        ),
      ],
    );
  }

  @override
  Future<List<LeadComment>> getComments(String leadId) async {
    return _comments
        .where((c) => c.leadId == leadId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<LeadComment> addComment({
    required String leadId,
    required String authorName,
    String? authorId,
    required String content,
  }) async {
    final comment = LeadComment(
      id: 'lead-comm-${_idCounter++}',
      leadId: leadId,
      authorName: authorName,
      authorId: authorId,
      content: content,
      createdAt: _now(),
    );
    _comments.add(comment);
    return comment;
  }
}
