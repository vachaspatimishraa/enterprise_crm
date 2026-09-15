import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/lead_import.dart';
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

    final LeadImportRequest request;
    try {
      request = _requestBuilder.build(preview: preview, decision: decision);
    } on LeadImportExecutionPreparationException catch (e) {
      emit(
        LeadImportExecutionFailure(
          message: e.message,
          preview: preview,
          decision: decision,
          canRetry: false,
        ),
      );
      return;
    } catch (_) {
      emit(
        LeadImportExecutionFailure(
          message: 'The selected import rows are no longer valid.',
          preview: preview,
          decision: decision,
          canRetry: false,
        ),
      );
      return;
    }

    try {
      final result = await _repository.importLeads(request);

      if (result.totalRows < 0 ||
          result.importedRows < 0 ||
          result.skippedRows < 0 ||
          result.failedRows < 0 ||
          result.duplicateRows < 0) {
        emit(
          LeadImportExecutionFailure(
            message: 'Unable to import the selected Leads.',
            preview: preview,
            decision: decision,
            canRetry: true,
          ),
        );
        return;
      }

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
          canRetry: true,
        ),
      );
    }
  }

  /// Retries the last failed import execution with the same preview and decision,
  /// provided the failure was retriable.
  Future<void> retry() async {
    final current = state;
    if (current is LeadImportExecutionFailure && current.canRetry) {
      await execute(preview: current.preview, decision: current.decision);
    }
  }
}
