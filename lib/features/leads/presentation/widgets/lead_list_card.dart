import 'package:flutter/material.dart';
import '../../domain/entities/lead.dart';
import '../utils/lead_display_formatters.dart';

export '../utils/lead_display_formatters.dart';

class LeadListCard extends StatelessWidget {
  final Lead lead;
  final void Function(Lead lead)? onViewLead;

  const LeadListCard({super.key, required this.lead, this.onViewLead});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onViewLead != null ? () => onViewLead!(lead) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header: Name & View Action
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      formatLeadName(lead.name),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onViewLead != null
                        ? () => onViewLead!(lead)
                        : null,
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 2. Phone & Email
              Row(
                children: [
                  Icon(
                    Icons.phone_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      formatLeadPhone(lead.phone),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      formatLeadEmail(lead.email),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Metadata Badges (Source, Status, Assignment)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _LeadBadge(
                    label: formatLeadSource(lead.source),
                    icon: Icons.source_outlined,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  _LeadBadge(
                    label: formatLeadStatus(lead.status),
                    icon: Icons.flag_outlined,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  _LeadBadge(
                    label: formatLeadAssignee(lead),
                    icon: lead.isAssigned ? Icons.person : Icons.person_outline,
                    backgroundColor: lead.isAssigned
                        ? colorScheme.secondaryContainer
                        : colorScheme.surfaceContainerHighest,
                    foregroundColor: lead.isAssigned
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 4. Footer: Created Date
              Text(
                'Created: ${formatLeadDate(lead.createdAt)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withAlpha(180),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const _LeadBadge({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foregroundColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
