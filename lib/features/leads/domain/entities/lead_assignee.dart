class LeadAssignee {
  const LeadAssignee({required this.id, required this.displayName});

  final String id;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadAssignee &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName;

  @override
  int get hashCode => Object.hash(id, displayName);
}
