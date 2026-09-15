import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/lead_import_selected_file.dart';
import '../services/lead_import_parser.dart';
import 'lead_import_parse_state.dart';

class LeadImportParseCubit extends Cubit<LeadImportParseState> {
  LeadImportParseCubit([LeadImportParser? parser])
    : _parser = parser ?? const DefaultLeadImportParser(),
      super(const LeadImportParseInitial());

  final LeadImportParser _parser;

  /// Parses the selected file into a format-neutral parsed representation.
  Future<void> parse(LeadImportSelectedFile file) async {
    // Duplicate parse request protection while parsing is in progress
    if (state is LeadImportParsing) return;

    emit(const LeadImportParsing());

    try {
      final parsed = await _parser.parse(file);
      emit(LeadImportParseSuccess(parsed));
    } on LeadImportParseException catch (e) {
      emit(LeadImportParseFailure(e.message));
    } catch (_) {
      emit(const LeadImportParseFailure('Failed to parse import file.'));
    }
  }

  /// Resets the parse state to initial.
  void reset() {
    emit(const LeadImportParseInitial());
  }
}
