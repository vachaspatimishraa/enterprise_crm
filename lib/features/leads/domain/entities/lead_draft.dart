import 'lead_source.dart';
import 'lead_status.dart';

class LeadDraft {
  const LeadDraft({
    this.name,
    this.phone,
    this.email,
    this.status,
    this.source,
  });

  final String? name;
  final String? phone;
  final String? email;
  final LeadStatus? status;
  final LeadSource? source;
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
