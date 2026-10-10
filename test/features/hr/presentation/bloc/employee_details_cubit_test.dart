import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/employee_details_cubit.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/employee_details_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockEmployeeRepository repository;
  late EmployeeDetailsCubit cubit;

  setUp(() {
    repository = MockEmployeeRepository();
    cubit = EmployeeDetailsCubit(repository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  group('EmployeeDetailsCubit', () {
    test('initial state has initial status', () {
      expect(cubit.state.status, EmployeeDetailsStatus.initial);
      expect(cubit.state.employee, isNull);
    });

    test('loadEmployee loads employee when found', () async {
      await cubit.loadEmployee('emp_1');
      expect(cubit.state.status, EmployeeDetailsStatus.loaded);
      expect(cubit.state.employee, isNotNull);
      expect(cubit.state.employee!.fullName, 'Alice Johnson');
    });

    test('loadEmployee emits notFound when ID does not exist', () async {
      await cubit.loadEmployee('emp_unknown_999');
      expect(cubit.state.status, EmployeeDetailsStatus.notFound);
      expect(cubit.state.employee, isNull);
      expect(cubit.state.searchedId, 'emp_unknown_999');
    });

    test('reload reloads current employee record', () async {
      await cubit.loadEmployee('emp_1');
      expect(cubit.state.status, EmployeeDetailsStatus.loaded);

      await cubit.reload();
      expect(cubit.state.status, EmployeeDetailsStatus.loaded);
      expect(cubit.state.employee!.fullName, 'Alice Johnson');
    });
  });
}
