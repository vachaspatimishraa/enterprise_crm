/// Immutable domain entity representing an Employee KPI record.
///
/// Follows HR-5.1 frozen business requirements:
/// - Stably associated with an [employeeId] referencing [Employee.id].
/// - [periodStart] and [periodEnd] are normalized to UTC calendar dates (midnight UTC).
/// - [metricName] is a descriptive identifier of the KPI metric.
/// - [targetValue] and [actualValue] are quantitative targets and achieved values.
/// - [score] is an optional recorded score (no automatic client-side calculation).
/// - [remarks] captures qualitative assessor observations.
/// - Strictly decoupled from UI and networking dependencies.
class EmployeeKpi {
  final String id;
  final String employeeId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String metricName;
  final double targetValue;
  final double actualValue;
  final double? score;
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EmployeeKpi({
    required this.id,
    required this.employeeId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required this.metricName,
    required this.targetValue,
    required this.actualValue,
    this.score,
    this.remarks,
    this.createdAt,
    this.updatedAt,
  }) : periodStart = DateTime.utc(
         periodStart.year,
         periodStart.month,
         periodStart.day,
       ),
       periodEnd = DateTime.utc(periodEnd.year, periodEnd.month, periodEnd.day);

  /// Formatted date range string in 'YYYY-MM-DD – YYYY-MM-DD' format.
  String get formattedPeriod {
    final sY = periodStart.year.toString().padLeft(4, '0');
    final sM = periodStart.month.toString().padLeft(2, '0');
    final sD = periodStart.day.toString().padLeft(2, '0');
    final eY = periodEnd.year.toString().padLeft(4, '0');
    final eM = periodEnd.month.toString().padLeft(2, '0');
    final eD = periodEnd.day.toString().padLeft(2, '0');
    return '$sY-$sM-$sD – $eY-$eM-$eD';
  }

  /// Creates a copy of this KPI record with the given fields replaced.
  EmployeeKpi copyWith({
    String? id,
    String? employeeId,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? metricName,
    double? targetValue,
    double? actualValue,
    double? score,
    bool clearScore = false,
    String? remarks,
    bool clearRemarks = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeKpi(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      metricName: metricName ?? this.metricName,
      targetValue: targetValue ?? this.targetValue,
      actualValue: actualValue ?? this.actualValue,
      score: clearScore ? null : (score ?? this.score),
      remarks: clearRemarks ? null : (remarks ?? this.remarks),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmployeeKpi &&
        other.id == id &&
        other.employeeId == employeeId &&
        other.periodStart == periodStart &&
        other.periodEnd == periodEnd &&
        other.metricName == metricName &&
        other.targetValue == targetValue &&
        other.actualValue == actualValue &&
        other.score == score &&
        other.remarks == remarks;
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    periodStart,
    periodEnd,
    metricName,
    targetValue,
    actualValue,
    score,
    remarks,
  );

  @override
  String toString() =>
      'EmployeeKpi(id: $id, employeeId: $employeeId, metric: $metricName, target: $targetValue, actual: $actualValue, score: $score)';
}
