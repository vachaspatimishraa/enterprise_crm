import 'package:flutter/foundation.dart';

import '../../domain/entities/lead_import.dart';
import '../models/lead_import_preview.dart';
import '../models/lead_import_review.dart';

@immutable
sealed class LeadImportExecutionState {
  const LeadImportExecutionState();
}

class LeadImportExecutionInitial extends LeadImportExecutionState {
  const LeadImportExecutionInitial();
}

class LeadImportExecuting extends LeadImportExecutionState {
  const LeadImportExecuting();
}

class LeadImportExecutionSuccess extends LeadImportExecutionState {
  const LeadImportExecutionSuccess({
    required this.result,
    required this.preview,
    required this.decision,
  });

  final LeadImportResult result;
  final LeadImportPreview preview;
  final LeadImportReviewDecision decision;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportExecutionSuccess &&
          runtimeType == other.runtimeType &&
          result == other.result &&
          preview == other.preview &&
          decision == other.decision;

  @override
  int get hashCode => Object.hash(result, preview, decision);
}

class LeadImportExecutionFailure extends LeadImportExecutionState {
  const LeadImportExecutionFailure({
    required this.message,
    required this.preview,
    required this.decision,
  });

  final String message;
  final LeadImportPreview preview;
  final LeadImportReviewDecision decision;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportExecutionFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          preview == other.preview &&
          decision == other.decision;

  @override
  int get hashCode => Object.hash(message, preview, decision);
}
