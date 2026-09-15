enum LeadSortField { name, createdAt }

enum LeadSortDirection { ascending, descending }

class LeadSort {
  final LeadSortField field;
  final LeadSortDirection direction;

  const LeadSort({required this.field, required this.direction});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadSort &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          direction == other.direction;

  @override
  int get hashCode => Object.hash(field, direction);

  @override
  String toString() => 'LeadSort($field, $direction)';
}
