import 'package:flutter/material.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employment_status.dart';
import '../../domain/inputs/update_employee_input.dart';
import '../../domain/repositories/employee_repository.dart';

/// Form screen for editing an existing Employee record in the HR module.
///
/// Restricted to Administrators only.
class EditEmployeeScreen extends StatefulWidget {
  final CurrentUser user;
  final Employee employee;
  final EmployeeRepository repository;

  const EditEmployeeScreen({
    super.key,
    required this.user,
    required this.employee,
    required this.repository,
  });

  @override
  State<EditEmployeeScreen> createState() => _EditEmployeeScreenState();
}

class _EditEmployeeScreenState extends State<EditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late final TextEditingController _codeController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _departmentController;
  late final TextEditingController _designationController;
  late final TextEditingController _userIdController;

  late EmploymentStatus _selectedStatus;
  DateTime? _selectedJoiningDate;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    _fullNameController = TextEditingController(text: emp.fullName);
    _codeController = TextEditingController(text: emp.employeeCode ?? '');
    _emailController = TextEditingController(text: emp.email ?? '');
    _phoneController = TextEditingController(text: emp.phone ?? '');
    _departmentController = TextEditingController(text: emp.department ?? '');
    _designationController = TextEditingController(text: emp.designation ?? '');
    _userIdController = TextEditingController(text: emp.userId ?? '');
    _selectedStatus = emp.employmentStatus;
    _selectedJoiningDate = emp.joiningDate;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _designationController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.isAdmin) {
      return const AccessRestrictedScreen();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('edit_employee_scaffold'),
      appBar: AppBar(title: const Text('Edit Employee')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Update Employee Details',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Modify personal or position attributes for this employee record.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_errorMessage != null) ...[
                        Container(
                          key: const Key('edit_employee_error_banner'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Full Name
                      TextFormField(
                        key: const Key('edit_employee_name_field'),
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter employee full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Employee Code
                      TextFormField(
                        key: const Key('edit_employee_code_field'),
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Employee Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Department & Designation
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('edit_employee_dept_field'),
                              controller: _departmentController,
                              decoration: const InputDecoration(
                                labelText: 'Department',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              key: const Key('edit_employee_designation_field'),
                              controller: _designationController,
                              decoration: const InputDecoration(
                                labelText: 'Designation',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Employment Status Dropdown
                      DropdownButtonFormField<EmploymentStatus>(
                        key: const Key('edit_employee_status_dropdown'),
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Employment Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: EmploymentStatus.active,
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: EmploymentStatus.probation,
                            child: Text('Probation'),
                          ),
                          DropdownMenuItem(
                            value: EmploymentStatus.inactive,
                            child: Text('Inactive'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatus = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Joining Date
                      ListTile(
                        key: const Key('edit_employee_date_tile'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Joining Date'),
                        subtitle: Text(
                          _selectedJoiningDate != null
                              ? '${_selectedJoiningDate!.year}-${_selectedJoiningDate!.month.toString().padLeft(2, '0')}-${_selectedJoiningDate!.day.toString().padLeft(2, '0')}'
                              : 'Not set',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today_outlined),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  _selectedJoiningDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _selectedJoiningDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email & Phone
                      TextFormField(
                        key: const Key('edit_employee_email_field'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final trimmed = value?.trim();
                          if (trimmed != null &&
                              trimmed.isNotEmpty &&
                              !trimmed.contains('@')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        key: const Key('edit_employee_phone_field'),
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Optional Link to CRM Account
                      TextFormField(
                        key: const Key('edit_employee_user_id_field'),
                        controller: _userIdController,
                        decoration: const InputDecoration(
                          labelText: 'Link CRM User ID (Optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Save Changes Button
                      ElevatedButton(
                        key: const Key('edit_employee_submit_button'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isSubmitting ? null : _submitForm,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final input = UpdateEmployeeInput(
        id: widget.employee.id,
        fullName: _fullNameController.text.trim(),
        employeeCode: _codeController.text.trim().isNotEmpty
            ? _codeController.text.trim()
            : null,
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        department: _departmentController.text.trim().isNotEmpty
            ? _departmentController.text.trim()
            : null,
        designation: _designationController.text.trim().isNotEmpty
            ? _designationController.text.trim()
            : null,
        employmentStatus: _selectedStatus,
        joiningDate: _selectedJoiningDate,
        userId: _userIdController.text.trim().isNotEmpty
            ? _userIdController.text.trim()
            : null,
        clearUserId:
            _userIdController.text.trim().isEmpty &&
            widget.employee.userId != null,
      );

      await widget.repository.updateEmployee(input);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on EmployeeException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isSubmitting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred while updating employee.';
          _isSubmitting = false;
        });
      }
    }
  }
}
