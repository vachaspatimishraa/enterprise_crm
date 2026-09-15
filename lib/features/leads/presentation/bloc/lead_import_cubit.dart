import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/lead_import_selected_file.dart';
import '../services/lead_import_file_picker.dart';
import 'lead_import_state.dart';

class LeadImportCubit extends Cubit<LeadImportState> {
  LeadImportCubit([LeadImportFilePicker? filePicker])
    : _filePicker = filePicker ?? const DefaultLeadImportFilePicker(),
      super(const LeadImportInitial());

  final LeadImportFilePicker _filePicker;

  /// Returns the current valid selected file, if one exists (even if in a picking or error state).
  LeadImportSelectedFile? get currentFile {
    final s = state;
    if (s is LeadImportFileSelected) return s.file;
    if (s is LeadImportFileError) return s.previousFile;
    if (s is LeadImportPicking) return s.previousFile;
    return null;
  }

  /// Triggers the file picker to choose a CSV or XLSX file.
  Future<void> pickFile() async {
    // Prevent duplicate picker launches while picking is already active.
    if (state is LeadImportPicking) return;

    final previous = currentFile;
    emit(LeadImportPicking(previousFile: previous));

    try {
      final selected = await _filePicker.pickFile();

      if (selected == null) {
        // Picker was cancelled by the user. Restore previous state cleanly.
        if (previous != null) {
          emit(LeadImportFileSelected(previous));
        } else {
          emit(const LeadImportInitial());
        }
        return;
      }

      // Defensive validation for file extension and size
      final ext = selected.extension.trim().toLowerCase();
      if (ext != 'csv' && ext != 'xlsx') {
        emit(
          LeadImportFileError(
            'Unsupported file type. Please select a .csv or .xlsx file.',
            previousFile: previous,
          ),
        );
        return;
      }

      if (selected.sizeBytes <= 0) {
        emit(
          LeadImportFileError(
            'The selected file is empty.',
            previousFile: previous,
          ),
        );
        return;
      }

      emit(LeadImportFileSelected(selected));
    } on LeadImportFileException catch (e) {
      emit(LeadImportFileError(e.message, previousFile: previous));
    } catch (_) {
      emit(
        LeadImportFileError(
          'Unable to read the selected file.',
          previousFile: previous,
        ),
      );
    }
  }

  /// Removes the currently selected file and returns to the initial state.
  void removeFile() {
    emit(const LeadImportInitial());
  }

  /// Clears the active error message and returns to the previous file (if any) or initial state.
  void clearError() {
    final s = state;
    if (s is LeadImportFileError) {
      if (s.previousFile != null) {
        emit(LeadImportFileSelected(s.previousFile!));
      } else {
        emit(const LeadImportInitial());
      }
    }
  }
}
