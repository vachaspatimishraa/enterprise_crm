import 'package:enterprise_crm/features/hr/domain/entities/employee_kpi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmployeeKpi Domain Entity Tests', () {
    final start = DateTime(2026, 7, 1, 14, 30);
    final end = DateTime(2026, 9, 30, 22, 15);

    test('normalizes periodStart and periodEnd to UTC midnight', () {
      final kpi = EmployeeKpi(
        id: 'kpi_test_1',
        employeeId: 'emp_1',
        periodStart: start,
        periodEnd: end,
        metricName: 'Customer Satisfaction',
        targetValue: 95.0,
        actualValue: 97.2,
      );

      expect(kpi.periodStart, DateTime.utc(2026, 7, 1));
      expect(kpi.periodEnd, DateTime.utc(2026, 9, 30));
    });

    test('preserves all approved fields correctly', () {
      final now = DateTime.utc(2026, 7, 1);
      final kpi = EmployeeKpi(
        id: 'kpi_test_1',
        employeeId: 'emp_1',
        periodStart: DateTime.utc(2026, 7, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
        metricName: 'Retention',
        targetValue: 90.0,
        actualValue: 92.5,
        score: 95.0,
        remarks: 'Target met smoothly',
        createdAt: now,
        updatedAt: now,
      );

      expect(kpi.id, 'kpi_test_1');
      expect(kpi.employeeId, 'emp_1');
      expect(kpi.metricName, 'Retention');
      expect(kpi.targetValue, 90.0);
      expect(kpi.actualValue, 92.5);
      expect(kpi.score, 95.0);
      expect(kpi.remarks, 'Target met smoothly');
      expect(kpi.createdAt, now);
      expect(kpi.updatedAt, now);
    });

    test(
      'supports nullable optional fields (score, remarks, audit fields)',
      () {
        final kpi = EmployeeKpi(
          id: 'kpi_test_2',
          employeeId: 'emp_2',
          periodStart: DateTime.utc(2026, 1, 1),
          periodEnd: DateTime.utc(2026, 3, 31),
          metricName: 'Sales Conversion',
          targetValue: 20.0,
          actualValue: 18.5,
        );

        expect(kpi.score, isNull);
        expect(kpi.remarks, isNull);
        expect(kpi.createdAt, isNull);
        expect(kpi.updatedAt, isNull);
      },
    );

    test('formattedPeriod returns YYYY-MM-DD – YYYY-MM-DD', () {
      final kpi = EmployeeKpi(
        id: 'kpi_test_1',
        employeeId: 'emp_1',
        periodStart: DateTime.utc(2026, 7, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
        metricName: 'Retention',
        targetValue: 90.0,
        actualValue: 92.5,
      );

      expect(kpi.formattedPeriod, '2026-07-01 – 2026-09-30');
    });

    test(
      'copyWith updates specified fields and supports clearing nullable fields',
      () {
        final original = EmployeeKpi(
          id: 'kpi_test_1',
          employeeId: 'emp_1',
          periodStart: DateTime.utc(2026, 7, 1),
          periodEnd: DateTime.utc(2026, 9, 30),
          metricName: 'Retention',
          targetValue: 90.0,
          actualValue: 92.5,
          score: 95.0,
          remarks: 'Original note',
        );

        final updated = original.copyWith(
          actualValue: 94.0,
          clearScore: true,
          clearRemarks: true,
        );

        expect(updated.id, original.id);
        expect(updated.employeeId, original.employeeId);
        expect(updated.targetValue, 90.0);
        expect(updated.actualValue, 94.0);
        expect(updated.score, isNull);
        expect(updated.remarks, isNull);
      },
    );

    test('value-based equality and hashCode work correctly', () {
      final kpi1 = EmployeeKpi(
        id: 'kpi_1',
        employeeId: 'emp_1',
        periodStart: DateTime.utc(2026, 7, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
        metricName: 'Retention',
        targetValue: 90.0,
        actualValue: 92.5,
        score: 95.0,
        remarks: 'Note',
      );

      final kpi2 = EmployeeKpi(
        id: 'kpi_1',
        employeeId: 'emp_1',
        periodStart: DateTime.utc(2026, 7, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
        metricName: 'Retention',
        targetValue: 90.0,
        actualValue: 92.5,
        score: 95.0,
        remarks: 'Note',
      );

      final kpi3 = kpi1.copyWith(actualValue: 93.0);

      expect(kpi1, equals(kpi2));
      expect(kpi1.hashCode, equals(kpi2.hashCode));
      expect(kpi1, isNot(equals(kpi3)));
    });

    test('toString includes key identifying information', () {
      final kpi = EmployeeKpi(
        id: 'kpi_101',
        employeeId: 'emp_1',
        periodStart: DateTime.utc(2026, 7, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
        metricName: 'Retention',
        targetValue: 90.0,
        actualValue: 92.5,
        score: 95.0,
      );

      final str = kpi.toString();
      expect(str, contains('kpi_101'));
      expect(str, contains('emp_1'));
      expect(str, contains('Retention'));
      expect(str, contains('90.0'));
      expect(str, contains('92.5'));
      expect(str, contains('95.0'));
    });
  });
}
