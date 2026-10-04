import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_catalogs.dart';
import '../../domain/entities/inventory_import_models.dart';
import '../services/inventory_import_parser.dart';

/// Base sealed state for the Inventory import flow.
sealed class InventoryImportState {
  const InventoryImportState();
}

/// Initial resting state before a file is chosen.
class InventoryImportInitial extends InventoryImportState {
  const InventoryImportInitial();
}

/// In-progress asynchronous operation (reading, parsing, building preview).
class InventoryImportLoading extends InventoryImportState {
  const InventoryImportLoading(this.message);

  final String message;
}

/// Multi-sheet XLSX file requires user to select a target sheet.
class InventoryImportSheetSelect extends InventoryImportState {
  const InventoryImportSheetSelect({
    required this.file,
    required this.selectedSheetIndex,
  });

  final InventoryImportParsedFile file;
  final int selectedSheetIndex;

  InventoryImportSheetSelect copyWith({int? selectedSheetIndex}) {
    return InventoryImportSheetSelect(
      file: file,
      selectedSheetIndex: selectedSheetIndex ?? this.selectedSheetIndex,
    );
  }
}

/// User specifies which row acts as the tabular header.
class InventoryImportHeaderSelect extends InventoryImportState {
  const InventoryImportHeaderSelect({
    required this.file,
    required this.sheetIndex,
    required this.selectedHeaderRowIndex,
  });

  final InventoryImportParsedFile file;
  final int sheetIndex;
  final int selectedHeaderRowIndex;

  InventoryImportParsedSheet get sheet => file.sheets[sheetIndex];

  InventoryImportHeaderSelect copyWith({int? selectedHeaderRowIndex}) {
    return InventoryImportHeaderSelect(
      file: file,
      sheetIndex: sheetIndex,
      selectedHeaderRowIndex:
          selectedHeaderRowIndex ?? this.selectedHeaderRowIndex,
    );
  }
}

/// User maps discovered spreadsheet columns to required/optional Inventory fields.
class InventoryImportMappingState extends InventoryImportState {
  const InventoryImportMappingState({
    required this.file,
    required this.sheetIndex,
    required this.headerRowIndex,
    required this.availableColumns,
    required this.mapping,
    this.validationError,
    this.customFieldDefinitions = const [],
    this.catalogs,
  });

  final InventoryImportParsedFile file;
  final int sheetIndex;
  final int headerRowIndex;
  final List<String> availableColumns;
  final InventoryImportColumnMapping mapping;
  final String? validationError;
  final List<CustomFieldDefinition> customFieldDefinitions;
  final InventoryCatalogs? catalogs;

  InventoryImportParsedSheet get sheet => file.sheets[sheetIndex];

  InventoryImportMappingState copyWith({
    InventoryImportColumnMapping? mapping,
    String? validationError,
    bool clearValidationError = false,
    List<CustomFieldDefinition>? customFieldDefinitions,
    InventoryCatalogs? catalogs,
  }) {
    return InventoryImportMappingState(
      file: file,
      sheetIndex: sheetIndex,
      headerRowIndex: headerRowIndex,
      availableColumns: availableColumns,
      mapping: mapping ?? this.mapping,
      validationError: clearValidationError
          ? null
          : (validationError ?? this.validationError),
      customFieldDefinitions:
          customFieldDefinitions ?? this.customFieldDefinitions,
      catalogs: catalogs ?? this.catalogs,
    );
  }
}

/// Evaluated preview state showing validated, invalid, and duplicate rows.
class InventoryImportPreviewState extends InventoryImportState {
  const InventoryImportPreviewState({
    required this.file,
    required this.sheetIndex,
    required this.mapping,
    required this.preview,
    this.filter = 'all',
  });

  final InventoryImportParsedFile file;
  final int sheetIndex;
  final InventoryImportColumnMapping mapping;
  final InventoryImportPreview preview;
  final String filter; // 'all', 'valid', 'errors'

  InventoryImportPreviewState copyWith({
    InventoryImportPreview? preview,
    String? filter,
  }) {
    return InventoryImportPreviewState(
      file: file,
      sheetIndex: sheetIndex,
      mapping: mapping,
      preview: preview ?? this.preview,
      filter: filter ?? this.filter,
    );
  }
}

/// Active import repository submission in progress (prevents double submits).
class InventoryImportSubmitting extends InventoryImportState {
  const InventoryImportSubmitting({required this.preview});

  final InventoryImportPreview preview;
}

/// Completed import result with counts and failure reasons.
class InventoryImportSuccessState extends InventoryImportState {
  const InventoryImportSuccessState({required this.result});

  final InventoryImportResult result;
}

/// User-safe error state with message and retry capability.
class InventoryImportErrorState extends InventoryImportState {
  const InventoryImportErrorState({required this.message, this.fallbackState});

  final String message;
  final InventoryImportState? fallbackState;
}
