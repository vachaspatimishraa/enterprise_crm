import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_document_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/employee_documents_cubit.dart';
import 'package:enterprise_crm/features/hr/presentation/bloc/employee_documents_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockEmployeeDocumentRepository repository;
  late EmployeeDocumentsCubit cubit;

  setUp(() {
    repository = MockEmployeeDocumentRepository();
    cubit = EmployeeDocumentsCubit(repository, employeeId: 'emp_1');
  });

  tearDown(() {
    cubit.close();
  });

  group('EmployeeDocumentsCubit Tests', () {
    test('initial state has initial status and empty list', () {
      expect(cubit.state.status, EmployeeDocumentsStatus.initial);
      expect(cubit.state.documents, isEmpty);
      expect(cubit.state.filteredDocuments, isEmpty);
    });

    test(
      'loadDocuments emits loading then loaded with employee documents',
      () async {
        await cubit.loadDocuments();

        expect(cubit.state.status, EmployeeDocumentsStatus.loaded);
        expect(cubit.state.documents.length, 2);
        expect(cubit.state.filteredDocuments.length, 2);
      },
    );

    test(
      'setSearchQuery filters documents by title, file name, or type',
      () async {
        await cubit.loadDocuments();

        cubit.setSearchQuery('agreement');
        expect(cubit.state.filteredDocuments.length, 1);
        expect(
          cubit.state.filteredDocuments.first.title,
          'Employment Agreement',
        );

        cubit.setSearchQuery('identity');
        expect(cubit.state.filteredDocuments.length, 1);
        expect(
          cubit.state.filteredDocuments.first.title,
          'National Identity Proof',
        );

        cubit.setSearchQuery('nonexistent');
        expect(cubit.state.filteredDocuments, isEmpty);
      },
    );

    test('setFilterType filters documents strictly by type', () async {
      await cubit.loadDocuments();

      cubit.setFilterType('Contract');
      expect(cubit.state.filteredDocuments.length, 1);
      expect(cubit.state.filteredDocuments.first.documentType, 'Contract');

      // Toggling the same filter clears it
      cubit.setFilterType('Contract');
      expect(cubit.state.filterType, isNull);
      expect(cubit.state.filteredDocuments.length, 2);
    });

    test('resetFilters clears query and active type filter', () async {
      await cubit.loadDocuments();
      cubit.setSearchQuery('National');
      cubit.setFilterType('Identity');

      expect(cubit.state.filteredDocuments.length, 1);

      cubit.resetFilters();
      expect(cubit.state.searchQuery, '');
      expect(cubit.state.filterType, isNull);
      expect(cubit.state.filteredDocuments.length, 2);
    });

    test(
      'refresh preserves active filters while updating document list',
      () async {
        await cubit.loadDocuments();
        cubit.setFilterType('Contract');

        await cubit.refresh();
        expect(cubit.state.filterType, 'Contract');
        expect(cubit.state.filteredDocuments.length, 1);
      },
    );
  });
}
