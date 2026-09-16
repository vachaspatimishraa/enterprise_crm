import '../../../data/models/lead.dart';

enum LeadStatus { initial, loading, success, error }

class LeadState {
  final LeadStatus status;
  final List<Lead> leads;
  final String? errorMessage;

  const LeadState({
    this.status = LeadStatus.initial,
    this.leads = const [],
    this.errorMessage,
  });

  LeadState copyWith({
    LeadStatus? status,
    List<Lead>? leads,
    String? errorMessage,
  }) {
    return LeadState(
      status: status ?? this.status,
      leads: leads ?? this.leads,
      errorMessage: errorMessage,
    );
  }
}