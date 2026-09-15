import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/lead_repository.dart';
import '../bloc/lead_import_execution_cubit.dart';
import '../bloc/lead_import_execution_state.dart';
import '../models/lead_import_preview.dart';
import '../models/lead_import_review.dart';
import '../services/lead_import_execution_request_builder.dart';
import 'lead_import_result_screen.dart';

/// Screen managing and rendering the execution lifecycle of a Lead import
/// (Executing progress indicator, Failure with conditional Retry, and Result Screen).
class LeadImportExecutionScreen extends StatelessWidget {
  const LeadImportExecutionScreen({
    super.key,
    required this.preview,
    required this.decision,
    required this.onDone,
    this.onCancel,
    this.cubit,
    this.repository,
    this.requestBuilder,
  });

  final LeadImportPreview preview;
  final LeadImportReviewDecision decision;
  final VoidCallback onDone;
  final VoidCallback? onCancel;
  final LeadImportExecutionCubit? cubit;
  final LeadRepository? repository;
  final LeadImportExecutionRequestBuilder? requestBuilder;

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _LeadImportExecutionView(
          preview: preview,
          decision: decision,
          onDone: onDone,
          onCancel: onCancel,
        ),
      );
    }

    assert(repository != null, 'repository must be provided if cubit is null');

    return BlocProvider(
      create: (_) => LeadImportExecutionCubit(
        repository: repository!,
        requestBuilder: requestBuilder,
      )..execute(preview: preview, decision: decision),
      child: _LeadImportExecutionView(
        preview: preview,
        decision: decision,
        onDone: onDone,
        onCancel: onCancel,
      ),
    );
  }
}

class _LeadImportExecutionView extends StatelessWidget {
  const _LeadImportExecutionView({
    required this.preview,
    required this.decision,
    required this.onDone,
    this.onCancel,
  });

  final LeadImportPreview preview;
  final LeadImportReviewDecision decision;
  final VoidCallback onDone;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<LeadImportExecutionCubit, LeadImportExecutionState>(
      builder: (context, state) {
        if (state is LeadImportExecutionSuccess) {
          return LeadImportResultScreen(
            result: state.result,
            preview: state.preview,
            decision: state.decision,
            onDone: onDone,
          );
        }

        if (state is LeadImportExecutionFailure) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Import Leads'),
              leading: onCancel != null
                  ? IconButton(
                      key: const Key('lead_import_execution_cancel_button'),
                      icon: const Icon(Icons.close),
                      onPressed: onCancel,
                    )
                  : null,
            ),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.message,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (onCancel != null)
                              OutlinedButton(
                                key: const Key(
                                  'lead_import_execution_failure_cancel_button',
                                ),
                                onPressed: onCancel,
                                child: const Text('Cancel'),
                              ),
                            if (state.canRetry) ...[
                              if (onCancel != null) const SizedBox(width: 12),
                              FilledButton(
                                key: const Key(
                                  'lead_import_execution_retry_button',
                                ),
                                onPressed: () {
                                  context
                                      .read<LeadImportExecutionCubit>()
                                      .retry();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Executing / Initial view
        return Scaffold(
          appBar: AppBar(
            title: const Text('Import Leads'),
            automaticallyImplyLeading: false,
          ),
          body: const SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    key: Key('lead_import_execution_progress_indicator'),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Importing Leads...',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
