import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/lead_import_column_mapping.dart';
import '../models/lead_import_parsed_file.dart';
import '../models/lead_import_structure_analysis.dart';
import '../services/lead_import_preview_builder.dart';
import 'lead_import_preview_state.dart';

class LeadImportPreviewCubit extends Cubit<LeadImportPreviewState> {
  LeadImportPreviewCubit({
    required LeadImportParsedFile parsedFile,
    required LeadImportStructureAnalysis analysis,
    required LeadImportColumnMapping mapping,
    LeadImportPreviewBuilder? builder,
  }) : _builder = builder ?? const DefaultLeadImportPreviewBuilder(),
       super(const LeadImportPreviewInitial()) {
    buildPreview(parsedFile: parsedFile, analysis: analysis, mapping: mapping);
  }

  final LeadImportPreviewBuilder _builder;

  /// Synchronously constructs the preview and emits [LeadImportPreviewReady]
  /// or [LeadImportPreviewFailure].
  void buildPreview({
    required LeadImportParsedFile parsedFile,
    required LeadImportStructureAnalysis analysis,
    required LeadImportColumnMapping mapping,
  }) {
    try {
      final preview = _builder.build(
        parsedFile: parsedFile,
        analysis: analysis,
        mapping: mapping,
      );
      emit(LeadImportPreviewReady(preview));
    } on LeadImportPreviewException catch (e) {
      emit(LeadImportPreviewFailure(e.message));
    } catch (_) {
      emit(
        const LeadImportPreviewFailure(
          'Unable to prepare this import preview.',
        ),
      );
    }
  }
}
