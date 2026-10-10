import 'package:enterprise_crm/features/hr/data/mock/mock_employee_kpi_store.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employee_kpi.dart';
import 'package:enterprise_crm/features/hr/domain/repositories/employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/employee_kpi_form_cubit.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/employee_kpi_form_state.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingEmployeeKpiRepository implements EmployeeKpiRepository {
  final bool throwDomainException;

  FailingEmployeeKpiRepository({this.throwDomainException = true});

  @override
  Future<List<EmployeeKpi>> getKpis({
    String? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async => [];

  @override
  Future<List<EmployeeKpi>> getKpisForEmployee(
    String employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async => [];

  @override
  Future<EmployeeKpi?> getKpiById(String id) async => null;

  @override
  Future<EmployeeKpi> createKpi({
    required String employeeId,
    required String metricName,
    required DateTime periodStart,
    required DateTime periodEnd,
    required double targetValue,
    required double actualValue,
    double? score,
    String? remarks,
  }) async {
    if (throwDomainException) {
      throw const EmployeeKpiException('Domain error creating KPI.');
    }
    throw Exception('Unexpected crash');
  }

  @override
  Future<EmployeeKpi> updateKpi({
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
  }) async {
    if (throwDomainException) {
      throw const EmployeeKpiException('Domain error updating KPI.');
    }
    throw Exception('Unexpected crash');
  }
}

void main() {
  late MockEmployeeKpiStore store;
  late MockEmployeeKpiRepository repository;
  late EmployeeKpiFormCubit cubit;

  setUp(() {
    store = MockEmployeeKpiStore();
    repository = MockEmployeeKpiRepository(store: store);
    cubit = EmployeeKpiFormCubit(repository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  group('EmployeeKpiFormCubit Tests', () {
    test('initial state has initial status and no error or record', () {
      expect(cubit.state.status, EmployeeKpiFormStatus.initial);
      expect(cubit.state.isSubmitting, isFalse);
      expect(cubit.state.isSuccess, isFalse);
      expect(cubit.state.isFailure, isFalse);
      expect(cubit.state.createdOrUpdatedKpi, isNull);
      expect(cubit.state.errorMessage, isNull);
    });

    group('submitCreate validation', () {
      test('rejects empty employeeId without calling repository', () async {
        await cubit.submitCreate(
          employeeId: '   ',
          metricName: 'Valid Metric',
          periodStart: DateTime.utc(2026, 7, 1),
          periodEnd: DateTime.utc(2026, 9, 30),
          targetValue: 100,
          actualValue: 90,
        );

        expect(cubit.state.status, EmployeeKpiFormStatus.failure);
        expect(cubit.state.errorMessage, 'An employee must be selected.');
      });

      test('rejects empty metricName without calling repository', () async {
        await cubit.submitCreate(
          employeeId: 'emp_1',
          metricName: '  ',
          periodStart: DateTime.utc(2026, 7, 1),
          periodEnd: DateTime.utc(2026, 9, 30),
          targetValue: 100,
          actualValue: 90,
        );

        expect(cubit.state.status, EmployeeKpiFormStatus.failure);
        expect(cubit.state.errorMessage, 'Metric name is required.');
      });

      test('rejects periodEnd preceding periodStart', () async {
        await cubit.submitCreate(
          employeeId: 'emp_1',
          metricName: 'Valid Metric',
          periodStart: DateTime.utc(2026, 9, 30),
          periodEnd: DateTime.utc(2026, 7, 1),
          targetValue: 100,
          actualValue: 90,
        );

        expect(cubit.state.status, EmployeeKpiFormStatus.failure);
        expect(
          cubit.state.errorMessage,
          'Period end date cannot precede start date.',
        );
      });
    });

    group('submitUpdate validation', () {
      test('rejects empty metricName without calling repository', () async {
        await cubit.submitUpdate(
          id: 'kpi_101',
          metricName: '  ',
          periodStart: DateTime.utc(2026, 7, 1),
          periodEnd: DateTime.utc(2026, 9, 30),
          targetValue: 100,
          actualValue: 90,
        );

        expect(cubit.state.status, EmployeeKpiFormStatus.failure);
        expect(cubit.state.errorMessage, 'Metric name is required.');
      });

      test('rejects periodEnd preceding periodStart', () async {
        await cubit.submitUpdate(
          id: 'kpi_101',
          metricName: 'Valid Metric',
          periodStart: DateTime.utc(2026, 9, 30),
          periodEnd: DateTime.utc(2026, 7, 1),
          targetValue: 100,
          actualValue: 90,
        );

        expect(cubit.state.status, EmployeeKpiFormStatus.failure);
        expect(
          cubit.state.errorMessage,
          'Period end date cannot precede start date.',
        );
      });
    });

    test(
      'successful create emits submitting then success with new KPI',
      () async {
        expectLater(
          cubit.stream,
          emitsInOrder([
            predicate<EmployeeKpiFormState>(
              (s) => s.status == EmployeeKpiFormStatus.submitting,
            ),
            predicate<EmployeeKpiFormState>(
              (s) =>
                  s.status == EmployeeKpiFormStatus.success &&
                  s.createdOrUpdatedKpi?.metricName == 'Warehouse Throughput' &&
                  s.createdOrUpdatedKpi?.employeeId == 'emp_2' &&
                  s.createdOrUpdatedKpi?.score == 95.0,
            ),
          ]),
        );

        await cubit.submitCreate(
          employeeId: 'emp_2',
          metricName: 'Warehouse Throughput',
          periodStart: DateTime.utc(2026, 7, 1),
          periodEnd: DateTime.utc(2026, 9, 30),
          targetValue: 500,
          actualValue: 520,
          score: 95.0,
          remarks: 'Great performance',
        );

        expect(cubit.state.status, EmployeeKpiFormStatus.success);
        expect(
          cubit.state.createdOrUpdatedKpi?.metricName,
          'Warehouse Throughput',
        );
      },
    );

    test(
      'successful update emits submitting then success with updated KPI',
      () async {
        expectLater(
          cubit.stream,
          emitsInOrder([
            predicate<EmployeeKpiFormState>(
              (s) => s.status == EmployeeKpiFormStatus.submitting,
            ),
            predicate<EmployeeKpiFormState>(
              (s) =>
                  s.status == EmployeeKpiFormStatus.success &&
                  s.createdOrUpdatedKpi?.metricName ==
                      'Modified Retention Rate' &&
                  s.createdOrUpdatedKpi?.targetValue == 95.0,
            ),
          ]),
        );

        await cubit.submitUpdate(
          id: 'kpi_101',
          metricName: 'Modified Retention Rate',
          periodStart: DateTime.utc(2026, 7, 1),
          periodEnd: DateTime.utc(2026, 9, 30),
          targetValue: 95,
          actualValue: 93,
          score: 88.0,
          remarks: 'Slightly revised',
        );

        expect(cubit.state.status, EmployeeKpiFormStatus.success);
        expect(
          cubit.state.createdOrUpdatedKpi?.metricName,
          'Modified Retention Rate',
        );
      },
    );

    test('prevents duplicate submissions when isSubmitting is true', () async {
      // Simulate state already submitting
      cubit.emit(
        const EmployeeKpiFormState(status: EmployeeKpiFormStatus.submitting),
      );

      await cubit.submitCreate(
        employeeId: 'emp_1',
        metricName: 'Duplicate Test',
        periodStart: DateTime.utc(2026, 7, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
        targetValue: 100,
        actualValue: 90,
      );

      // State should remain unchanged in submitting
      expect(cubit.state.status, EmployeeKpiFormStatus.submitting);
      expect(cubit.state.createdOrUpdatedKpi, isNull);

      await cubit.submitUpdate(
        id: 'kpi_101',
        metricName: 'Duplicate Update',
        periodStart: DateTime.utc(2026, 7, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
        targetValue: 100,
        actualValue: 90,
      );

      expect(cubit.state.status, EmployeeKpiFormStatus.submitting);
      expect(cubit.state.createdOrUpdatedKpi, isNull);
    });

    test(
      'handles EmployeeKpiException gracefully on create and update',
      () async {
        final failingRepo = FailingEmployeeKpiRepository(
          throwDomainException: true,
        );
        final failCubit = EmployeeKpiFormCubit(repository: failingRepo);

        await failCubit.submitCreate(
          employeeId: 'emp_1',
          metricName: 'Any Metric',
          periodStart: DateTime.utc(2026, 7, 1),
          periodEnd: DateTime.utc(2026, 9, 30),
          targetValue: 10,
          actualValue: 10,
        );
        expect(failCubit.state.status, EmployeeKpiFormStatus.failure);
        expect(failCubit.state.errorMessage, 'Domain error creating KPI.');

        await failCubit.submitUpdate(
          id: 'kpi_101',
          metricName: 'Any Metric',
          periodStart: DateTime.utc(2026, 7, 1),
          periodEnd: DateTime.utc(2026, 9, 30),
          targetValue: 10,
          actualValue: 10,
        );
        expect(failCubit.state.status, EmployeeKpiFormStatus.failure);
        expect(failCubit.state.errorMessage, 'Domain error updating KPI.');

        await failCubit.close();
      },
    );

    test('handles unexpected exception with user-friendly message', () async {
      final crashingRepo = FailingEmployeeKpiRepository(
        throwDomainException: false,
      );
      final crashCubit = EmployeeKpiFormCubit(repository: crashingRepo);

      await crashCubit.submitCreate(
        employeeId: 'emp_1',
        metricName: 'Any Metric',
        periodStart: DateTime.utc(2026, 7, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
        targetValue: 10,
        actualValue: 10,
      );
      expect(crashCubit.state.status, EmployeeKpiFormStatus.failure);
      expect(
        crashCubit.state.errorMessage,
        'Failed to create KPI. Please try again.',
      );

      await crashCubit.close();
    });
  });
}
