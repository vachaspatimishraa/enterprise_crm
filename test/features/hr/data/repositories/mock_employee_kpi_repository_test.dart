import 'package:enterprise_crm/features/hr/data/mock/mock_employee_kpi_store.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_kpi_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockEmployeeKpiStore store;
  late MockEmployeeKpiRepository repository;

  setUp(() {
    store = MockEmployeeKpiStore();
    repository = MockEmployeeKpiRepository(store: store);
  });

  group('MockEmployeeKpiRepository Tests', () {
    test('retrieves all seeded KPI records in deterministic order', () async {
      final kpis = await repository.getKpis();

      expect(kpis.length, 5);
      expect(kpis.map((k) => k.id).toList(), [
        'kpi_101',
        'kpi_201',
        'kpi_202',
        'kpi_301',
        'kpi_102',
      ]);
    });

    test('retrieves KPI records filtered by employeeId', () async {
      final aliceKpis = await repository.getKpis(employeeId: 'emp_1');
      expect(aliceKpis.length, 2);
      expect(aliceKpis.every((k) => k.employeeId == 'emp_1'), isTrue);
      expect(aliceKpis.map((k) => k.id).toSet(), {'kpi_101', 'kpi_102'});

      final bobKpis = await repository.getKpis(employeeId: 'emp_2');
      expect(bobKpis.length, 2);
      expect(bobKpis.every((k) => k.employeeId == 'emp_2'), isTrue);
      expect(bobKpis.map((k) => k.id).toSet(), {'kpi_201', 'kpi_202'});
    });

    test('getKpisForEmployee delegates with correct employeeId', () async {
      final charlieKpis = await repository.getKpisForEmployee('emp_3');
      expect(charlieKpis.length, 1);
      expect(charlieKpis.first.id, 'kpi_301');
      expect(charlieKpis.first.employeeId, 'emp_3');
      expect(charlieKpis.first.metricName, 'Quarterly Sales Revenue (\$k)');
    });

    test('returns empty list for employee with no KPI records', () async {
      final danaKpis = await repository.getKpisForEmployee('emp_4');
      expect(danaKpis, isEmpty);

      final unknownKpis = await repository.getKpisForEmployee('emp_unknown');
      expect(unknownKpis, isEmpty);
    });

    test('retrieves an individual KPI by stable id', () async {
      final kpi = await repository.getKpiById('kpi_101');
      expect(kpi, isNotNull);
      expect(kpi!.id, 'kpi_101');
      expect(kpi.employeeId, 'emp_1');
      expect(kpi.metricName, 'Employee Retention Rate');
      expect(kpi.targetValue, 90.0);
      expect(kpi.actualValue, 92.5);
      expect(kpi.score, 95.0);
    });

    test('returns null for unknown KPI id', () async {
      final kpi = await repository.getKpiById('kpi_nonexistent');
      expect(kpi, isNull);
    });

    test('filters KPI records by date boundaries', () async {
      // Matching range
      final q3Kpis = await repository.getKpis(
        startDate: DateTime.utc(2026, 7, 1),
        endDate: DateTime.utc(2026, 9, 30),
      );
      expect(q3Kpis.length, 5);

      // Future date range outside Q3
      final futureKpis = await repository.getKpis(
        startDate: DateTime.utc(2027, 1, 1),
        endDate: DateTime.utc(2027, 3, 31),
      );
      expect(futureKpis, isEmpty);

      // Past date range outside Q3
      final pastKpis = await repository.getKpis(
        startDate: DateTime.utc(2025, 1, 1),
        endDate: DateTime.utc(2025, 3, 31),
      );
      expect(pastKpis, isEmpty);
    });

    test(
      'enforces cross-employee isolation: emp_1 KPIs never leak to emp_2',
      () async {
        final emp1Kpis = await repository.getKpisForEmployee('emp_1');
        final emp2Kpis = await repository.getKpisForEmployee('emp_2');

        final emp1Ids = emp1Kpis.map((k) => k.id).toSet();
        final emp2Ids = emp2Kpis.map((k) => k.id).toSet();

        expect(emp1Ids.intersection(emp2Ids), isEmpty);
      },
    );

    test(
      'defensive immutability: modifications to returned list do not alter store',
      () async {
        final initial = await repository.getKpis();
        expect(initial.length, 5);

        // In Dart, if an unmodifiable list is mutated it throws, or if fresh list is cleared it doesn't affect store
        final fresh = await repository.getKpis();
        fresh.clear();

        final reFetched = await repository.getKpis();
        expect(reFetched.length, 5);
      },
    );

    test('store reset restores initial deterministic seed state', () async {
      store.reset();
      final kpis = await repository.getKpis();
      expect(kpis.length, 5);
      expect(kpis.map((k) => k.id).toSet(), {
        'kpi_101',
        'kpi_102',
        'kpi_201',
        'kpi_202',
        'kpi_301',
      });
    });
  });
}
