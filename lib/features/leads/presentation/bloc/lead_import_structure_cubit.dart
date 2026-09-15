import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/lead_import_parsed_file.dart';
import '../services/lead_import_structure_analyzer.dart';
import 'lead_import_structure_state.dart';

class LeadImportStructureCubit extends Cubit<LeadImportStructureState> {
  LeadImportStructureCubit({
    required LeadImportParsedFile parsedFile,
    LeadImportStructureAnalyzer? analyzer,
  }) : _analyzer = analyzer ?? const DefaultLeadImportStructureAnalyzer(),
       super(
         _createInitialState(
           parsedFile: parsedFile,
           analyzer: analyzer ?? const DefaultLeadImportStructureAnalyzer(),
         ),
       );

  final LeadImportStructureAnalyzer _analyzer;

  static LeadImportStructureState _createInitialState({
    required LeadImportParsedFile parsedFile,
    required LeadImportStructureAnalyzer analyzer,
  }) {
    final analysis = analyzer.analyze(
      parsedFile: parsedFile,
      sheetIndex: 0,
      headerRowIndex: 0,
    );
    return LeadImportStructureState(
      parsedFile: parsedFile,
      selectedSheetIndex: 0,
      selectedHeaderRowIndex: 0,
      analysis: analysis,
    );
  }

  /// Selects another worksheet and automatically resets the header row to 0.
  void selectSheet(int index) {
    if (index < 0 || index >= state.parsedFile.sheets.length) return;
    final analysis = _analyzer.analyze(
      parsedFile: state.parsedFile,
      sheetIndex: index,
      headerRowIndex: 0,
    );
    emit(
      state.copyWith(
        selectedSheetIndex: index,
        selectedHeaderRowIndex: 0,
        analysis: analysis,
      ),
    );
  }

  /// Selects another header row within the currently selected worksheet.
  void selectHeaderRow(int rowIndex) {
    final analysis = _analyzer.analyze(
      parsedFile: state.parsedFile,
      sheetIndex: state.selectedSheetIndex,
      headerRowIndex: rowIndex,
    );
    emit(state.copyWith(selectedHeaderRowIndex: rowIndex, analysis: analysis));
  }
}
