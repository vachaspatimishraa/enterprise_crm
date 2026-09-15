import 'package:flutter/material.dart';

import '../../domain/entities/lead_import.dart';
import '../models/lead_import_preview.dart';
import '../models/lead_import_review.dart';

/// Screen displaying the final summary of the Lead import execution,
/// clearly separating importer execution results from upstream review context.
class LeadImportResultScreen extends StatelessWidget {
  const LeadImportResultScreen({
    super.key,
    required this.result,
    required this.preview,
    required this.decision,
    required this.onDone,
  });

  final LeadImportResult result;
  final LeadImportPreview preview;
  final LeadImportReviewDecision decision;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isComplete = result.importedRows > 0 && result.failedRows == 0;
    final title = isComplete ? 'Import Complete' : 'Import Finished';

    final excludedValidRows =
        preview.validRowCount - decision.includedSourceRowIndices.length;

    return Scaffold(
      appBar: AppBar(title: Text(title), automaticallyImplyLeading: false),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 768;
            final horizontalPadding = isDesktop ? 32.0 : 16.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 20.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header banner
                      _buildHeader(
                        context,
                        isComplete: isComplete,
                        title: title,
                      ),
                      const SizedBox(height: 24),

                      // Importer Result Card
                      _buildCard(
                        context,
                        key: const Key('lead_import_result_importer_card'),
                        title: 'Importer Result',
                        icon: Icons.cloud_done_outlined,
                        children: [
                          _buildMetricRow(
                            context,
                            label: 'Selected for import',
                            value: result.totalRows,
                            isBold: true,
                          ),
                          const Divider(height: 16),
                          _buildMetricRow(
                            context,
                            label: 'Imported',
                            value: result.importedRows,
                            valueColor: colorScheme.primary,
                            isBold: true,
                          ),
                          _buildMetricRow(
                            context,
                            label: 'Skipped by importer',
                            value: result.skippedRows,
                          ),
                          _buildMetricRow(
                            context,
                            label: 'Failed',
                            value: result.failedRows,
                            valueColor: result.failedRows > 0
                                ? colorScheme.error
                                : null,
                          ),
                          _buildMetricRow(
                            context,
                            label: 'Reported duplicates',
                            value: result.duplicateRows,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Review Summary Card
                      _buildCard(
                        context,
                        key: const Key(
                          'lead_import_result_review_summary_card',
                        ),
                        title: 'Review Summary',
                        icon: Icons.rate_review_outlined,
                        children: [
                          _buildMetricRow(
                            context,
                            label: 'Valid rows',
                            value: preview.validRowCount,
                          ),
                          _buildMetricRow(
                            context,
                            label: 'Excluded valid rows',
                            value: excludedValidRows < 0
                                ? 0
                                : excludedValidRows,
                          ),
                          _buildMetricRow(
                            context,
                            label: 'Invalid rows',
                            value: preview.invalidRowCount,
                          ),
                          _buildMetricRow(
                            context,
                            label: 'Blank rows',
                            value: preview.blankRowCount,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Done Button
                      FilledButton(
                        key: const Key('lead_import_result_done_button'),
                        onPressed: onDone,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required bool isComplete,
    required String title,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: isComplete
                ? colorScheme.primaryContainer
                : colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isComplete ? Icons.check_circle_outline : Icons.info_outline,
            size: 36,
            color: isComplete
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          preview.fileName,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required Key key,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: key,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context, {
    required String label,
    required int value,
    Color? valueColor,
    bool isBold = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: isBold ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
    );

    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: valueColor ?? colorScheme.onSurface,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: textStyle)),
          const SizedBox(width: 12),
          Text('$value', style: valueStyle),
        ],
      ),
    );
  }
}
