import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../data/repositories/mock_employee_repository.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_kpi_repository.dart';
import '../../domain/repositories/employee_repository.dart';
import '../bloc/employee_kpi_form_cubit.dart';
import '../bloc/employee_kpi_form_state.dart';

/// Screen allowing authorized Administrators to record a new Employee KPI.
class AddEmployeeKpiScreen extends StatelessWidget {
  final CurrentUser user;
  final EmployeeKpiRepository? kpiRepository;
  final EmployeeRepository? employeeRepository;
  final EmployeeKpiFormCubit? formCubit;
  final String? preselectedEmployeeId;

  const AddEmployeeKpiScreen({
    super.key,
    required this.user,
    this.kpiRepository,
    this.employeeRepository,
    this.formCubit,
    this.preselectedEmployeeId,
  });

  @override
  Widget build(BuildContext context) {
    if (!user.isAdmin) {
      return const AccessRestrictedScreen();
    }

    final effectiveKpiRepo =
        kpiRepository ??
        RepositoryProvider.of<EmployeeKpiRepository>(context, listen: false);

    if (formCubit != null) {
      return BlocProvider.value(
        value: formCubit!,
        child: _AddEmployeeKpiView(
          user: user,
          employeeRepository: employeeRepository ?? MockEmployeeRepository(),
          preselectedEmployeeId: preselectedEmployeeId,
        ),
      );
    }

    return BlocProvider(
      create: (_) => EmployeeKpiFormCubit(repository: effectiveKpiRepo),
      child: _AddEmployeeKpiView(
        user: user,
        employeeRepository: employeeRepository ?? MockEmployeeRepository(),
        preselectedEmployeeId: preselectedEmployeeId,
      ),
    );
  }
}

class _AddEmployeeKpiView extends StatefulWidget {
  final CurrentUser user;
  final EmployeeRepository employeeRepository;
  final String? preselectedEmployeeId;

  const _AddEmployeeKpiView({
    required this.user,
    required this.employeeRepository,
    this.preselectedEmployeeId,
  });

  @override
  State<_AddEmployeeKpiView> createState() => _AddEmployeeKpiViewState();
}

class _AddEmployeeKpiViewState extends State<_AddEmployeeKpiView> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedEmployeeId;
  final _metricNameController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _actualValueController = TextEditingController();
  final _scoreController = TextEditingController();
  final _remarksController = TextEditingController();

  DateTime _startDate = DateTime.utc(2026, 7, 1);
  DateTime _endDate = DateTime.utc(2026, 9, 30);

  List<Employee> _employees = [];
  bool _isLoadingEmployees = true;

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.preselectedEmployeeId;
    _loadEmployees();
  }

  @override
  void dispose() {
    _metricNameController.dispose();
    _targetValueController.dispose();
    _actualValueController.dispose();
    _scoreController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final list = await widget.employeeRepository.getEmployees();
      if (!mounted) return;
      setState(() {
        _employees = list;
        _isLoadingEmployees = false;
        if (_selectedEmployeeId == null && list.isNotEmpty) {
          _selectedEmployeeId = list.first.id;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingEmployees = false);
      }
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = DateTime.utc(picked.year, picked.month, picked.day);
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = DateTime.utc(picked.year, picked.month, picked.day);
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) return;

    final target = double.parse(_targetValueController.text.trim());
    final actual = double.parse(_actualValueController.text.trim());
    final scoreText = _scoreController.text.trim();
    final score = scoreText.isNotEmpty ? double.tryParse(scoreText) : null;
    final remarksText = _remarksController.text.trim();
    final remarks = remarksText.isNotEmpty ? remarksText : null;

    context.read<EmployeeKpiFormCubit>().submitCreate(
      employeeId: _selectedEmployeeId!,
      metricName: _metricNameController.text.trim(),
      periodStart: _startDate,
      periodEnd: _endDate,
      targetValue: target,
      actualValue: actual,
      score: score,
      remarks: remarks,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocConsumer<EmployeeKpiFormCubit, EmployeeKpiFormState>(
      listener: (context, state) {
        if (state.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              key: Key('add_kpi_success_snackbar'),
              content: Text('KPI record created successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state.isFailure && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              key: const Key('add_kpi_error_snackbar'),
              content: Text(state.errorMessage!),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          key: const Key('add_employee_kpi_scaffold'),
          appBar: AppBar(title: const Text('Add Employee KPI')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'New KPI Record',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter metric targets, actual results, and approved measurement period.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (state.isFailure &&
                              state.errorMessage != null) ...[
                            Container(
                              key: const Key('add_kpi_error_banner'),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                state.errorMessage!,
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Employee Dropdown
                          _isLoadingEmployees
                              ? const LinearProgressIndicator()
                              : DropdownButtonFormField<String>(
                                  key: const Key('add_kpi_employee_dropdown'),
                                  initialValue: _selectedEmployeeId,
                                  decoration: const InputDecoration(
                                    labelText: 'Employee *',
                                    prefixIcon: Icon(Icons.person_outline),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _employees.map((e) {
                                    return DropdownMenuItem(
                                      value: e.id,
                                      child: Text('${e.fullName} (${e.id})'),
                                    );
                                  }).toList(),
                                  validator: (val) => val == null || val.isEmpty
                                      ? 'Please select an employee'
                                      : null,
                                  onChanged: state.isSubmitting
                                      ? null
                                      : (val) => setState(
                                          () => _selectedEmployeeId = val,
                                        ),
                                ),
                          const SizedBox(height: 16),

                          // Metric Name Field
                          TextFormField(
                            key: const Key('add_kpi_metric_field'),
                            controller: _metricNameController,
                            enabled: !state.isSubmitting,
                            decoration: const InputDecoration(
                              labelText: 'Metric Name *',
                              hintText: 'e.g. Employee Retention Rate',
                              prefixIcon: Icon(Icons.analytics_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Metric name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Measurement Period Pickers
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  key: const Key('add_kpi_start_date_picker'),
                                  onTap: state.isSubmitting
                                      ? null
                                      : _selectStartDate,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Period Start *',
                                      prefixIcon: Icon(
                                        Icons.calendar_today_outlined,
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(
                                      '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  key: const Key('add_kpi_end_date_picker'),
                                  onTap: state.isSubmitting
                                      ? null
                                      : _selectEndDate,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Period End *',
                                      prefixIcon: Icon(
                                        Icons.calendar_today_outlined,
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(
                                      '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Target & Actual Values
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  key: const Key('add_kpi_target_field'),
                                  controller: _targetValueController,
                                  enabled: !state.isSubmitting,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Target Value *',
                                    hintText: 'e.g. 90.0',
                                    prefixIcon: Icon(
                                      Icons.track_changes_outlined,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Target value is required';
                                    }
                                    if (double.tryParse(val.trim()) == null) {
                                      return 'Enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  key: const Key('add_kpi_actual_field'),
                                  controller: _actualValueController,
                                  enabled: !state.isSubmitting,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Actual Value *',
                                    hintText: 'e.g. 92.5',
                                    prefixIcon: Icon(Icons.done_all_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Actual value is required';
                                    }
                                    if (double.tryParse(val.trim()) == null) {
                                      return 'Enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Score (Optional)
                          TextFormField(
                            key: const Key('add_kpi_score_field'),
                            controller: _scoreController,
                            enabled: !state.isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Recorded Score (Optional)',
                              hintText:
                                  'e.g. 95.0 (leave blank if not yet evaluated)',
                              prefixIcon: Icon(Icons.grade_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val != null && val.trim().isNotEmpty) {
                                if (double.tryParse(val.trim()) == null) {
                                  return 'Enter a valid number';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Remarks (Optional)
                          TextFormField(
                            key: const Key('add_kpi_remarks_field'),
                            controller: _remarksController,
                            enabled: !state.isSubmitting,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Remarks (Optional)',
                              hintText: 'Additional context or notes...',
                              prefixIcon: Icon(Icons.notes_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Actions Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                key: const Key('add_kpi_cancel_button'),
                                onPressed: state.isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                key: const Key('add_kpi_submit_button'),
                                onPressed: state.isSubmitting ? null : _submit,
                                child: state.isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Save KPI Record'),
                              ),
                            ],
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
      },
    );
  }
}
