import 'package:flutter/material.dart';
import '../../domain/entities/lead.dart';
import '../utils/lead_display_formatters.dart';

class LeadDataTable extends StatelessWidget {
  final List<Lead> leads;
  final void Function(Lead lead)? onViewLead;

  const LeadDataTable({super.key, required this.leads, this.onViewLead});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            colorScheme.surfaceContainerHighest.withAlpha(120),
          ),
          columns: const [
            DataColumn(
              label: Text(
                'Lead',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Phone',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Email',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Source',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Assigned To',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Created',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Action',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: leads.map((lead) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    formatLeadName(lead.name),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(Text(formatLeadPhone(lead.phone))),
                DataCell(Text(formatLeadEmail(lead.email))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      formatLeadSource(lead.source),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(formatLeadStatus(lead.status))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        lead.isAssigned ? Icons.person : Icons.person_outline,
                        size: 14,
                        color: lead.isAssigned
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(formatLeadAssignee(lead)),
                    ],
                  ),
                ),
                DataCell(Text(formatLeadDate(lead.createdAt))),
                DataCell(
                  OutlinedButton.icon(
                    onPressed: onViewLead != null
                        ? () => onViewLead!(lead)
                        : null,
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
