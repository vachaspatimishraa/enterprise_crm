/// Value object representing an employee's current employment status.
///
/// Follows the project's string value-object convention (analogous to [LeadStatus])
/// to remain flexible for backend-defined status vocabularies without guessing enums.
class EmploymentStatus {
  final String value;

  const EmploymentStatus(this.value);

  // Common standardized statuses for UI helpers & mock fixtures
  static const EmploymentStatus active = EmploymentStatus('Active');
  static const EmploymentStatus probation = EmploymentStatus('Probation');
  static const EmploymentStatus inactive = EmploymentStatus('Inactive');

  factory EmploymentStatus.fromString(String value) =>
      EmploymentStatus(value.trim());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmploymentStatus &&
          runtimeType == other.runtimeType &&
          value.toLowerCase() == other.value.toLowerCase();

  @override
  int get hashCode => value.toLowerCase().hashCode;

  @override
  String toString() => value;
}
