import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../data/repositories/mock_attendance_repository.dart';
import '../../data/repositories/mock_employee_document_repository.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employment_status.dart';
import '../../domain/policies/hr_access_policy.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../domain/repositories/employee_document_repository.dart';
import '../../domain/repositories/employee_repository.dart';
import '../bloc/employee_details_cubit.dart';
import '../bloc/employee_details_state.dart';
import 'edit_employee_screen.dart';
import 'employee_attendance_history_screen.dart';
import 'employee_documents_screen.dart';

/// Employee Details screen displaying full information for a selected employee record.
class EmployeeDetailsScreen extends StatelessWidget {
  final CurrentUser user;
  final String employeeId;
  final EmployeeRepository repository;
  final EmployeeDocumentRepository? documentRepository;
  final AttendanceRepository? attendanceRepository;

  const EmployeeDetailsScreen({
    super.key,
    required this.user,
    required this.employeeId,
    required this.repository,
    this.documentRepository,
    this.attendanceRepository,
  });

  @override
  Widget build(BuildContext context) {
    if (!HrAccessPolicy.canAccessModule(user)) {
      return const AccessRestrictedScreen();
    }

    if (!user.isAdmin && !HrAccessPolicy.canViewHrRecords(user)) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider(
      create: (_) =>
          EmployeeDetailsCubit(repository: repository)
            ..loadEmployee(employeeId),
      child: _EmployeeDetailsView(
        user: user,
        employeeId: employeeId,
        repository: repository,
        documentRepository: documentRepository,
        attendanceRepository: attendanceRepository,
      ),
    );
  }
}

class _EmployeeDetailsView extends StatefulWidget {
  final CurrentUser user;
  final String employeeId;
  final EmployeeRepository repository;
  final EmployeeDocumentRepository? documentRepository;
  final AttendanceRepository? attendanceRepository;

  const _EmployeeDetailsView({
    required this.user,
    required this.employeeId,
    required this.repository,
    this.documentRepository,
    this.attendanceRepository,
  });

  @override
  State<_EmployeeDetailsView> createState() => _EmployeeDetailsViewState();
}

class _EmployeeDetailsViewState extends State<_EmployeeDetailsView> {
  bool _didMutate = false;

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.user.isAdmin;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).pop(_didMutate);
        }
      },
      child: Scaffold(
        key: const Key('employee_details_scaffold'),
        appBar: AppBar(
          title: const Text('Employee Details'),
          leading: BackButton(
            key: const Key('employee_details_back_button'),
            onPressed: () => Navigator.of(context).pop(_didMutate),
          ),
          actions: [
            BlocBuilder<EmployeeDetailsCubit, EmployeeDetailsState>(
              builder: (context, state) {
                if (state.isLoaded && canEdit && state.employee != null) {
                  return TextButton.icon(
                    key: const Key('employee_details_edit_button'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                    onPressed: () async {
                      final updated = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => EditEmployeeScreen(
                            user: widget.user,
                            employee: state.employee!,
                            repository: widget.repository,
                          ),
                        ),
                      );
                      if (updated == true && context.mounted) {
                        _didMutate = true;
                        context.read<EmployeeDetailsCubit>().reload();
                      }
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: BlocBuilder<EmployeeDetailsCubit, EmployeeDetailsState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  key: Key('employee_details_loading_indicator'),
                ),
              );
            }

            if (state.isFailure) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.redAccent,
                        key: Key('employee_details_error_icon'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.errorMessage ?? 'Failed to load employee record.',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        key: const Key('employee_details_retry_button'),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        onPressed: () =>
                            context.read<EmployeeDetailsCubit>().reload(),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state.isNotFound) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_off_outlined,
                        size: 48,
                        color: Colors.grey,
                        key: Key('employee_details_not_found_icon'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Employee Not Found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Record with ID "${state.searchedId ?? widget.employeeId}" does not exist.',
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state.isLoaded && state.employee != null) {
              return _buildContent(context, state.employee!);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Employee employee) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      key: const Key('employee_details_content_scroll'),
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          employee.fullName.isNotEmpty
                              ? employee.fullName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employee.fullName,
                              key: const Key('employee_details_name_text'),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              employee.employeeCode ?? 'No Code Assigned',
                              key: const Key('employee_details_code_text'),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _StatusBadge(status: employee.employmentStatus),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Position & Organization Info
              _buildSectionCard(
                context,
                title: 'Organization & Role',
                icon: Icons.work_outline,
                children: [
                  _buildDetailRow('Department', employee.department ?? '—'),
                  _buildDetailRow('Designation', employee.designation ?? '—'),
                  _buildDetailRow(
                    'Joining Date',
                    employee.joiningDate != null
                        ? '${employee.joiningDate!.year}-${employee.joiningDate!.month.toString().padLeft(2, '0')}-${employee.joiningDate!.day.toString().padLeft(2, '0')}'
                        : '—',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Contact Information
              _buildSectionCard(
                context,
                title: 'Contact Information',
                icon: Icons.contact_mail_outlined,
                children: [
                  _buildDetailRow('Email', employee.email ?? '—'),
                  _buildDetailRow('Phone', employee.phone ?? '—'),
                ],
              ),
              const SizedBox(height: 16),

              // System Linkage
              _buildSectionCard(
                context,
                title: 'CRM System Account',
                icon: Icons.account_circle_outlined,
                children: [
                  _buildDetailRow(
                    'Linked User ID',
                    employee.userId ?? 'Not linked to any CRM account',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Employee Documents Card
              Card(
                key: const Key('employee_details_documents_card'),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: ListTile(
                  key: const Key('employee_documents_tile'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.folder_shared_outlined,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: const Text(
                    'Employee Documents',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'View agreements, KYC, identity, and certificates',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EmployeeDocumentsScreen(
                          user: widget.user,
                          employee: employee,
                          repository:
                              widget.documentRepository ??
                              MockEmployeeDocumentRepository(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Attendance History Card
              Card(
                key: const Key('employee_details_attendance_card'),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: ListTile(
                  key: const Key('employee_attendance_tile'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.calendar_month_outlined,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: const Text(
                    'Attendance History',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'View recorded attendance logs and status history',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EmployeeAttendanceHistoryScreen(
                          user: widget.user,
                          employee: employee,
                          repository:
                              widget.attendanceRepository ??
                              MockAttendanceRepository(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final EmploymentStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status.value.toLowerCase()) {
      'active' => Colors.green,
      'probation' => Colors.orange,
      'inactive' => Colors.grey,
      _ => Colors.blueGrey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.value,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
