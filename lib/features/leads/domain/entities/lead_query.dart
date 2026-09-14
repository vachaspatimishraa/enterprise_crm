import 'lead_source.dart';
import 'lead_status.dart';

class LeadQuery {
  final String? searchText;
  final LeadStatus? status;
  final LeadSource? source;
  final String? assignedUserId;
  final bool? isAssigned;
  final int page;
  final int pageSize;

  const LeadQuery({
    this.searchText,
    this.status,
    this.source,
    this.assignedUserId,
    this.isAssigned,
    this.page = 1,
    this.pageSize = 20,
  });

  static const LeadQuery empty = LeadQuery();

  bool get isEmpty =>
      (searchText == null || searchText!.trim().isEmpty) &&
      status == null &&
      source == null &&
      assignedUserId == null &&
      isAssigned == null &&
      page == 1;

  LeadQuery copyWith({
    String? searchText,
    LeadStatus? status,
    LeadSource? source,
    String? assignedUserId,
    bool? isAssigned,
    int? page,
    int? pageSize,
    bool clearSearch = false,
    bool clearStatus = false,
    bool clearSource = false,
    bool clearAssignedUser = false,
    bool clearIsAssigned = false,
  }) {
    return LeadQuery(
      searchText: clearSearch ? null : (searchText ?? this.searchText),
      status: clearStatus ? null : (status ?? this.status),
      source: clearSource ? null : (source ?? this.source),
      assignedUserId: clearAssignedUser
          ? null
          : (assignedUserId ?? this.assignedUserId),
      isAssigned: clearIsAssigned ? null : (isAssigned ?? this.isAssigned),
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadQuery &&
          runtimeType == other.runtimeType &&
          searchText == other.searchText &&
          status == other.status &&
          source == other.source &&
          assignedUserId == other.assignedUserId &&
          isAssigned == other.isAssigned &&
          page == other.page &&
          pageSize == other.pageSize;

  @override
  int get hashCode => Object.hash(
    searchText,
    status,
    source,
    assignedUserId,
    isAssigned,
    page,
    pageSize,
  );

  @override
  String toString() =>
      'LeadQuery(search: $searchText, status: $status, source: $source, assignedUserId: $assignedUserId, isAssigned: $isAssigned, page: $page)';
}
