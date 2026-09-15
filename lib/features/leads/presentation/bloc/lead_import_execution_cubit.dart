import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/lead_repository.dart';
import '../models/lead_import_preview.dart';
import '../models/lead_import_review.dart';
import '../services/lead_import_execution_request_builder.dart';
import 'lead_import_execution_state.dart';

class LeadImportExecutionCubit extends Cubit<LeadImportExecutionState> {
  LeadImportExecutionCubit({
    required LeadRepository repository,
    LeadImportExecutionRequestBuilder? requestBuilder,
  }) : _repository = repository,
       _requestBuilder =
           requestBuilder ?? const DefaultLeadImportExecutionRequestBuilder(),
       super(const LeadImportExecutionInitial());

  final LeadRepository _repository;
  final LeadImportExecutionRequestBuilder _requestBuilder;

  /// Executes the import of the reviewed rows. If an execution is already in
  /// progress, duplicate requests are ignored.
  Future<void> execute({
    required LeadImportPreview preview,
    required LeadImportReviewDecision decision,
  }) async {
    if (state is LeadImportExecuting) {
      return;
    }

    emit(const LeadImportExecuting());

    try {
      final request = _requestBuilder.build(
        preview: preview,
        decision: decision,
      );
      final result = await _repository.importLeads(request);
      emit(
        LeadImportExecutionSuccess(
          result: result,
          preview: preview,
          decision: decision,
        ),
      );
    } catch (_) {
      emit(
        LeadImportExecutionFailure(
          message: 'Unable to import the selected Leads.',
          preview: preview,
          decision: decision,
        ),
      );
    }
  }

  /// Retries the last failed import execution with the same preview and decision.
  Future<void> retry() async {
    final current = state;
    if (current is LeadImportExecutionFailure) {
      await execute(preview: current.preview, decision: current.decision);
    }
  }
}
