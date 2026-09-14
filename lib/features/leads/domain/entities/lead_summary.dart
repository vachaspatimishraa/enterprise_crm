class LeadSummary {
  final int totalLeads;
  final int assignedLeads;
  final int unassignedLeads;
  final int manualLeads;
  final int excelLeads;
  final int csvLeads;

  const LeadSummary({
    required this.totalLeads,
    required this.assignedLeads,
    required this.unassignedLeads,
    required this.manualLeads,
    required this.excelLeads,
    required this.csvLeads,
  });

  bool get isEmpty => totalLeads == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadSummary &&
          runtimeType == other.runtimeType &&
          totalLeads == other.totalLeads &&
          assignedLeads == other.assignedLeads &&
          unassignedLeads == other.unassignedLeads &&
          manualLeads == other.manualLeads &&
          excelLeads == other.excelLeads &&
          csvLeads == other.csvLeads;

  @override
  int get hashCode => Object.hash(
    totalLeads,
    assignedLeads,
    unassignedLeads,
    manualLeads,
    excelLeads,
    csvLeads,
  );

  @override
  String toString() =>
      'LeadSummary(total: $totalLeads, assigned: $assignedLeads, unassigned: $unassignedLeads, manual: $manualLeads, excel: $excelLeads, csv: $csvLeads)';
}
