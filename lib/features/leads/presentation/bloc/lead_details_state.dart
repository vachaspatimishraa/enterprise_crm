import '../../domain/entities/lead.dart';

sealed class LeadDetailsState {
  const LeadDetailsState();
}

final class LeadDetailsInitial extends LeadDetailsState {
  const LeadDetailsInitial();
}

final class LeadDetailsLoading extends LeadDetailsState {
  const LeadDetailsLoading();
}

final class LeadDetailsLoaded extends LeadDetailsState {
  final Lead lead;

  const LeadDetailsLoaded(this.lead);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadDetailsLoaded &&
          runtimeType == other.runtimeType &&
          lead == other.lead;

  @override
  int get hashCode => lead.hashCode;
}

final class LeadDetailsNotFound extends LeadDetailsState {
  final String leadId;

  const LeadDetailsNotFound(this.leadId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadDetailsNotFound &&
          runtimeType == other.runtimeType &&
          leadId == other.leadId;

  @override
  int get hashCode => leadId.hashCode;
}

final class LeadDetailsFailure extends LeadDetailsState {
  final String message;
  final String? leadId;

  const LeadDetailsFailure(this.message, {this.leadId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadDetailsFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          leadId == other.leadId;

  @override
  int get hashCode => Object.hash(message, leadId);
}
