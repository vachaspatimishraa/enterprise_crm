import '../entities/employment_status.dart';

/// Input data payload for creating a new Employee record.
class CreateEmployeeInput {
  final String? employeeCode;
  final String fullName;
  final String? email;
  final String? phone;
  final String? department;
  final String? designation;
  final EmploymentStatus employmentStatus;
  final DateTime? joiningDate;
  final String? userId;

  const CreateEmployeeInput({
    this.employeeCode,
    required this.fullName,
    this.email,
    this.phone,
    this.department,
    this.designation,
    this.employmentStatus = EmploymentStatus.active,
    this.joiningDate,
    this.userId,
  });
}
