import 'package:flutter/foundation.dart';

/// Immutable domain entity representing a timestamp-enabled comment or note on a Lead.
@immutable
class LeadComment {
  final String id;
  final String leadId;
  final String authorName;
  final String? authorId;
  final String content;
  final DateTime createdAt;

  const LeadComment({
    required this.id,
    required this.leadId,
    required this.authorName,
    this.authorId,
    required this.content,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadComment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          leadId == other.leadId &&
          authorName == other.authorName &&
          authorId == other.authorId &&
          content == other.content &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      Object.hash(id, leadId, authorName, authorId, content, createdAt);
}
