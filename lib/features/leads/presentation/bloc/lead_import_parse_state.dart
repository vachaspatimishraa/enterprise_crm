import '../models/lead_import_parsed_file.dart';

sealed class LeadImportParseState {
  const LeadImportParseState();
}

final class LeadImportParseInitial extends LeadImportParseState {
  const LeadImportParseInitial();
}

final class LeadImportParsing extends LeadImportParseState {
  const LeadImportParsing();
}

final class LeadImportParseSuccess extends LeadImportParseState {
  const LeadImportParseSuccess(this.parsedFile);

  final LeadImportParsedFile parsedFile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportParseSuccess &&
          runtimeType == other.runtimeType &&
          parsedFile == other.parsedFile;

  @override
  int get hashCode => parsedFile.hashCode;
}

final class LeadImportParseFailure extends LeadImportParseState {
  const LeadImportParseFailure(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportParseFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}
