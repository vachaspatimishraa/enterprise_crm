import 'employment_status.dart';

/// Immutable domain entity representing an Employee in the Enterprise CRM HR module.
///
/// Plaintext credentials, passwords, bank details, and sensitive payroll calculations
/// must NEVER be held in this model.
class Employee {
  final String id;
  final String? employeeCode;
  final String fullName;
  final String? email;
  final String? phone;
  final String? department;
  final String? designation;
  final EmploymentStatus employmentStatus;
  final DateTime? joiningDate;
  final String? userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Employee({
    required this.id,
    this.employeeCode,
    required this.fullName,
    this.email,
    this.phone,
    this.department,
    this.designation,
    this.employmentStatus = EmploymentStatus.active,
    this.joiningDate,
    this.userId,
    this.createdAt,
    this.updatedAt,
  });

  /// Whether this employee record is currently active.
  bool get isActive => employmentStatus == EmploymentStatus.active;

  /// Whether this employee is linked to a CRM login user account.
  bool get hasLinkedUser => userId != null && userId!.trim().isNotEmpty;

  /// Creates a copy of this employee with updated fields.
  Employee copyWith({
    String? id,
    String? employeeCode,
    String? fullName,
    String? email,
    String? phone,
    String? department,
    String? designation,
    EmploymentStatus? employmentStatus,
    DateTime? joiningDate,
    String? userId,
    bool clearUserId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Employee(
      id: id ?? this.id,
      employeeCode: employeeCode ?? this.employeeCode,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      joiningDate: joiningDate ?? this.joiningDate,
      userId: clearUserId ? null : (userId ?? this.userId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Employee &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          employeeCode == other.employeeCode &&
          fullName == other.fullName &&
          email == other.email &&
          phone == other.phone &&
          department == other.department &&
          designation == other.designation &&
          employmentStatus == other.employmentStatus &&
          joiningDate == other.joiningDate &&
          userId == other.userId;

  @override
  int get hashCode => Object.hash(
    id,
    employeeCode,
    fullName,
    email,
    phone,
    department,
    designation,
    employmentStatus,
    joiningDate,
    userId,
  );

  @override
  String toString() =>
      'Employee(id: $id, code: $employeeCode, name: $fullName, dept: $department, status: $employmentStatus)';
}
