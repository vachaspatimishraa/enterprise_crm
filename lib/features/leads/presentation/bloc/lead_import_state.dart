import '../models/lead_import_selected_file.dart';

sealed class LeadImportState {
  const LeadImportState();
}

final class LeadImportInitial extends LeadImportState {
  const LeadImportInitial();
}

final class LeadImportPicking extends LeadImportState {
  const LeadImportPicking({this.previousFile});

  final LeadImportSelectedFile? previousFile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportPicking &&
          runtimeType == other.runtimeType &&
          previousFile == other.previousFile;

  @override
  int get hashCode => previousFile.hashCode;
}

final class LeadImportFileSelected extends LeadImportState {
  const LeadImportFileSelected(this.file);

  final LeadImportSelectedFile file;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportFileSelected &&
          runtimeType == other.runtimeType &&
          file == other.file;

  @override
  int get hashCode => file.hashCode;
}

final class LeadImportFileError extends LeadImportState {
  const LeadImportFileError(this.message, {this.previousFile});

  final String message;
  final LeadImportSelectedFile? previousFile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportFileError &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          previousFile == other.previousFile;

  @override
  int get hashCode => Object.hash(message, previousFile);
}
