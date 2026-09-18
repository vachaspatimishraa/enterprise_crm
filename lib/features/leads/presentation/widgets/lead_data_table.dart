import 'package:flutter/material.dart';
import '../../domain/entities/lead.dart';
import '../utils/lead_display_formatters.dart';

class LeadDataTable extends StatelessWidget {
  final List<Lead> leads;
  final void Function(Lead lead)? onViewLead;
  final bool isSelectionMode;
  final Set<String> selectedLeadIds;
  final void Function(Lead lead)? onToggleSelect;
  final void Function(bool? selectAll)? onSelectAll;
  final bool allEligibleSelected;

  const LeadDataTable({
    super.key,
    required this.leads,
    this.onViewLead,
    this.isSelectionMode = false,
    this.selectedLeadIds = const {},
    this.onToggleSelect,
    this.onSelectAll,
    this.allEligibleSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(
            colorScheme.surfaceContainerHighest.withAlpha(120),
          ),
          columns: [
            if (isSelectionMode)
              DataColumn(
                label: Checkbox(
                  key: const Key('lead_data_table_select_all_checkbox'),
                  value: allEligibleSelected,
                  onChanged: onSelectAll,
                ),
              ),
            const DataColumn(
              label: Text(
                'Lead',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Phone',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Email',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Source',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Assigned To',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Created',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Action',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: leads.map((lead) {
            final canSelect = !lead.isAssigned;
            final isSelected = selectedLeadIds.contains(lead.id);

            return DataRow(
              selected: isSelectionMode && isSelected,
              onSelectChanged: isSelectionMode
                  ? (canSelect ? (_) => onToggleSelect?.call(lead) : null)
                  : null,
              cells: [
                if (isSelectionMode)
                  DataCell(
                    Checkbox(
                      key: Key('lead_select_checkbox_${lead.id}'),
                      value: isSelected,
                      onChanged: canSelect
                          ? (_) => onToggleSelect?.call(lead)
                          : null,
                    ),
                  ),
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
                  isSelectionMode
                      ? const SizedBox.shrink()
                      : OutlinedButton.icon(
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
