import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/lead_repository.dart';
import '../bloc/lead_import_cubit.dart';
import '../bloc/lead_import_execution_cubit.dart';
import '../bloc/lead_import_execution_state.dart';
import '../bloc/lead_import_mapping_cubit.dart';
import '../bloc/lead_import_parse_cubit.dart';
import '../bloc/lead_import_parse_state.dart';
import '../bloc/lead_import_preview_cubit.dart';
import '../bloc/lead_import_review_cubit.dart';
import '../bloc/lead_import_structure_cubit.dart';
import '../bloc/lead_import_workflow_cubit.dart';
import '../bloc/lead_import_workflow_state.dart';
import '../models/lead_import_selected_file.dart';
import '../services/lead_import_duplicate_detector.dart';
import '../services/lead_import_execution_request_builder.dart';
import '../services/lead_import_file_picker.dart';
import '../services/lead_import_preview_builder.dart';
import '../services/lead_import_structure_analyzer.dart';
import 'lead_import_execution_screen.dart';
import 'lead_import_mapping_screen.dart';
import 'lead_import_preview_screen.dart';
import 'lead_import_review_screen.dart';
import 'lead_import_screen.dart';
import 'lead_import_structure_screen.dart';

/// End-to-end coordinator screen orchestrating the full Lead Import workflow:
/// File selection -> Parse -> Sheet & Header structure -> Field mapping ->
/// Row preview -> Exact duplicate review -> Execution -> Result summary.
class LeadImportWorkflowScreen extends StatefulWidget {
  const LeadImportWorkflowScreen({
    super.key,
    required this.repository,
    this.workflowCubit,
    this.filePicker,
    this.fileCubit,
    this.parseCubit,
    this.structureAnalyzer,
    this.structureCubit,
    this.mappingCubit,
    this.previewBuilder,
    this.previewCubit,
    this.duplicateDetector,
    this.reviewCubit,
    this.executionRequestBuilder,
    this.executionCubit,
    this.onDone,
    this.onCancel,
  });

  final LeadRepository repository;
  final LeadImportWorkflowCubit? workflowCubit;
  final LeadImportFilePicker? filePicker;
  final LeadImportCubit? fileCubit;
  final LeadImportParseCubit? parseCubit;
  final LeadImportStructureAnalyzer? structureAnalyzer;
  final LeadImportStructureCubit? structureCubit;
  final LeadImportMappingCubit? mappingCubit;
  final LeadImportPreviewBuilder? previewBuilder;
  final LeadImportPreviewCubit? previewCubit;
  final LeadImportDuplicateDetector? duplicateDetector;
  final LeadImportReviewCubit? reviewCubit;
  final LeadImportExecutionRequestBuilder? executionRequestBuilder;
  final LeadImportExecutionCubit? executionCubit;
  final VoidCallback? onDone;
  final VoidCallback? onCancel;

  @override
  State<LeadImportWorkflowScreen> createState() =>
      _LeadImportWorkflowScreenState();
}

class _LeadImportWorkflowScreenState extends State<LeadImportWorkflowScreen> {
  late final LeadImportWorkflowCubit _workflowCubit;
  late final LeadImportParseCubit _parseCubit;
  late final LeadImportCubit _fileCubit;

  LeadImportStructureCubit? _structureCubit;
  LeadImportMappingCubit? _mappingCubit;
  LeadImportReviewCubit? _reviewCubit;
  LeadImportExecutionCubit? _executionCubit;

  @override
  void initState() {
    super.initState();
    _workflowCubit = widget.workflowCubit ?? LeadImportWorkflowCubit();
    _parseCubit = widget.parseCubit ?? LeadImportParseCubit();
    _fileCubit = widget.fileCubit ?? LeadImportCubit(widget.filePicker);
  }

  @override
  void dispose() {
    if (widget.workflowCubit == null) {
      _workflowCubit.close();
    }
    if (widget.parseCubit == null) {
      _parseCubit.close();
    }
    if (widget.fileCubit == null) {
      _fileCubit.close();
    }
    _structureCubit?.close();
    _mappingCubit?.close();
    _reviewCubit?.close();
    if (widget.executionCubit == null) {
      _executionCubit?.close();
    }
    super.dispose();
  }

  void _onFileSelected(LeadImportSelectedFile file) {
    // Fresh file confirmation: discard all downstream cubit states
    _structureCubit?.close();
    _structureCubit = null;
    _mappingCubit?.close();
    _mappingCubit = null;
    _reviewCubit?.close();
    _reviewCubit = null;
    if (widget.executionCubit == null) {
      _executionCubit?.close();
      _executionCubit = null;
    }

    _workflowCubit.selectFileAndParse(file);
    _parseCubit.parse(file);
  }

  void _onRetryParse() {
    final selectedFile = _workflowCubit.state.selectedFile;
    if (selectedFile != null) {
      _workflowCubit.retryParsing();
      _parseCubit.parse(selectedFile);
    }
  }

  void _handleSuccessDone(BuildContext context) {
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  void _handleCancel(BuildContext context) {
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else {
      Navigator.of(context).pop(false);
    }
  }

  void _handleBack(BuildContext context) {
    final state = _workflowCubit.state;
    switch (state.step) {
      case LeadImportWorkflowStep.selectFile:
        _handleCancel(context);
        break;
      case LeadImportWorkflowStep.parsing:
        if (state.parseErrorMessage != null) {
          _workflowCubit.backToFileSelection();
        }
        // If actively parsing, block back to preserve parsing integrity
        break;
      case LeadImportWorkflowStep.structure:
        _workflowCubit.backToFileSelection();
        break;
      case LeadImportWorkflowStep.mapping:
        _workflowCubit.backToStructure();
        break;
      case LeadImportWorkflowStep.preview:
        _workflowCubit.backToMapping();
        break;
      case LeadImportWorkflowStep.review:
        _workflowCubit.backToPreview();
        break;
      case LeadImportWorkflowStep.execution:
        final execState = _executionCubit?.state;
        if (execState is LeadImportExecuting) {
          // Actively executing import into repository: BLOCK BACK!
          return;
        }
        if (execState is LeadImportExecutionSuccess) {
          // Import has already succeeded! Any route exit must communicate success.
          _handleSuccessDone(context);
          return;
        }
        // Failure or initial: allowed to cancel/exit false
        _handleCancel(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _workflowCubit),
        BlocProvider.value(value: _parseCubit),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<LeadImportParseCubit, LeadImportParseState>(
            listener: (context, parseState) {
              if (parseState is LeadImportParseSuccess) {
                _workflowCubit.onParseSuccess(parseState.parsedFile);
              } else if (parseState is LeadImportParseFailure) {
                _workflowCubit.onParseFailure(parseState.message);
              }
            },
          ),
        ],
        child: BlocBuilder<LeadImportWorkflowCubit, LeadImportWorkflowState>(
          builder: (context, state) {
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                _handleBack(context);
              },
              child: _buildCurrentStepView(context, state),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCurrentStepView(
    BuildContext context,
    LeadImportWorkflowState state,
  ) {
    switch (state.step) {
      case LeadImportWorkflowStep.selectFile:
        return LeadImportScreen(
          filePicker: widget.filePicker,
          cubit: _fileCubit,
          onContinue: _onFileSelected,
          onCancel: () => _handleCancel(context),
        );

      case LeadImportWorkflowStep.parsing:
        return _LeadImportParsingView(
          errorMessage: state.parseErrorMessage,
          onRetry: _onRetryParse,
          onBack: () => _workflowCubit.backToFileSelection(),
        );

      case LeadImportWorkflowStep.structure:
        if (state.parsedFile == null) {
          return _WorkflowErrorFallbackView(
            onReset: () => _workflowCubit.backToFileSelection(),
          );
        }
        _structureCubit ??=
            widget.structureCubit ??
            LeadImportStructureCubit(
              parsedFile: state.parsedFile!,
              analyzer: widget.structureAnalyzer,
            );
        return LeadImportStructureScreen(
          parsedFile: state.parsedFile!,
          analyzer: widget.structureAnalyzer,
          cubit: _structureCubit,
          onContinue: (analysis) {
            _workflowCubit.onStructureConfirmed(analysis);
          },
          onCancel: () => _workflowCubit.backToFileSelection(),
        );

      case LeadImportWorkflowStep.mapping:
        if (state.parsedFile == null || state.structureAnalysis == null) {
          return _WorkflowErrorFallbackView(
            onReset: () => _workflowCubit.backToFileSelection(),
          );
        }
        if (_mappingCubit == null ||
            _mappingCubit!.state.analysis != state.structureAnalysis) {
          _mappingCubit?.close();
          _mappingCubit =
              widget.mappingCubit ??
              LeadImportMappingCubit(
                parsedFile: state.parsedFile!,
                analysis: state.structureAnalysis!,
                initialMapping: state.columnMapping,
              );
        }
        return LeadImportMappingScreen(
          parsedFile: state.parsedFile!,
          analysis: state.structureAnalysis!,
          cubit: _mappingCubit,
          onContinue: (mapping) {
            _workflowCubit.onMappingConfirmed(mapping);
          },
          onCancel: () => _workflowCubit.backToStructure(),
        );

      case LeadImportWorkflowStep.preview:
        if (state.parsedFile == null ||
            state.structureAnalysis == null ||
            state.columnMapping == null) {
          return _WorkflowErrorFallbackView(
            onReset: () => _workflowCubit.backToFileSelection(),
          );
        }
        return LeadImportPreviewScreen(
          parsedFile: state.parsedFile!,
          analysis: state.structureAnalysis!,
          mapping: state.columnMapping!,
          builder: widget.previewBuilder,
          cubit: widget.previewCubit,
          onContinue: (preview) {
            _workflowCubit.onPreviewConfirmed(preview);
          },
          onCancel: () => _workflowCubit.backToMapping(),
        );

      case LeadImportWorkflowStep.review:
        if (state.preview == null) {
          return _WorkflowErrorFallbackView(
            onReset: () => _workflowCubit.backToFileSelection(),
          );
        }
        if (_reviewCubit == null ||
            _reviewCubit!.state.preview != state.preview) {
          _reviewCubit?.close();
          _reviewCubit =
              widget.reviewCubit ??
              LeadImportReviewCubit(
                preview: state.preview!,
                duplicateDetector: widget.duplicateDetector,
              );
        }
        return LeadImportReviewScreen(
          preview: state.preview!,
          duplicateDetector: widget.duplicateDetector,
          cubit: _reviewCubit,
          onContinue: (decision) {
            _workflowCubit.onReviewConfirmed(decision);
          },
          onCancel: () => _workflowCubit.backToPreview(),
        );

      case LeadImportWorkflowStep.execution:
        if (state.preview == null || state.reviewDecision == null) {
          return _WorkflowErrorFallbackView(
            onReset: () => _workflowCubit.backToFileSelection(),
          );
        }
        if (_executionCubit == null) {
          _executionCubit =
              widget.executionCubit ??
              LeadImportExecutionCubit(
                repository: widget.repository,
                requestBuilder: widget.executionRequestBuilder,
              );
          _executionCubit!.execute(
            preview: state.preview!,
            decision: state.reviewDecision!,
          );
        }
        return LeadImportExecutionScreen(
          preview: state.preview!,
          decision: state.reviewDecision!,
          repository: widget.repository,
          requestBuilder: widget.executionRequestBuilder,
          cubit: _executionCubit,
          onDone: () => _handleSuccessDone(context),
          onCancel: () => _handleCancel(context),
        );
    }
  }
}

/// View rendered during the parsing stage (in-progress progress indicator or failure banner with retry).
class _LeadImportParsingView extends StatelessWidget {
  const _LeadImportParsingView({
    required this.errorMessage,
    required this.onRetry,
    required this.onBack,
  });

  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Leads'),
        leading: IconButton(
          key: const Key('lead_import_parse_back_button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: onBack,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: errorMessage != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          key: const Key('lead_import_parse_error_text'),
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
                            OutlinedButton(
                              key: const Key(
                                'lead_import_parse_failure_back_button',
                              ),
                              onPressed: onBack,
                              child: const Text('Back'),
                            ),
                            const SizedBox(width: 16),
                            FilledButton(
                              key: const Key('lead_import_parse_retry_button'),
                              onPressed: onRetry,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          key: Key('lead_import_parsing_indicator'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Preparing file...',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Defensive fallback UI rendered only if an unexpected upstream artifact is missing.
class _WorkflowErrorFallbackView extends StatelessWidget {
  const _WorkflowErrorFallbackView({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Leads')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              const Text(
                'Workflow state was interrupted.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onReset,
                child: const Text('Return to File Selection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
