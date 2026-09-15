import '../models/lead_import_column_mapping.dart';
import '../models/lead_import_parsed_file.dart';
import '../models/lead_import_structure_analysis.dart';

class LeadImportMappingState {
  const LeadImportMappingState({
    required this.parsedFile,
    required this.analysis,
    required this.mapping,
  });

  final LeadImportParsedFile parsedFile;
  final LeadImportStructureAnalysis analysis;
  final LeadImportColumnMapping mapping;

  /// True if the mapping is structurally valid and ready for Continue.
  ///
  /// Requirements:
  /// - Analysis has no blocking errors.
  /// - At least one Lead field is mapped.
  /// - All mapped column indices exist in [analysis.columns].
  /// - No two fields map to the same column index.
  /// - Mapping sheet/header metadata matches analysis.
  bool get canContinue {
    if (analysis.hasBlockingErrors) return false;
    if (!mapping.hasAnyMapping) return false;
    if (mapping.sheetIndex != analysis.sheetIndex ||
        mapping.headerRowIndex != analysis.headerRowIndex) {
      return false;
    }

    final validIndices = analysis.columns.map((c) => c.index).toSet();
    final mappedList = <int>[
      if (mapping.nameColumnIndex != null) mapping.nameColumnIndex!,
      if (mapping.phoneColumnIndex != null) mapping.phoneColumnIndex!,
      if (mapping.emailColumnIndex != null) mapping.emailColumnIndex!,
    ];

    // Ensure all mapped indices exist in the discovered columns
    for (final index in mappedList) {
      if (!validIndices.contains(index)) return false;
    }

    // Ensure no duplicate column indices across target fields
    if (mappedList.toSet().length != mappedList.length) return false;

    return true;
  }

  LeadImportMappingState copyWith({
    LeadImportParsedFile? parsedFile,
    LeadImportStructureAnalysis? analysis,
    LeadImportColumnMapping? mapping,
  }) {
    return LeadImportMappingState(
      parsedFile: parsedFile ?? this.parsedFile,
      analysis: analysis ?? this.analysis,
      mapping: mapping ?? this.mapping,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportMappingState &&
          runtimeType == other.runtimeType &&
          parsedFile == other.parsedFile &&
          analysis == other.analysis &&
          mapping == other.mapping;

  @override
  int get hashCode => Object.hash(parsedFile, analysis, mapping);

  @override
  String toString() =>
      'LeadImportMappingState(mapping: $mapping, canContinue: $canContinue)';
}
