import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employee_kpi.dart';
import 'package:enterprise_crm/features/hr/domain/repositories/employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/employee_kpi_list_cubit.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/employee_kpi_list_state.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingEmployeeKpiRepository implements EmployeeKpiRepository {
  final Exception errorToThrow;

  FailingEmployeeKpiRepository(this.errorToThrow);

  @override
  Future<List<EmployeeKpi>> getKpis({
    String? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    throw errorToThrow;
  }

  @override
  Future<List<EmployeeKpi>> getKpisForEmployee(
    String employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    throw errorToThrow;
  }

  @override
  Future<EmployeeKpi?> getKpiById(String id) async {
    throw errorToThrow;
  }

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
  }) async => throw UnimplementedError();

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
  }) async => throw UnimplementedError();
}

void main() {
  late MockEmployeeKpiRepository repository;

  setUp(() {
    repository = MockEmployeeKpiRepository();
  });

  group('EmployeeKpiListCubit Tests', () {
    test('initial state has correct default values', () {
      final cubit = EmployeeKpiListCubit(repository: repository);
      expect(cubit.state.status, EmployeeKpiListStatus.initial);
      expect(cubit.state.kpis, isEmpty);
      expect(cubit.state.filteredKpis, isEmpty);
      expect(cubit.state.selectedEmployeeId, isNull);
      expect(cubit.state.searchQuery, isEmpty);
      expect(cubit.state.selectedMetric, isNull);
      expect(cubit.state.startDate, isNull);
      expect(cubit.state.endDate, isNull);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.isEmpty, isFalse);
      expect(cubit.state.isFilteredEmpty, isFalse);
    });

    test('initial state preserves initialEmployeeId if provided', () {
      final cubit = EmployeeKpiListCubit(
        repository: repository,
        initialEmployeeId: 'emp_1',
      );
      expect(cubit.state.selectedEmployeeId, 'emp_1');
    });

    test('loadKpis loads seeded KPI records successfully', () async {
      final cubit = EmployeeKpiListCubit(repository: repository);

      await cubit.loadKpis();

      expect(cubit.state.status, EmployeeKpiListStatus.loaded);
      expect(cubit.state.kpis.length, 5);
      expect(cubit.state.filteredKpis.length, 5);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.isEmpty, isFalse);
      expect(cubit.state.isFilteredEmpty, isFalse);
    });

    test(
      'loadKpis with selectedEmployeeId loads only matching records',
      () async {
        final cubit = EmployeeKpiListCubit(
          repository: repository,
          initialEmployeeId: 'emp_1',
        );

        await cubit.loadKpis();

        expect(cubit.state.status, EmployeeKpiListStatus.loaded);
        expect(cubit.state.kpis.length, 2);
        expect(cubit.state.filteredKpis.length, 2);
        expect(cubit.state.kpis.every((k) => k.employeeId == 'emp_1'), isTrue);
      },
    );

    test(
      'loadKpis for employee without KPIs emits loaded with isEmpty == true',
      () async {
        final cubit = EmployeeKpiListCubit(
          repository: repository,
          initialEmployeeId: 'emp_4',
        );

        await cubit.loadKpis();

        expect(cubit.state.status, EmployeeKpiListStatus.loaded);
        expect(cubit.state.kpis, isEmpty);
        expect(cubit.state.filteredKpis, isEmpty);
        expect(cubit.state.isEmpty, isTrue);
        expect(cubit.state.isFilteredEmpty, isFalse);
      },
    );

    test('loadKpis emits failure on EmployeeKpiException', () async {
      final failingRepo = FailingEmployeeKpiRepository(
        const EmployeeKpiException('Backend service unavailable'),
      );
      final cubit = EmployeeKpiListCubit(repository: failingRepo);

      await cubit.loadKpis();

      expect(cubit.state.status, EmployeeKpiListStatus.failure);
      expect(cubit.state.errorMessage, 'Backend service unavailable');
    });

    test(
      'loadKpis emits failure on generic Exception with safe fallback message',
      () async {
        final failingRepo = FailingEmployeeKpiRepository(
          Exception('Socket closed'),
        );
        final cubit = EmployeeKpiListCubit(repository: failingRepo);

        await cubit.loadKpis();

        expect(cubit.state.status, EmployeeKpiListStatus.failure);
        expect(
          cubit.state.errorMessage,
          'Failed to load employee KPI records. Please try again.',
        );
      },
    );

    test('setEmployeeFilter updates employee and triggers reload', () async {
      final cubit = EmployeeKpiListCubit(repository: repository);
      await cubit.loadKpis();
      expect(cubit.state.kpis.length, 5);

      await cubit.setEmployeeFilter('emp_2');
      expect(cubit.state.selectedEmployeeId, 'emp_2');
      expect(cubit.state.kpis.length, 2);
      expect(cubit.state.filteredKpis.length, 2);
      expect(cubit.state.kpis.every((k) => k.employeeId == 'emp_2'), isTrue);

      await cubit.setEmployeeFilter(null);
      expect(cubit.state.selectedEmployeeId, isNull);
      expect(cubit.state.kpis.length, 5);
      expect(cubit.state.filteredKpis.length, 5);
    });

    test(
      'setDateRangeFilter updates date boundaries and triggers reload',
      () async {
        final cubit = EmployeeKpiListCubit(repository: repository);

        await cubit.setDateRangeFilter(
          startDate: DateTime.utc(2027, 1, 1),
          endDate: DateTime.utc(2027, 3, 31),
        );

        expect(cubit.state.startDate, DateTime.utc(2027, 1, 1));
        expect(cubit.state.endDate, DateTime.utc(2027, 3, 31));
        expect(cubit.state.kpis, isEmpty);
        expect(cubit.state.isEmpty, isTrue);
      },
    );

    test('setSearchQuery filters records locally by metric name', () async {
      final cubit = EmployeeKpiListCubit(repository: repository);
      await cubit.loadKpis();

      cubit.setSearchQuery('retention');
      expect(cubit.state.filteredKpis.length, 1);
      expect(
        cubit.state.filteredKpis.first.metricName,
        'Employee Retention Rate',
      );
      expect(cubit.state.kpis.length, 5); // Raw records unchanged
    });

    test('setSearchQuery filters records by resolved employee name', () async {
      final cubit = EmployeeKpiListCubit(
        repository: repository,
        employeeNameMap: {'emp_1': 'Alice Johnson', 'emp_2': 'Bob Miller'},
      );
      await cubit.loadKpis();

      cubit.setSearchQuery('alice');
      expect(cubit.state.filteredKpis.length, 2);
      expect(
        cubit.state.filteredKpis.every((k) => k.employeeId == 'emp_1'),
        isTrue,
      );
    });

    test('setSelectedMetric filters records by exact metric name', () async {
      final cubit = EmployeeKpiListCubit(repository: repository);
      await cubit.loadKpis();

      cubit.setSelectedMetric('Inventory Accuracy');
      expect(cubit.state.filteredKpis.length, 1);
      expect(cubit.state.filteredKpis.first.id, 'kpi_201');

      cubit.setSelectedMetric('All');
      expect(cubit.state.filteredKpis.length, 5);
    });

    test(
      'isFilteredEmpty is true when records exist but search matches nothing',
      () async {
        final cubit = EmployeeKpiListCubit(repository: repository);
        await cubit.loadKpis();

        cubit.setSearchQuery('nonexistent_metric_query');
        expect(cubit.state.filteredKpis, isEmpty);
        expect(cubit.state.isEmpty, isFalse);
        expect(cubit.state.isFilteredEmpty, isTrue);
      },
    );

    test(
      'resetFilters clears all active filters and reloads records',
      () async {
        final cubit = EmployeeKpiListCubit(
          repository: repository,
          initialEmployeeId: 'emp_2',
        );
        await cubit.loadKpis();
        cubit.setSearchQuery('Lead');
        cubit.setSelectedMetric('Order Dispatch Lead Time (Hours)');

        expect(cubit.state.filteredKpis.length, 1);

        await cubit.resetFilters();

        expect(cubit.state.searchQuery, isEmpty);
        expect(cubit.state.selectedMetric, isNull);
        expect(cubit.state.selectedEmployeeId, isNull);
        expect(cubit.state.startDate, isNull);
        expect(cubit.state.endDate, isNull);
        expect(cubit.state.filteredKpis.length, 5);
      },
    );

    test('reload re-fetches records using current filters', () async {
      final cubit = EmployeeKpiListCubit(
        repository: repository,
        initialEmployeeId: 'emp_3',
      );

      await cubit.loadKpis();
      expect(cubit.state.kpis.length, 1);

      await cubit.reload();
      expect(cubit.state.status, EmployeeKpiListStatus.loaded);
      expect(cubit.state.kpis.length, 1);
    });

    test(
      'does not emit updates if cubit is closed during async operation',
      () async {
        final cubit = EmployeeKpiListCubit(repository: repository);
        final future = cubit.loadKpis();
        await cubit.close();
        await future;

        expect(cubit.isClosed, isTrue);
      },
    );
  });
}
