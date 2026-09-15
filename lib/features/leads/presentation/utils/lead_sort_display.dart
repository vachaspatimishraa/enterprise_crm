import '../../domain/entities/lead_sort.dart';

String leadSortToDisplayName(LeadSort? sort) {
  if (sort == null) return 'Default';
  switch (sort.field) {
    case LeadSortField.name:
      return sort.direction == LeadSortDirection.ascending
          ? 'Name A–Z'
          : 'Name Z–A';
    case LeadSortField.createdAt:
      return sort.direction == LeadSortDirection.descending
          ? 'Newest Created'
          : 'Oldest Created';
  }
}

const List<LeadSort?> leadSortOptions = [
  null,
  LeadSort(field: LeadSortField.name, direction: LeadSortDirection.ascending),
  LeadSort(field: LeadSortField.name, direction: LeadSortDirection.descending),
  LeadSort(
    field: LeadSortField.createdAt,
    direction: LeadSortDirection.descending,
  ),
  LeadSort(
    field: LeadSortField.createdAt,
    direction: LeadSortDirection.ascending,
  ),
];
