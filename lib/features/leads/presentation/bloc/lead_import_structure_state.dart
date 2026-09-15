import '../models/lead_import_parsed_file.dart';
import '../models/lead_import_structure_analysis.dart';

class LeadImportStructureState {
  const LeadImportStructureState({
    required this.parsedFile,
    required this.selectedSheetIndex,
    required this.selectedHeaderRowIndex,
    required this.analysis,
  });

  final LeadImportParsedFile parsedFile;
  final int selectedSheetIndex;
  final int selectedHeaderRowIndex;
  final LeadImportStructureAnalysis analysis;

  bool get isValid => analysis.isValid;
  bool get hasBlockingErrors => analysis.hasBlockingErrors;

  LeadImportStructureState copyWith({
    LeadImportParsedFile? parsedFile,
    int? selectedSheetIndex,
    int? selectedHeaderRowIndex,
    LeadImportStructureAnalysis? analysis,
  }) {
    return LeadImportStructureState(
      parsedFile: parsedFile ?? this.parsedFile,
      selectedSheetIndex: selectedSheetIndex ?? this.selectedSheetIndex,
      selectedHeaderRowIndex:
          selectedHeaderRowIndex ?? this.selectedHeaderRowIndex,
      analysis: analysis ?? this.analysis,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportStructureState &&
          runtimeType == other.runtimeType &&
          parsedFile == other.parsedFile &&
          selectedSheetIndex == other.selectedSheetIndex &&
          selectedHeaderRowIndex == other.selectedHeaderRowIndex &&
          analysis == other.analysis;

  @override
  int get hashCode => Object.hash(
    parsedFile,
    selectedSheetIndex,
    selectedHeaderRowIndex,
    analysis,
  );
}
