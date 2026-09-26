import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/employee_document_repository.dart';
import 'employee_documents_state.dart';

/// Cubit managing state for the Employee Documents feature.
class EmployeeDocumentsCubit extends Cubit<EmployeeDocumentsState> {
  final EmployeeDocumentRepository _repository;
  final String employeeId;

  EmployeeDocumentsCubit(this._repository, {required this.employeeId})
    : super(const EmployeeDocumentsState());

  /// Loads documents for [employeeId] from the repository.
  Future<void> loadDocuments() async {
    emit(state.copyWith(status: EmployeeDocumentsStatus.loading));
    try {
      final docs = await _repository.getDocumentsForEmployee(employeeId);
      emit(
        state.copyWith(
          status: EmployeeDocumentsStatus.loaded,
          documents: docs,
          clearErrorMessage: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: EmployeeDocumentsStatus.failure,
          errorMessage: e is EmployeeDocumentException
              ? e.message
              : 'Failed to load employee documents.',
        ),
      );
    }
  }

  /// Sets the active search query.
  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  /// Sets the active document type filter chip.
  void setFilterType(String? type) {
    if (state.filterType == type) {
      emit(state.copyWith(clearFilterType: true));
    } else {
      emit(state.copyWith(filterType: type));
    }
  }

  /// Resets search query and filter chips.
  void resetFilters() {
    emit(state.copyWith(searchQuery: '', clearFilterType: true));
  }

  /// Refreshes the document list while preserving active filters.
  Future<void> refresh() async {
    try {
      final docs = await _repository.getDocumentsForEmployee(employeeId);
      emit(
        state.copyWith(
          status: EmployeeDocumentsStatus.loaded,
          documents: docs,
          clearErrorMessage: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: EmployeeDocumentsStatus.failure,
          errorMessage: e is EmployeeDocumentException
              ? e.message
              : 'Failed to refresh employee documents.',
        ),
      );
    }
  }
}
