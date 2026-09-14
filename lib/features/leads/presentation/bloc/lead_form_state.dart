import '../../domain/entities/lead.dart';

sealed class LeadFormState {
  const LeadFormState();
}

final class LeadFormInitial extends LeadFormState {
  const LeadFormInitial();
}

final class LeadFormSubmitting extends LeadFormState {
  const LeadFormSubmitting();
}

final class LeadFormSuccess extends LeadFormState {
  final Lead lead;

  const LeadFormSuccess(this.lead);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadFormSuccess &&
          runtimeType == other.runtimeType &&
          lead == other.lead;

  @override
  int get hashCode => lead.hashCode;
}

final class LeadFormFailure extends LeadFormState {
  final String message;

  const LeadFormFailure(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadFormFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}
