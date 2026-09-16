import '../../../data/models/lead.dart';

abstract class LeadEvent {}

class LeadSubscriptionRequested extends LeadEvent {}

class LeadAdded extends LeadEvent {
  final Lead lead;
  LeadAdded(this.lead);
}

class LeadStatusChanged extends LeadEvent {
  final String id;
  final String newStatus;
  LeadStatusChanged(this.id, this.newStatus);
}

class LeadDeleted extends LeadEvent {
  final String id;
  LeadDeleted(this.id);
}