import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../domain/entities/inventory_import_models.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../services/inventory_import_file_picker.dart';
import '../services/inventory_import_parser.dart';
import '../services/inventory_import_preview_builder.dart';
import 'inventory_import_state.dart';

/// Cubit managing the multi-step inventory import process.
class InventoryImportCubit extends Cubit<InventoryImportState> {
  InventoryImportCubit({
    required this.user,
    required this.repository,
    this.filePicker = const DefaultInventoryImportFilePicker(),
    this.parser = const DefaultInventoryImportParser(),
    this.previewBuilder = const InventoryImportPreviewBuilder(),
  }) : super(const InventoryImportInitial());

  final CurrentUser user;
  final InventoryRepository repository;
  final InventoryImportFilePicker filePicker;
  final InventoryImportParser parser;
  final InventoryImportPreviewBuilder previewBuilder;

  bool _isImporting = false;

  /// Prompts user to select a CSV or XLSX file and parses it into sheets.
  Future<void> selectFileAndParse() async {
    final InventoryImportSelectedFile? selectedFile;
    try {
      selectedFile = await filePicker.pickFile();
    } catch (e) {
      emit(InventoryImportErrorState(message: e.toString()));
      return;
    }

    if (selectedFile == null) {
      // User cancelled picker: retain current state safely
      return;
    }

    emit(const InventoryImportLoading('Reading and parsing file...'));

    try {
      final parsedFile = await parser.parse(selectedFile);

      if (parsedFile.sheets.isEmpty) {
        emit(
          const InventoryImportErrorState(
            message: 'Unable to read this file. No sheets found.',
          ),
        );
        return;
      }

      // Multi-sheet XLSX requires explicit sheet selection
      if (parsedFile.fileType == InventoryImportFileType.xlsx &&
          parsedFile.sheets.length > 1) {
        emit(
          InventoryImportSheetSelect(file: parsedFile, selectedSheetIndex: 0),
        );
      } else {
        // Single sheet CSV or single-sheet XLSX: proceed to header selection
        emit(
          InventoryImportHeaderSelect(
            file: parsedFile,
            sheetIndex: 0,
            selectedHeaderRowIndex: 0,
          ),
        );
      }
    } catch (e) {
      emit(InventoryImportErrorState(message: e.toString()));
    }
  }

  void selectSheetIndex(int index) {
    if (state is! InventoryImportSheetSelect) return;
    final curr = state as InventoryImportSheetSelect;
    emit(curr.copyWith(selectedSheetIndex: index));
  }

  void confirmSheet() {
    if (state is! InventoryImportSheetSelect) return;
    final curr = state as InventoryImportSheetSelect;
    emit(
      InventoryImportHeaderSelect(
        file: curr.file,
        sheetIndex: curr.selectedSheetIndex,
        selectedHeaderRowIndex: 0,
      ),
    );
  }

  void selectHeaderRowIndex(int index) {
    if (state is! InventoryImportHeaderSelect) return;
    final curr = state as InventoryImportHeaderSelect;
    emit(curr.copyWith(selectedHeaderRowIndex: index));
  }

  void confirmHeaderRow() {
    if (state is! InventoryImportHeaderSelect) return;
    final curr = state as InventoryImportHeaderSelect;
    final sheet = curr.sheet;

    final headerRow = curr.selectedHeaderRowIndex < sheet.rows.length
        ? sheet.rows[curr.selectedHeaderRowIndex]
        : <String>[];

    final availableColumns = List<String>.generate(headerRow.length, (i) {
      final text = headerRow[i].trim();
      return text.isEmpty ? 'Column ${i + 1}' : 'Col ${i + 1}: $text';
    });

    emit(
      InventoryImportMappingState(
        file: curr.file,
        sheetIndex: curr.sheetIndex,
        headerRowIndex: curr.selectedHeaderRowIndex,
        availableColumns: List.unmodifiable(availableColumns),
        mapping: InventoryImportColumnMapping(
          sheetIndex: curr.sheetIndex,
          headerRowIndex: curr.selectedHeaderRowIndex,
        ),
      ),
    );
  }

  void setFieldMapping(InventoryImportField field, int? columnIndex) {
    if (state is! InventoryImportMappingState) return;
    final curr = state as InventoryImportMappingState;
    final mapping = curr.mapping;

    int? newName = mapping.nameColumnIndex;
    int? newSku = mapping.skuColumnIndex;
    int? newOpeningStock = mapping.openingStockColumnIndex;

    // Prevent duplicate mapping of the same source column
    if (columnIndex != null) {
      if (newName == columnIndex) newName = null;
      if (newSku == columnIndex) newSku = null;
      if (newOpeningStock == columnIndex) newOpeningStock = null;
    }

    switch (field) {
      case InventoryImportField.name:
        newName = columnIndex;
        break;
      case InventoryImportField.sku:
        newSku = columnIndex;
        break;
      case InventoryImportField.openingStock:
        newOpeningStock = columnIndex;
        break;
    }

    emit(
      curr.copyWith(
        mapping: InventoryImportColumnMapping(
          sheetIndex: curr.sheetIndex,
          headerRowIndex: curr.headerRowIndex,
          nameColumnIndex: newName,
          skuColumnIndex: newSku,
          openingStockColumnIndex: newOpeningStock,
        ),
        clearValidationError: true,
      ),
    );
  }

  Future<void> confirmMapping() async {
    if (state is! InventoryImportMappingState) return;
    final curr = state as InventoryImportMappingState;

    if (!curr.mapping.isValid) {
      emit(
        curr.copyWith(validationError: 'Please map both Name and SKU columns.'),
      );
      return;
    }

    emit(const InventoryImportLoading('Building preview...'));

    try {
      final existingSkus = await repository.getExistingSkus();
      final preview = previewBuilder.build(
        sheet: curr.sheet,
        mapping: curr.mapping,
        existingSkus: existingSkus,
      );

      emit(
        InventoryImportPreviewState(
          file: curr.file,
          sheetIndex: curr.sheetIndex,
          mapping: curr.mapping,
          preview: preview,
        ),
      );
    } catch (e) {
      emit(
        InventoryImportErrorState(
          message: 'Failed to build preview: $e',
          fallbackState: curr,
        ),
      );
    }
  }

  void toggleRowSelection(int sourceRowNumber) {
    if (state is! InventoryImportPreviewState) return;
    final curr = state as InventoryImportPreviewState;

    final updatedRows = curr.preview.rows
        .map((row) {
          if (row.sourceRowNumber == sourceRowNumber && row.isSelectable) {
            return row.copyWith(isSelected: !row.isSelected);
          }
          return row;
        })
        .toList(growable: false);

    emit(curr.copyWith(preview: InventoryImportPreview(rows: updatedRows)));
  }

  void selectAllValid() {
    if (state is! InventoryImportPreviewState) return;
    final curr = state as InventoryImportPreviewState;

    final updatedRows = curr.preview.rows
        .map((row) {
          if (row.isSelectable) {
            return row.copyWith(isSelected: true);
          }
          return row;
        })
        .toList(growable: false);

    emit(curr.copyWith(preview: InventoryImportPreview(rows: updatedRows)));
  }

  void deselectAll() {
    if (state is! InventoryImportPreviewState) return;
    final curr = state as InventoryImportPreviewState;

    final updatedRows = curr.preview.rows
        .map((row) {
          return row.copyWith(isSelected: false);
        })
        .toList(growable: false);

    emit(curr.copyWith(preview: InventoryImportPreview(rows: updatedRows)));
  }

  Future<void> executeImport() async {
    if (_isImporting) return;
    if (state is! InventoryImportPreviewState) return;
    final curr = state as InventoryImportPreviewState;

    if (curr.preview.selectedCount == 0) return;

    _isImporting = true;
    emit(InventoryImportSubmitting(preview: curr.preview));

    try {
      final selectedInputs = curr.preview.selectedRows
          .map((r) {
            return InventoryImportRowInput(
              sourceRowNumber: r.sourceRowNumber,
              name: r.name,
              sku: r.sku,
              openingStock: r.openingStock,
            );
          })
          .toList(growable: false);

      final request = InventoryImportRequest(
        performedByUserId: user.id,
        rows: selectedInputs,
      );

      final result = await repository.importItems(request);
      emit(InventoryImportSuccessState(result: result));
    } catch (e) {
      emit(
        InventoryImportErrorState(
          message: 'Failed to complete import: $e',
          fallbackState: curr,
        ),
      );
    } finally {
      _isImporting = false;
    }
  }

  void backToFileSelection() {
    emit(const InventoryImportInitial());
  }

  void backToSheetSelection() {
    if (state is InventoryImportHeaderSelect) {
      final curr = state as InventoryImportHeaderSelect;
      if (curr.file.sheets.length > 1) {
        emit(
          InventoryImportSheetSelect(
            file: curr.file,
            selectedSheetIndex: curr.sheetIndex,
          ),
        );
        return;
      }
    }
    emit(const InventoryImportInitial());
  }

  void backToHeaderSelection() {
    if (state is InventoryImportMappingState) {
      final curr = state as InventoryImportMappingState;
      emit(
        InventoryImportHeaderSelect(
          file: curr.file,
          sheetIndex: curr.sheetIndex,
          selectedHeaderRowIndex: curr.headerRowIndex,
        ),
      );
    }
  }

  void backToMapping() {
    if (state is InventoryImportPreviewState) {
      final curr = state as InventoryImportPreviewState;
      final sheet = curr.file.sheets[curr.sheetIndex];
      final headerRow = curr.mapping.headerRowIndex < sheet.rows.length
          ? sheet.rows[curr.mapping.headerRowIndex]
          : <String>[];

      final availableColumns = List<String>.generate(headerRow.length, (i) {
        final text = headerRow[i].trim();
        return text.isEmpty ? 'Column ${i + 1}' : 'Col ${i + 1}: $text';
      });

      emit(
        InventoryImportMappingState(
          file: curr.file,
          sheetIndex: curr.sheetIndex,
          headerRowIndex: curr.mapping.headerRowIndex,
          availableColumns: List.unmodifiable(availableColumns),
          mapping: curr.mapping,
        ),
      );
    }
  }
}
