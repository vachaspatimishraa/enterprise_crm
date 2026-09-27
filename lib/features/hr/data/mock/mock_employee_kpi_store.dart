import '../../domain/entities/employee_kpi.dart';
import '../../domain/repositories/employee_kpi_repository.dart';

/// In-memory thread-safe mock store for employee KPI records.
///
/// Follows HR-5 architectural constraints:
/// - Deterministic initial seed data across stable employee identifiers (`emp_1`, `emp_2`, `emp_3`).
/// - Full copy isolation so mutations in tests or runtime do not leak.
/// - Normalized calendar dates (UTC midnight).
/// - No dependency on [DateTime.now] for seed data.
class MockEmployeeKpiStore {
  final Map<String, EmployeeKpi> _records = {};

  MockEmployeeKpiStore({bool seedInitialData = true}) {
    if (seedInitialData) {
      _seed();
    }
  }

  void _seed() {
    final seeds = [
      // emp_1: Alice Johnson (HR Manager)
      EmployeeKpi(
        id: 'kpi_101',
        employeeId: 'emp_1',
        periodStart: DateTime.utc(2026, 7, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
        metricName: 'Employee Retention Rate',
        targetValue: 90.0,
        actualValue: 92.5,
        score: 95.0,
        remarks: 'Exceeded retention target across departments',
        createdAt: DateTime.utc(2026, 7, 1, 10, 0),
        updatedAt: DateTime.utc(2026, 9, 30, 18, 0),
      ),
      EmployeeKpi(
        id: 'kpi_102',
        employeeId: 'emp_1',
        periodStart: DateTime.utc(2026, 7, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
        metricName: 'Time to Hire (Days)',
        targetValue: 25.0,
        actualValue: 22.0,
        score: 90.0,
        remarks: 'Average hiring cycle reduced by 3 days',
        createdAt: DateTime.utc(2026, 7, 1, 10, 0),
        updatedAt: DateTime.utc(2026, 9, 30, 18, 0),
      ),

      // emp_2: Bob Miller (Warehouse Supervisor)
      EmployeeKpi(
        id: 'kpi_201',
        employeeId: 'emp_2',
        periodStart: DateTime.utc(2026, 7, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
        metricName: 'Inventory Accuracy',
        targetValue: 98.0,
        actualValue: 96.5,
        score: 85.0,
        remarks: 'Minor discrepancy in warehouse aisle 4',
        createdAt: DateTime.utc(2026, 7, 1, 10, 0),
        updatedAt: DateTime.utc(2026, 9, 30, 18, 0),
      ),
      EmployeeKpi(
        id: 'kpi_202',
        employeeId: 'emp_2',
        periodStart: DateTime.utc(2026, 7, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
        metricName: 'Order Dispatch Lead Time (Hours)',
        targetValue: 4.0,
        actualValue: 3.5,
        score: 95.0,
        remarks: 'Prompt dispatch fulfillment maintained',
        createdAt: DateTime.utc(2026, 7, 1, 10, 0),
        updatedAt: DateTime.utc(2026, 9, 30, 18, 0),
      ),

      // emp_3: Charlie Davis (Senior Account Executive)
      EmployeeKpi(
        id: 'kpi_301',
        employeeId: 'emp_3',
        periodStart: DateTime.utc(2026, 7, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
        metricName: 'Quarterly Sales Revenue (\$k)',
        targetValue: 150.0,
        actualValue: 165.0,
        score: 100.0,
        remarks: 'Q3 sales target surpassed with enterprise accounts',
        createdAt: DateTime.utc(2026, 7, 1, 10, 0),
        updatedAt: DateTime.utc(2026, 9, 30, 18, 0),
      ),
    ];

    for (final record in seeds) {
      _records[record.id] = record;
    }
  }

  /// Resets the store and re-populates deterministic seeds.
  void reset() {
    _records.clear();
    _seed();
  }

  /// Retrieves cloned KPI records with optional filtering.
  List<EmployeeKpi> getKpis({
    String? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    var results = _records.values.toList();

    if (employeeId != null && employeeId.trim().isNotEmpty) {
      final normalizedId = employeeId.trim();
      results = results.where((r) => r.employeeId == normalizedId).toList();
    }

    if (startDate != null) {
      final normalizedStart = DateTime.utc(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      results = results
          .where((r) => !r.periodEnd.isBefore(normalizedStart))
          .toList();
    }

    if (endDate != null) {
      final normalizedEnd = DateTime.utc(
        endDate.year,
        endDate.month,
        endDate.day,
      );
      results = results
          .where((r) => !r.periodStart.isAfter(normalizedEnd))
          .toList();
    }

    // Sort by periodStart descending, then metricName ascending, then id ascending
    results.sort((a, b) {
      final periodCmp = b.periodStart.compareTo(a.periodStart);
      if (periodCmp != 0) return periodCmp;
      final metricCmp = a.metricName.compareTo(b.metricName);
      if (metricCmp != 0) return metricCmp;
      return a.id.compareTo(b.id);
    });

    return results.map(_cloneKpi).toList();
  }

  /// Retrieves an individual KPI record by [id].
  EmployeeKpi? getKpiById(String id) {
    final record = _records[id];
    return record != null ? _cloneKpi(record) : null;
  }

  /// Retrieves all records for an [employeeId].
  List<EmployeeKpi> getKpisForEmployee(
    String employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return getKpis(
      employeeId: employeeId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  EmployeeKpi _cloneKpi(EmployeeKpi k) {
    return k.copyWith();
  }

  /// Creates a new KPI record with auto-assigned stable ID and UTC normalized dates.
  EmployeeKpi createKpi({
    required String employeeId,
    required String metricName,
    required DateTime periodStart,
    required DateTime periodEnd,
    required double targetValue,
    required double actualValue,
    double? score,
    String? remarks,
  }) {
    if (metricName.trim().isEmpty) {
      throw const EmployeeKpiException('Metric name cannot be empty.');
    }
    final normalizedStart = DateTime.utc(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    );
    final normalizedEnd = DateTime.utc(
      periodEnd.year,
      periodEnd.month,
      periodEnd.day,
    );
    if (normalizedEnd.isBefore(normalizedStart)) {
      throw const EmployeeKpiException(
        'Period end date cannot precede start date.',
      );
    }

    final id =
        'kpi_${DateTime.now().millisecondsSinceEpoch}_${_records.length + 1}';
    final now = DateTime.now().toUtc();

    final record = EmployeeKpi(
      id: id,
      employeeId: employeeId.trim(),
      periodStart: normalizedStart,
      periodEnd: normalizedEnd,
      metricName: metricName.trim(),
      targetValue: targetValue,
      actualValue: actualValue,
      score: score,
      remarks: remarks != null && remarks.trim().isNotEmpty
          ? remarks.trim()
          : null,
      createdAt: now,
      updatedAt: now,
    );

    _records[id] = record;
    return _cloneKpi(record);
  }

  /// Updates an existing KPI record by [id].
  EmployeeKpi updateKpi({
    required String id,
    required String metricName,
    required DateTime periodStart,
    required DateTime periodEnd,
    required double targetValue,
    required double actualValue,
    double? score,
    bool clearScore = false,
    String? remarks,
    bool clearRemarks = false,
  }) {
    final existing = _records[id];
    if (existing == null) {
      throw EmployeeKpiException('KPI record with id "$id" not found.');
    }
    if (metricName.trim().isEmpty) {
      throw const EmployeeKpiException('Metric name cannot be empty.');
    }
    final normalizedStart = DateTime.utc(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    );
    final normalizedEnd = DateTime.utc(
      periodEnd.year,
      periodEnd.month,
      periodEnd.day,
    );
    if (normalizedEnd.isBefore(normalizedStart)) {
      throw const EmployeeKpiException(
        'Period end date cannot precede start date.',
      );
    }

    final updated = existing.copyWith(
      metricName: metricName.trim(),
      periodStart: normalizedStart,
      periodEnd: normalizedEnd,
      targetValue: targetValue,
      actualValue: actualValue,
      score: clearScore ? null : (score ?? existing.score),
      clearScore: clearScore,
      remarks: clearRemarks
          ? null
          : (remarks != null && remarks.trim().isNotEmpty
                ? remarks.trim()
                : existing.remarks),
      clearRemarks: clearRemarks,
      updatedAt: DateTime.now().toUtc(),
    );

    _records[id] = updated;
    return _cloneKpi(updated);
  }
}
