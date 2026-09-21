import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../../leads/domain/entities/lead.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import '../../data/repositories/mock_lead_call_activity_repository.dart';
import '../../domain/entities/call_outcome.dart';
import '../../domain/repositories/lead_call_activity_repository.dart';
import '../../domain/repositories/lead_follow_up_repository.dart';
import '../../domain/services/calling_workflow_service.dart';
import '../bloc/record_call_activity_cubit.dart';
import '../bloc/record_call_activity_state.dart';
import '../utils/calling_display_formatters.dart';

/// Screen allowing an authorized user to record a call outcome and optional follow-up reschedule.
class RecordCallOutcomeScreen extends StatelessWidget {
  final CurrentUser user;
  final String leadId;
  final Lead? initialLead;
  final UserLeadLinkRepository linkRepository;
  final LeadRepository leadRepository;
  final LeadCallActivityRepository callActivityRepository;
  final LeadFollowUpRepository? followUpRepository;
  final CallingWorkflowService? workflowService;
  final RecordCallActivityCubit? cubit;
  final NowProvider? now;

  const RecordCallOutcomeScreen({
    super.key,
    required this.user,
    required this.leadId,
    this.initialLead,
    required this.linkRepository,
    required this.leadRepository,
    required this.callActivityRepository,
    this.followUpRepository,
    this.workflowService,
    this.cubit,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _RecordCallOutcomeView(now: now),
      );
    }

    return BlocProvider(
      create: (_) => RecordCallActivityCubit(
        user: user,
        leadId: leadId,
        initialLead: initialLead,
        linkRepository: linkRepository,
        leadRepository: leadRepository,
        callActivityRepository: callActivityRepository,
        followUpRepository: followUpRepository,
        workflowService: workflowService,
        now: now,
      )..load(),
      child: _RecordCallOutcomeView(now: now),
    );
  }
}

class _RecordCallOutcomeView extends StatelessWidget {
  final NowProvider? now;

  const _RecordCallOutcomeView({this.now});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecordCallActivityCubit, RecordCallActivityState>(
      listener: (context, state) {
        if (state is RecordCallActivitySuccess) {
          Navigator.of(context).pop(state.activity);
        }
      },
      builder: (context, state) {
        return switch (state) {
          RecordCallActivityInitial() ||
          RecordCallActivityLoading() => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                key: Key('record_call_outcome_loading'),
              ),
            ),
          ),
          RecordCallActivityAccessDenied() => const AccessRestrictedScreen(),
          RecordCallActivitySuccess() => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          RecordCallActivityReady(:final lead) => _RecordCallOutcomeForm(
            lead: lead,
            isSubmitting: false,
            errorMessage: null,
            now: now,
          ),
          RecordCallActivitySubmitting(:final lead) => _RecordCallOutcomeForm(
            lead: lead,
            isSubmitting: true,
            errorMessage: null,
            now: now,
          ),
          RecordCallActivityFailure(:final lead, :final message) =>
            _RecordCallOutcomeForm(
              lead: lead,
              isSubmitting: false,
              errorMessage: message,
              now: now,
            ),
        };
      },
    );
  }
}

class _RecordCallOutcomeForm extends StatefulWidget {
  final Lead lead;
  final bool isSubmitting;
  final String? errorMessage;
  final NowProvider? now;

  const _RecordCallOutcomeForm({
    required this.lead,
    required this.isSubmitting,
    required this.errorMessage,
    this.now,
  });

  @override
  State<_RecordCallOutcomeForm> createState() => _RecordCallOutcomeFormState();
}

class _RecordCallOutcomeFormState extends State<_RecordCallOutcomeForm> {
  CallOutcome? _selectedOutcome;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _localValidationError;

  DateTime get _currentNow =>
      (widget.now != null) ? widget.now!() : DateTime.now();

  Future<void> _pickDate() async {
    final now = _currentNow;
    final initial = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _localValidationError = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _localValidationError = null;
      });
    }
  }

  void _clearSchedule() {
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
      _localValidationError = null;
    });
  }

  void _submit() {
    setState(() => _localValidationError = null);

    if (_selectedOutcome == null) {
      setState(() => _localValidationError = 'Please select a call outcome.');
      return;
    }

    // Atomic schedule check: neither or both
    final hasDate = _selectedDate != null;
    final hasTime = _selectedTime != null;

    if ((hasDate && !hasTime) || (!hasDate && hasTime)) {
      setState(
        () => _localValidationError =
            'Please select both date and time for reschedule, or clear the schedule.',
      );
      return;
    }

    DateTime? combinedReschedule;
    if (hasDate && hasTime) {
      combinedReschedule = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }

    context.read<RecordCallActivityCubit>().submitActivity(
      outcome: _selectedOutcome!,
      rescheduleAt: combinedReschedule,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = (widget.lead.name?.trim().isNotEmpty ?? false)
        ? widget.lead.name!
        : 'Unnamed Lead';

    final activeError = _localValidationError ?? widget.errorMessage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Call Outcome'),
        leading: IconButton(
          key: const Key('record_call_outcome_cancel_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 32 : 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isWide ? 28 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Lead Context Header
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimaryContainer,
                              child: const Icon(Icons.phone_outlined),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    key: const Key(
                                      'record_call_outcome_lead_name',
                                    ),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (widget.lead.phone != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.lead.phone!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 20),

                        // Error Banner
                        if (activeError != null) ...[
                          Container(
                            key: const Key('record_call_outcome_error_banner'),
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
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    activeError,
                                    style: TextStyle(
                                      color: colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Outcome Dropdown
                        Text(
                          'Call Outcome *',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<CallOutcome>(
                          key: const Key('record_call_outcome_dropdown'),
                          initialValue: _selectedOutcome,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Select call outcome',
                            prefixIcon: Icon(Icons.call_end_outlined),
                          ),
                          items: [
                            for (final outcome in CallOutcome.values)
                              DropdownMenuItem<CallOutcome>(
                                value: outcome,
                                child: Text(formatCallOutcome(outcome)),
                              ),
                          ],
                          onChanged: widget.isSubmitting
                              ? null
                              : (val) {
                                  setState(() {
                                    _selectedOutcome = val;
                                    _localValidationError = null;
                                  });
                                },
                        ),
                        const SizedBox(height: 24),

                        // Reschedule Section
                        Text(
                          'Reschedule / Follow-up (Optional)',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Set a specific date and time for the next follow-up.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Date and Time Pickers
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key(
                                  'record_call_outcome_date_button',
                                ),
                                icon: const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                ),
                                label: Text(
                                  _selectedDate == null
                                      ? 'Pick Date'
                                      : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                                ),
                                onPressed: widget.isSubmitting
                                    ? null
                                    : _pickDate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key(
                                  'record_call_outcome_time_button',
                                ),
                                icon: const Icon(Icons.access_time, size: 16),
                                label: Text(
                                  _selectedTime == null
                                      ? 'Pick Time'
                                      : _selectedTime!.format(context),
                                ),
                                onPressed: widget.isSubmitting
                                    ? null
                                    : _pickTime,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedDate != null || _selectedTime != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: const Key(
                                'record_call_outcome_clear_schedule',
                              ),
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Clear Schedule'),
                              onPressed: widget.isSubmitting
                                  ? null
                                  : _clearSchedule,
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),

                        // Actions: Cancel & Save
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                key: const Key('record_call_outcome_cancel'),
                                onPressed: widget.isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              FilledButton.icon(
                                key: const Key('record_call_outcome_save'),
                                onPressed: widget.isSubmitting ? null : _submit,
                                icon: widget.isSubmitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined, size: 18),
                                label: Text(
                                  widget.isSubmitting ? 'Saving...' : 'Save',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
