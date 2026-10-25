import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/mock_lead_comment_repository.dart';
import '../../domain/entities/lead_comment.dart';
import '../../domain/repositories/lead_comment_repository.dart';
import '../bloc/lead_comments_cubit.dart';
import '../bloc/lead_comments_state.dart';
import '../utils/lead_display_formatters.dart';

/// Reusable section displaying a timeline of timestamp-enabled comments on a lead,
/// along with an input area for users to add new timestamped comments.
class LeadCommentsSection extends StatefulWidget {
  final String leadId;
  final String currentUserName;
  final String? currentUserId;
  final LeadCommentRepository? repository;
  final LeadCommentsCubit? cubit;

  const LeadCommentsSection({
    super.key,
    required this.leadId,
    required this.currentUserName,
    this.currentUserId,
    this.repository,
    this.cubit,
  });

  @override
  State<LeadCommentsSection> createState() => _LeadCommentsSectionState();
}

class _LeadCommentsSectionState extends State<LeadCommentsSection> {
  late final LeadCommentsCubit _cubit;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _ownsCubit = false;

  @override
  void initState() {
    super.initState();
    if (widget.cubit != null) {
      _cubit = widget.cubit!;
    } else {
      _ownsCubit = true;
      final repo = widget.repository ?? MockLeadCommentRepository.instance;
      _cubit = LeadCommentsCubit(
        repository: repo,
        leadId: widget.leadId,
      )..loadComments();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    if (_ownsCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final success = await _cubit.addComment(
      content: text,
      authorName: widget.currentUserName,
      authorId: widget.currentUserId,
    );

    if (success && mounted) {
      _controller.clear();
      _focusNode.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment added successfully'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LeadCommentsCubit>.value(
      value: _cubit,
      child: BlocBuilder<LeadCommentsCubit, LeadCommentsState>(
        builder: (context, state) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          final comments = state is LeadCommentsLoaded ? state.comments : const <LeadComment>[];
          final isSubmitting = state is LeadCommentsLoaded && state.isSubmitting;
          final count = comments.length;

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(Icons.comment_outlined, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Comments & Notes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Comment Input
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TextField(
                          key: const Key('lead_comment_input'),
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Add a timestamped comment or note...',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          key: const Key('lead_comment_submit_button'),
                          onPressed: isSubmitting ? null : _submitComment,
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 14),
                          label: Text(isSubmitting ? 'Posting...' : 'Add Comment'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            textStyle: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Comments Timeline / List
                  if (state is LeadCommentsLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          key: Key('lead_comments_loading'),
                        ),
                      ),
                    )
                  else if (state is LeadCommentsFailure)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 18, color: colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.message,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (comments.isEmpty)
                    Container(
                      key: const Key('lead_comments_empty'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'No comments yet. Add the first comment above.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (int i = 0; i < comments.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _CommentCard(
                            comment: comments[i],
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final LeadComment comment;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _CommentCard({
    required this.comment,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final initial = comment.authorName.isNotEmpty
        ? comment.authorName[0].toUpperCase()
        : 'U';

    return Container(
      key: Key('lead_comment_item_${comment.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  initial,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  comment.authorName,
                  key: Key('lead_comment_author_${comment.id}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatLeadDateTime(comment.createdAt),
                    key: Key('lead_comment_timestamp_${comment.id}'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 32),
            child: SelectableText(
              comment.content,
              key: Key('lead_comment_content_${comment.id}'),
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
