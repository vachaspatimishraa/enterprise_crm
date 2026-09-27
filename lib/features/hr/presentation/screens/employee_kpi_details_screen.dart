import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_kpi.dart';
import '../../domain/policies/hr_access_policy.dart';
import '../../domain/repositories/employee_kpi_repository.dart';
import '../../domain/repositories/employee_repository.dart';
import '../bloc/employee_kpi_details_cubit.dart';
import '../bloc/employee_kpi_details_state.dart';

/// Screen displaying the complete read-only details of an individual Employee KPI record.
class EmployeeKpiDetailsScreen extends StatelessWidget {
  final CurrentUser user;
  final String kpiId;
  final EmployeeKpiRepository? kpiRepository;
  final EmployeeRepository? employeeRepository;
  final EmployeeKpiDetailsCubit? cubit;

  const EmployeeKpiDetailsScreen({
    super.key,
    required this.user,
    required this.kpiId,
    this.kpiRepository,
    this.employeeRepository,
    this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    if (!HrAccessPolicy.canAccessModule(user) ||
        !HrAccessPolicy.canViewHrRecords(user)) {
      return const AccessRestrictedScreen();
    }

    final effectiveRepo =
        kpiRepository ??
        RepositoryProvider.of<EmployeeKpiRepository>(context, listen: false);

    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _EmployeeKpiDetailsView(
          user: user,
          kpiId: kpiId,
          employeeRepository: employeeRepository,
        ),
      );
    }

    return BlocProvider(
      create: (_) => EmployeeKpiDetailsCubit(repository: effectiveRepo)
        ..loadKpi(kpiId),
      child: _EmployeeKpiDetailsView(
        user: user,
        kpiId: kpiId,
        employeeRepository: employeeRepository,
      ),
    );
  }
}

class _EmployeeKpiDetailsView extends StatefulWidget {
  final CurrentUser user;
  final String kpiId;
  final EmployeeRepository? employeeRepository;

  const _EmployeeKpiDetailsView({
    required this.user,
    required this.kpiId,
    this.employeeRepository,
  });

  @override
  State<_EmployeeKpiDetailsView> createState() =>
      _EmployeeKpiDetailsViewState();
}

class _EmployeeKpiDetailsViewState extends State<_EmployeeKpiDetailsView> {
  Employee? _resolvedEmployee;
  String? _loadedEmployeeId;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _resolveEmployee(String employeeId) async {
    final empRepo = widget.employeeRepository;
    if (empRepo == null) return;

    setState(() {
      _loadedEmployeeId = employeeId;
    });

    try {
      final emp = await empRepo.getEmployeeById(employeeId);
      if (mounted) {
        setState(() {
          _resolvedEmployee = emp;
        });
      }
    } catch (_) {
      // Ignored - fallback to employeeId
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EmployeeKpiDetailsCubit, EmployeeKpiDetailsState>(
      listener: (context, state) {
        if (state.kpi != null && state.kpi!.employeeId != _loadedEmployeeId) {
          _resolveEmployee(state.kpi!.employeeId);
        }
      },
      builder: (context, state) {
        return Scaffold(
          key: const Key('employee_kpi_details_scaffold'),
          appBar: AppBar(
            key: const Key('employee_kpi_details_app_bar'),
            title: const Text('KPI Details'),
            actions: [
              IconButton(
                key: const Key('kpi_details_refresh_button'),
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    context.read<EmployeeKpiDetailsCubit>().reload(),
              ),
            ],
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, EmployeeKpiDetailsState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (state.status) {
      case EmployeeKpiDetailsStatus.initial:
      case EmployeeKpiDetailsStatus.loading:
        return const Center(
          child: CircularProgressIndicator(
            key: Key('kpi_details_loading_indicator'),
          ),
        );

      case EmployeeKpiDetailsStatus.notFound:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_outlined,
                  size: 64,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'KPI record not found.',
                  key: const Key('kpi_details_not_found'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('kpi_details_back_to_list_button'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Return to KPI List'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );

      case EmployeeKpiDetailsStatus.failure:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  state.errorMessage ?? 'Failed to load KPI details.',
                  key: const Key('kpi_details_error_message'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  key: const Key('kpi_details_retry_button'),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: () =>
                      context.read<EmployeeKpiDetailsCubit>().reload(),
                ),
              ],
            ),
          ),
        );

      case EmployeeKpiDetailsStatus.loaded:
        if (state.kpi == null) {
          return const SizedBox.shrink();
        }
        return _buildContent(context, state.kpi!, colorScheme, theme);
    }
  }

  Widget _buildContent(
    BuildContext context,
    EmployeeKpi kpi,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    if (_loadedEmployeeId != kpi.employeeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _loadedEmployeeId != kpi.employeeId) {
          _resolveEmployee(kpi.employeeId);
        }
      });
    }

    final employeeDisplayName =
        _resolvedEmployee?.fullName ?? kpi.employeeId;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card: Metric Name & Employee
              Card(
                key: const Key('kpi_details_header_card'),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                color: colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.analytics_outlined,
                              color: colorScheme.onPrimaryContainer,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  kpi.metricName,
                                  key: const Key('kpi_details_metric_name'),
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 18,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        employeeDisplayName,
                                        key: const Key('kpi_details_employee_name'),
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_resolvedEmployee?.designation != null &&
                                    _resolvedEmployee!.designation!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _resolvedEmployee!.designation!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.date_range_outlined,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Period: ${kpi.formattedPeriod}',
                            key: const Key('kpi_details_period_text'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Metrics Value Card (Target, Actual, Stored Score)
              Card(
                key: const Key('kpi_details_metrics_card'),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Performance Metrics',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 500) {
                            return Column(
                              children: [
                                _buildMetricTile(
                                  context: context,
                                  label: 'Target Value',
                                  value: '${kpi.targetValue}',
                                  valueKey: 'kpi_details_target_value',
                                  icon: Icons.track_changes_outlined,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(height: 10),
                                _buildMetricTile(
                                  context: context,
                                  label: 'Actual Value',
                                  value: '${kpi.actualValue}',
                                  valueKey: 'kpi_details_actual_value',
                                  icon: Icons.done_all_outlined,
                                  color: colorScheme.secondary,
                                ),
                                const SizedBox(height: 10),
                                _buildMetricTile(
                                  context: context,
                                  label: 'Stored Score',
                                  value: kpi.score != null ? '${kpi.score}' : 'Not recorded',
                                  valueKey: 'kpi_details_score_value',
                                  icon: Icons.grade_outlined,
                                  color: kpi.score != null
                                      ? colorScheme.tertiary
                                      : colorScheme.outline,
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: _buildMetricTile(
                                  context: context,
                                  label: 'Target Value',
                                  value: '${kpi.targetValue}',
                                  valueKey: 'kpi_details_target_value',
                                  icon: Icons.track_changes_outlined,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricTile(
                                  context: context,
                                  label: 'Actual Value',
                                  value: '${kpi.actualValue}',
                                  valueKey: 'kpi_details_actual_value',
                                  icon: Icons.done_all_outlined,
                                  color: colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricTile(
                                  context: context,
                                  label: 'Stored Score',
                                  value: kpi.score != null ? '${kpi.score}' : 'Not recorded',
                                  valueKey: 'kpi_details_score_value',
                                  icon: Icons.grade_outlined,
                                  color: kpi.score != null
                                      ? colorScheme.tertiary
                                      : colorScheme.outline,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Detailed Attributes Table Card
              Card(
                key: const Key('kpi_details_attributes_card'),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Metadata',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        context,
                        'KPI Identifier',
                        kpi.id,
                        key: 'kpi_details_id_row',
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        context,
                        'Employee Identifier',
                        kpi.employeeId,
                        key: 'kpi_details_employee_id_row',
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        context,
                        'Period Start (UTC)',
                        _formatDateIso(kpi.periodStart),
                        key: 'kpi_details_start_row',
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        context,
                        'Period End (UTC)',
                        _formatDateIso(kpi.periodEnd),
                        key: 'kpi_details_end_row',
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        context,
                        'Remarks',
                        kpi.remarks != null && kpi.remarks!.trim().isNotEmpty
                            ? kpi.remarks!
                            : 'None recorded',
                        key: 'kpi_details_remarks_row',
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        context,
                        'Created At (UTC)',
                        kpi.createdAt?.toIso8601String() ?? '—',
                        key: 'kpi_details_created_at_row',
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        context,
                        'Updated At (UTC)',
                        kpi.updatedAt?.toIso8601String() ?? '—',
                        key: 'kpi_details_updated_at_row',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required String label,
    required String value,
    required String valueKey,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            key: Key(valueKey),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    required String key,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      key: Key(key),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 400) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 150,
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDateIso(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
