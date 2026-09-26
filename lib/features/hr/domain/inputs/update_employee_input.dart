import '../entities/employment_status.dart';

/// Input data payload for updating an existing Employee record.
class UpdateEmployeeInput {
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
  final bool clearUserId;

  const UpdateEmployeeInput({
    required this.id,
    this.employeeCode,
    required this.fullName,
    this.email,
    this.phone,
    this.department,
    this.designation,
    required this.employmentStatus,
    this.joiningDate,
    this.userId,
    this.clearUserId = false,
  });
}
