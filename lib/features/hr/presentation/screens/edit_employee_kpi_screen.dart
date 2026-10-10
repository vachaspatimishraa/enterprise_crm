import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../data/repositories/mock_employee_repository.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_kpi.dart';
import '../../domain/repositories/employee_kpi_repository.dart';
import '../../domain/repositories/employee_repository.dart';
import '../bloc/employee_kpi_form_cubit.dart';
import '../bloc/employee_kpi_form_state.dart';

/// Screen allowing authorized Administrators to edit an existing Employee KPI record.
class EditEmployeeKpiScreen extends StatelessWidget {
  final CurrentUser user;
  final EmployeeKpi kpi;
  final EmployeeKpiRepository? kpiRepository;
  final EmployeeRepository? employeeRepository;
  final EmployeeKpiFormCubit? formCubit;

  const EditEmployeeKpiScreen({
    super.key,
    required this.user,
    required this.kpi,
    this.kpiRepository,
    this.employeeRepository,
    this.formCubit,
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
        child: _EditEmployeeKpiView(
          user: user,
          kpi: kpi,
          employeeRepository: employeeRepository ?? MockEmployeeRepository(),
        ),
      );
    }

    return BlocProvider(
      create: (_) => EmployeeKpiFormCubit(repository: effectiveKpiRepo),
      child: _EditEmployeeKpiView(
        user: user,
        kpi: kpi,
        employeeRepository: employeeRepository ?? MockEmployeeRepository(),
      ),
    );
  }
}

class _EditEmployeeKpiView extends StatefulWidget {
  final CurrentUser user;
  final EmployeeKpi kpi;
  final EmployeeRepository employeeRepository;

  const _EditEmployeeKpiView({
    required this.user,
    required this.kpi,
    required this.employeeRepository,
  });

  @override
  State<_EditEmployeeKpiView> createState() => _EditEmployeeKpiViewState();
}

class _EditEmployeeKpiViewState extends State<_EditEmployeeKpiView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _metricNameController;
  late final TextEditingController _targetValueController;
  late final TextEditingController _actualValueController;
  late final TextEditingController _scoreController;
  late final TextEditingController _remarksController;

  late DateTime _startDate;
  late DateTime _endDate;

  Employee? _resolvedEmployee;
  bool _isLoadingEmployee = true;

  @override
  void initState() {
    super.initState();
    _metricNameController = TextEditingController(text: widget.kpi.metricName);
    _targetValueController = TextEditingController(
      text: '${widget.kpi.targetValue}',
    );
    _actualValueController = TextEditingController(
      text: '${widget.kpi.actualValue}',
    );
    _scoreController = TextEditingController(
      text: widget.kpi.score != null ? '${widget.kpi.score}' : '',
    );
    _remarksController = TextEditingController(text: widget.kpi.remarks ?? '');

    _startDate = widget.kpi.periodStart;
    _endDate = widget.kpi.periodEnd;

    _resolveEmployee();
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

  Future<void> _resolveEmployee() async {
    try {
      final emp = await widget.employeeRepository.getEmployeeById(
        widget.kpi.employeeId,
      );
      if (mounted) {
        setState(() {
          _resolvedEmployee = emp;
          _isLoadingEmployee = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingEmployee = false);
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

    final target = double.parse(_targetValueController.text.trim());
    final actual = double.parse(_actualValueController.text.trim());
    final scoreText = _scoreController.text.trim();
    final score = scoreText.isNotEmpty ? double.tryParse(scoreText) : null;
    final clearScore = scoreText.isEmpty;

    final remarksText = _remarksController.text.trim();
    final remarks = remarksText.isNotEmpty ? remarksText : null;
    final clearRemarks = remarksText.isEmpty;

    context.read<EmployeeKpiFormCubit>().submitUpdate(
      id: widget.kpi.id,
      metricName: _metricNameController.text.trim(),
      periodStart: _startDate,
      periodEnd: _endDate,
      targetValue: target,
      actualValue: actual,
      score: score,
      clearScore: clearScore,
      remarks: remarks,
      clearRemarks: clearRemarks,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final empDisplayName = _resolvedEmployee?.fullName ?? widget.kpi.employeeId;

    return BlocConsumer<EmployeeKpiFormCubit, EmployeeKpiFormState>(
      listener: (context, state) {
        if (state.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              key: Key('edit_kpi_success_snackbar'),
              content: Text('KPI record updated successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state.isFailure && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              key: const Key('edit_kpi_error_snackbar'),
              content: Text(state.errorMessage!),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          key: const Key('edit_employee_kpi_scaffold'),
          appBar: AppBar(title: const Text('Edit Employee KPI')),
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
                            'Edit KPI Record',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Modify metric targets, actual results, and approved measurement period.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (state.isFailure &&
                              state.errorMessage != null) ...[
                            Container(
                              key: const Key('edit_kpi_error_banner'),
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

                          // Read-Only Immutable Metadata Card (Employee & KPI ID)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      size: 16,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Immutable Record Association',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Employee',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _isLoadingEmployee
                                                ? 'Loading...'
                                                : empDisplayName,
                                            key: const Key(
                                              'edit_kpi_employee_text',
                                            ),
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'KPI Identifier',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            widget.kpi.id,
                                            key: const Key('edit_kpi_id_text'),
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Metric Name Field
                          TextFormField(
                            key: const Key('edit_kpi_metric_field'),
                            controller: _metricNameController,
                            enabled: !state.isSubmitting,
                            decoration: const InputDecoration(
                              labelText: 'Metric Name *',
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
                                  key: const Key('edit_kpi_start_date_picker'),
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
                                  key: const Key('edit_kpi_end_date_picker'),
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
                                  key: const Key('edit_kpi_target_field'),
                                  controller: _targetValueController,
                                  enabled: !state.isSubmitting,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Target Value *',
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
                                  key: const Key('edit_kpi_actual_field'),
                                  controller: _actualValueController,
                                  enabled: !state.isSubmitting,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Actual Value *',
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
                            key: const Key('edit_kpi_score_field'),
                            controller: _scoreController,
                            enabled: !state.isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Recorded Score (Optional)',
                              hintText: 'Leave empty to clear score',
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
                            key: const Key('edit_kpi_remarks_field'),
                            controller: _remarksController,
                            enabled: !state.isSubmitting,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Remarks (Optional)',
                              hintText: 'Leave empty to clear remarks',
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
                                key: const Key('edit_kpi_cancel_button'),
                                onPressed: state.isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                key: const Key('edit_kpi_submit_button'),
                                onPressed: state.isSubmitting ? null : _submit,
                                child: state.isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Update KPI Record'),
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
