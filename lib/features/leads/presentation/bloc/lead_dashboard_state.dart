import '../../domain/entities/lead_summary.dart';

typedef LeadSummaryMetrics = LeadSummary;

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
  final LeadSummary metrics;

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
