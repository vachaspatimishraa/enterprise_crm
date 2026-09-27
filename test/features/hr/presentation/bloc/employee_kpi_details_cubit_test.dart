import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employee_kpi.dart';
import 'package:enterprise_crm/features/hr/domain/repositories/employee_kpi_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/employee_kpi_details_cubit.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/employee_kpi_details_state.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingEmployeeKpiDetailsRepository implements EmployeeKpiRepository {
  final Exception errorToThrow;

  FailingEmployeeKpiDetailsRepository(this.errorToThrow);

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
}

void main() {
  late MockEmployeeKpiRepository repository;

  setUp(() {
    repository = MockEmployeeKpiRepository();
  });

  group('EmployeeKpiDetailsCubit Tests', () {
    test('initial state has correct default values', () {
      final cubit = EmployeeKpiDetailsCubit(repository: repository);
      expect(cubit.state.status, EmployeeKpiDetailsStatus.initial);
      expect(cubit.state.kpi, isNull);
      expect(cubit.state.searchedId, isNull);
      expect(cubit.state.errorMessage, isNull);
    });

    test('loadKpi loads KPI record when found', () async {
      final cubit = EmployeeKpiDetailsCubit(repository: repository);

      await cubit.loadKpi('kpi_101');

      expect(cubit.state.status, EmployeeKpiDetailsStatus.loaded);
      expect(cubit.state.kpi, isNotNull);
      expect(cubit.state.kpi!.id, 'kpi_101');
      expect(cubit.state.kpi!.metricName, 'Employee Retention Rate');
      expect(cubit.state.errorMessage, isNull);
    });

    test('loadKpi emits notFound when KPI does not exist', () async {
      final cubit = EmployeeKpiDetailsCubit(repository: repository);

      await cubit.loadKpi('kpi_missing');

      expect(cubit.state.status, EmployeeKpiDetailsStatus.notFound);
      expect(cubit.state.kpi, isNull);
      expect(cubit.state.searchedId, 'kpi_missing');
    });

    test('loadKpi emits failure on EmployeeKpiException', () async {
      final failingRepo = FailingEmployeeKpiDetailsRepository(
        const EmployeeKpiException('Record access denied'),
      );
      final cubit = EmployeeKpiDetailsCubit(repository: failingRepo);

      await cubit.loadKpi('kpi_101');

      expect(cubit.state.status, EmployeeKpiDetailsStatus.failure);
      expect(cubit.state.errorMessage, 'Record access denied');
    });

    test(
      'loadKpi emits failure on generic Exception with safe fallback message',
      () async {
        final failingRepo = FailingEmployeeKpiDetailsRepository(
          Exception('Network timeout'),
        );
        final cubit = EmployeeKpiDetailsCubit(repository: failingRepo);

        await cubit.loadKpi('kpi_101');

        expect(cubit.state.status, EmployeeKpiDetailsStatus.failure);
        expect(
          cubit.state.errorMessage,
          'Failed to load KPI details. Please try again.',
        );
      },
    );

    test('reload re-fetches the current KPI record', () async {
      final cubit = EmployeeKpiDetailsCubit(repository: repository);
      await cubit.loadKpi('kpi_201');
      expect(cubit.state.status, EmployeeKpiDetailsStatus.loaded);

      await cubit.reload();
      expect(cubit.state.status, EmployeeKpiDetailsStatus.loaded);
      expect(cubit.state.kpi!.id, 'kpi_201');
    });

    test('does not emit updates if closed during operation', () async {
      final cubit = EmployeeKpiDetailsCubit(repository: repository);
      final future = cubit.loadKpi('kpi_101');
      await cubit.close();
      await future;

      expect(cubit.isClosed, isTrue);
    });
  });
}
