class LeadAssignmentRequest {
  const LeadAssignmentRequest({
    required this.leadIds,
    required this.assigneeId,
  });

  final List<String> leadIds;
  final String assigneeId;
}

class LeadReassignmentRequest {
  const LeadReassignmentRequest({
    required this.leadId,
    required this.newAssigneeId,
    this.reason,
  });

  final String leadId;
  final String newAssigneeId;
  final String? reason;
}
