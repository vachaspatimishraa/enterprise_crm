import 'package:flutter/foundation.dart';

@immutable
class LeadSummaryMetrics {
  final int totalLeads;
  final int assignedLeads;
  final int unassignedLeads;
  final int manualLeads;
  final int excelLeads;
  final int csvLeads;

  const LeadSummaryMetrics({
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
      other is LeadSummaryMetrics &&
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
      'LeadSummaryMetrics(total: $totalLeads, assigned: $assignedLeads, unassigned: $unassignedLeads, manual: $manualLeads, excel: $excelLeads, csv: $csvLeads)';
}

sealed class LeadDashboardState {
  const LeadDashboardState();
}

final class LeadDashboardInitial extends LeadDashboardState {
  const LeadDashboardInitial();
}

final class LeadDashboardLoading extends LeadDashboardState {
  const LeadDashboardLoading();
}

final class LeadDashboardLoaded extends LeadDashboardState {
  final LeadSummaryMetrics metrics;

  const LeadDashboardLoaded(this.metrics);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadDashboardLoaded &&
          runtimeType == other.runtimeType &&
          metrics == other.metrics;

  @override
  int get hashCode => metrics.hashCode;
}

final class LeadDashboardEmpty extends LeadDashboardState {
  const LeadDashboardEmpty();
}

final class LeadDashboardFailure extends LeadDashboardState {
  final String message;

  const LeadDashboardFailure(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadDashboardFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}
