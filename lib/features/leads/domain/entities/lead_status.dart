class LeadStatus {
  final String value;

  const LeadStatus(this.value);

  factory LeadStatus.fromString(String value) => LeadStatus(value.trim());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadStatus &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
