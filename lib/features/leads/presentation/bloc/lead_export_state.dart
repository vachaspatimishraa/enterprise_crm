import '../../domain/entities/lead_export.dart';

/// Lifecycle status for lead export orchestration.
enum LeadExportStatus { idle, exporting, saving, success, cancelled, failure }

/// Presentation state for lead export format selection and export execution.
class LeadExportState {
  final LeadExportStatus status;
  final LeadExportFormat selectedFormat;
  final String? errorMessage;

  const LeadExportState({
    this.status = LeadExportStatus.idle,
    this.selectedFormat = LeadExportFormat.excel,
    this.errorMessage,
  });

  bool get isIdle => status == LeadExportStatus.idle;
  bool get isExporting => status == LeadExportStatus.exporting;
  bool get isSaving => status == LeadExportStatus.saving;
  bool get isBusy =>
      status == LeadExportStatus.exporting || status == LeadExportStatus.saving;
  bool get isSuccess => status == LeadExportStatus.success;
  bool get isCancelled => status == LeadExportStatus.cancelled;
  bool get isFailure => status == LeadExportStatus.failure;

  LeadExportState copyWith({
    LeadExportStatus? status,
    LeadExportFormat? selectedFormat,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LeadExportState(
      status: status ?? this.status,
      selectedFormat: selectedFormat ?? this.selectedFormat,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadExportState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          selectedFormat == other.selectedFormat &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(status, selectedFormat, errorMessage);

  @override
  String toString() =>
      'LeadExportState(status: $status, format: $selectedFormat, error: $errorMessage)';
}
