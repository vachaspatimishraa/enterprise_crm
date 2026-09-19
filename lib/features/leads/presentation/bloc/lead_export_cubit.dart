import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/lead_export_file_saver.dart';
import '../../domain/entities/lead_export.dart';
import '../../domain/entities/lead_query.dart';
import '../../domain/repositories/lead_repository.dart';
import 'lead_export_state.dart';

/// Cubit responsible for orchestrating lead export format selection,
/// repository byte generation, and platform file delivery.
class LeadExportCubit extends Cubit<LeadExportState> {
  final LeadRepository _repository;
  final LeadExportFileSaver _fileSaver;

  LeadExportCubit({
    required LeadRepository repository,
    required LeadExportFileSaver fileSaver,
    LeadExportFormat initialFormat = LeadExportFormat.excel,
  }) : _repository = repository,
       _fileSaver = fileSaver,
       super(LeadExportState(selectedFormat: initialFormat));

  /// Selects the export format (Excel or CSV).
  void selectFormat(LeadExportFormat format) {
    if (state.isBusy) return;
    emit(
      state.copyWith(
        selectedFormat: format,
        clearError: true,
        status: LeadExportStatus.idle,
      ),
    );
  }

  /// Triggers lead export generation from the repository and delivers the file via file saver.
  Future<void> export({required LeadQuery query}) async {
    if (state.isBusy) return;

    emit(state.copyWith(status: LeadExportStatus.exporting, clearError: true));

    try {
      final exportResult = await _repository.exportLeads(
        LeadExportRequest(query: query, format: state.selectedFormat),
      );

      emit(state.copyWith(status: LeadExportStatus.saving));

      final saveResult = await _fileSaver.save(exportResult);

      if (saveResult.isSaved) {
        emit(state.copyWith(status: LeadExportStatus.success));
      } else {
        emit(state.copyWith(status: LeadExportStatus.cancelled));
      }
    } catch (_) {
      emit(
        state.copyWith(
          status: LeadExportStatus.failure,
          errorMessage: 'Unable to export Leads.',
        ),
      );
    }
  }
}
