import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/lead_import_column_mapping.dart';
import '../models/lead_import_parsed_file.dart';
import '../models/lead_import_structure_analysis.dart';
import 'lead_import_mapping_state.dart';

class LeadImportMappingCubit extends Cubit<LeadImportMappingState> {
  LeadImportMappingCubit({
    required LeadImportParsedFile parsedFile,
    required LeadImportStructureAnalysis analysis,
    LeadImportColumnMapping? initialMapping,
  }) : super(
         LeadImportMappingState(
           parsedFile: parsedFile,
           analysis: analysis,
           mapping:
               initialMapping ??
               LeadImportColumnMapping(
                 sheetIndex: analysis.sheetIndex,
                 headerRowIndex: analysis.headerRowIndex,
               ),
         ),
       );

  /// Sets or clears the mapped column index for a [target] Lead field.
  ///
  /// - Passing `null` unmaps the field.
  /// - If [columnIndex] does not exist in discovered columns, the request is ignored.
  /// - If another Lead field was previously mapped to [columnIndex], its mapping
  ///   is automatically cleared so each source column feeds at most one field.
  void setMapping(LeadImportTargetField target, int? columnIndex) {
    if (columnIndex != null) {
      final isValidColumn = state.analysis.columns.any(
        (c) => c.index == columnIndex,
      );
      if (!isValidColumn) return;
    }

    var nameCol = state.mapping.nameColumnIndex;
    var phoneCol = state.mapping.phoneColumnIndex;
    var emailCol = state.mapping.emailColumnIndex;

    // Conflict resolution: clear any other field pointing to this columnIndex
    if (columnIndex != null) {
      if (target != LeadImportTargetField.name && nameCol == columnIndex) {
        nameCol = null;
      }
      if (target != LeadImportTargetField.phone && phoneCol == columnIndex) {
        phoneCol = null;
      }
      if (target != LeadImportTargetField.email && emailCol == columnIndex) {
        emailCol = null;
      }
    }

    // Assign to target field
    switch (target) {
      case LeadImportTargetField.name:
        nameCol = columnIndex;
      case LeadImportTargetField.phone:
        phoneCol = columnIndex;
      case LeadImportTargetField.email:
        emailCol = columnIndex;
    }

    final newMapping = LeadImportColumnMapping(
      sheetIndex: state.analysis.sheetIndex,
      headerRowIndex: state.analysis.headerRowIndex,
      nameColumnIndex: nameCol,
      phoneColumnIndex: phoneCol,
      emailColumnIndex: emailCol,
    );

    emit(state.copyWith(mapping: newMapping));
  }

  void mapNameTo(int? columnIndex) =>
      setMapping(LeadImportTargetField.name, columnIndex);

  void mapPhoneTo(int? columnIndex) =>
      setMapping(LeadImportTargetField.phone, columnIndex);

  void mapEmailTo(int? columnIndex) =>
      setMapping(LeadImportTargetField.email, columnIndex);
}
