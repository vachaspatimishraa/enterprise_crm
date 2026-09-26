import '../../domain/entities/employee_document.dart';

enum EmployeeDocumentsStatus { initial, loading, loaded, failure }

/// Immutable state for the Employee Documents feature.
class EmployeeDocumentsState {
  final EmployeeDocumentsStatus status;
  final List<EmployeeDocument> documents;
  final String? errorMessage;
  final String searchQuery;
  final String? filterType;

  const EmployeeDocumentsState({
    this.status = EmployeeDocumentsStatus.initial,
    this.documents = const [],
    this.errorMessage,
    this.searchQuery = '',
    this.filterType,
  });

  bool get isInitial => status == EmployeeDocumentsStatus.initial;
  bool get isLoading => status == EmployeeDocumentsStatus.loading;
  bool get isLoaded => status == EmployeeDocumentsStatus.loaded;
  bool get isFailure => status == EmployeeDocumentsStatus.failure;
  bool get isEmpty => isLoaded && filteredDocuments.isEmpty;

  /// Returns documents filtered by search query and type filter.
  List<EmployeeDocument> get filteredDocuments {
    var result = List<EmployeeDocument>.from(documents);

    if (filterType != null && filterType!.trim().isNotEmpty) {
      final normalizedType = filterType!.trim().toLowerCase();
      result = result
          .where((d) => d.documentType.trim().toLowerCase() == normalizedType)
          .toList();
    }

    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((d) {
        final matchesTitle = d.title.toLowerCase().contains(query);
        final matchesFileName = d.fileName.toLowerCase().contains(query);
        final matchesType = d.documentType.toLowerCase().contains(query);
        final matchesExt = d.fileExtension.toLowerCase().contains(query);
        return matchesTitle || matchesFileName || matchesType || matchesExt;
      }).toList();
    }

    return result;
  }

  /// Available document types present in the current dataset.
  Set<String> get availableTypes => documents
      .map((d) => d.documentType.trim())
      .where((t) => t.isNotEmpty)
      .toSet();

  EmployeeDocumentsState copyWith({
    EmployeeDocumentsStatus? status,
    List<EmployeeDocument>? documents,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? searchQuery,
    String? filterType,
    bool clearFilterType = false,
  }) {
    return EmployeeDocumentsState(
      status: status ?? this.status,
      documents: documents ?? this.documents,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      filterType: clearFilterType ? null : (filterType ?? this.filterType),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmployeeDocumentsState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          errorMessage == other.errorMessage &&
          searchQuery == other.searchQuery &&
          filterType == other.filterType &&
          documents.length == other.documents.length;

  @override
  int get hashCode => Object.hash(
    status,
    errorMessage,
    searchQuery,
    filterType,
    documents.length,
  );
}
