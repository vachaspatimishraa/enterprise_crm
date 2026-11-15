import 'lead_source.dart';
import 'lead_status.dart';

class LeadDraft {
  const LeadDraft({
    String? name,
    String? contactPersonName,
    this.businessName,
    this.phone,
    this.email,
    this.city,
    this.state,
    this.status,
    this.source,
    this.createdAt,
    this.metadata,
  }) : name = contactPersonName ?? name;

  final String? name;
  String? get contactPersonName => name;
  final String? businessName;
  final String? phone;
  final String? email;
  final String? city;
  final String? state;
  final LeadStatus? status;
  final LeadSource? source;
  final DateTime? createdAt;
  final Map<String, String>? metadata;
}

class CreateLeadInput {
  const CreateLeadInput({required this.draft});

  final LeadDraft draft;
}

class UpdateLeadInput {
  const UpdateLeadInput({required this.leadId, required this.draft});

  final String leadId;
  final LeadDraft draft;
}
