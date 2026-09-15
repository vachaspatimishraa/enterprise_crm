import 'package:flutter/material.dart';

class LeadPaginationControls extends StatelessWidget {
  final int currentPage;
  final int pageSize;
  final int totalItems;
  final bool hasNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const LeadPaginationControls({
    super.key,
    required this.currentPage,
    required this.pageSize,
    required this.totalItems,
    required this.hasNext,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalPages = (totalItems + pageSize - 1) ~/ pageSize;
    final start = ((currentPage - 1) * pageSize) + 1;
    final end = (currentPage * pageSize) > totalItems
        ? totalItems
        : (currentPage * pageSize);
    final canGoPrevious = currentPage > 1 && onPrevious != null;
    final canGoNext = hasNext && onNext != null;

    final rangeText = Text(
      '$start–$end of $totalItems leads',
      key: const Key('pagination_range_text'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );

    final pageText = Text(
      'Page $currentPage of $totalPages',
      key: const Key('pagination_page_text'),
      maxLines: 1,
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );

    final previousButton = OutlinedButton.icon(
      key: const Key('pagination_previous_button'),
      onPressed: canGoPrevious ? onPrevious : null,
      icon: const Icon(Icons.chevron_left, size: 16),
      label: const Text(
        'Previous',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );

    final nextButton = OutlinedButton(
      key: const Key('pagination_next_button'),
      onPressed: canGoNext ? onNext : null,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Next', maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 16),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withAlpha(120)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 768;

          if (isCompact) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: rangeText),
                      const SizedBox(width: 8),
                      pageText,
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (constraints.maxWidth < 600)
                    Row(
                      children: [
                        Expanded(child: previousButton),
                        const SizedBox(width: 8),
                        Expanded(child: nextButton),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        previousButton,
                        const SizedBox(width: 8),
                        nextButton,
                      ],
                    ),
                ],
              ),
            );
          }

          // Desktop / Wide layout (>= 768px)
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                rangeText,
                const Spacer(),
                pageText,
                const SizedBox(width: 16),
                previousButton,
                const SizedBox(width: 8),
                nextButton,
              ],
            ),
          );
        },
      ),
    );
  }
}
