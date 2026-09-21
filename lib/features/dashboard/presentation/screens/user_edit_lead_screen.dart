import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../../leads/domain/entities/lead.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import '../../../leads/presentation/utils/lead_display_formatters.dart';
import '../../../leads/presentation/utils/lead_field_validators.dart';
import '../bloc/user_lead_edit_cubit.dart';
import '../bloc/user_lead_edit_state.dart';

/// User-safe Edit Lead screen.
///
/// Restricted strictly to permitted fields (`name`, `phone`, `email`).
/// Status, source, and assignment fields are immutable context displays.
class UserEditLeadScreen extends StatelessWidget {
  final CurrentUser user;
  final String leadId;
  final Lead? initialLead;
  final UserLeadLinkRepository linkRepository;
  final LeadRepository leadRepository;
  final UserLeadEditCubit? cubit;

  const UserEditLeadScreen({
    super.key,
    required this.user,
    required this.leadId,
    this.initialLead,
    required this.linkRepository,
    required this.leadRepository,
    this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: const _UserEditLeadView(),
      );
    }

    return BlocProvider(
      create: (_) => UserLeadEditCubit(
        user: user,
        linkRepository: linkRepository,
        leadRepository: leadRepository,
        leadId: leadId,
        initialLead: initialLead,
      )..load(),
      child: const _UserEditLeadView(),
    );
  }
}

class _UserEditLeadView extends StatelessWidget {
  const _UserEditLeadView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserLeadEditCubit, UserLeadEditState>(
      listener: (context, state) {
        if (state is UserLeadEditSuccess) {
          Navigator.of(context).pop(state.updatedLead);
        }
      },
      builder: (context, state) {
        return switch (state) {
          UserLeadEditInitial() || UserLeadEditLoading() => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                key: Key('user_edit_lead_loading'),
              ),
            ),
          ),
          UserLeadEditAccessDenied() => const AccessRestrictedScreen(),
          UserLeadEditSuccess() => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          UserLeadEditReady(:final lead) => _UserEditLeadForm(
            lead: lead,
            isSubmitting: false,
            errorMessage: null,
          ),
          UserLeadEditSubmitting(:final lead) => _UserEditLeadForm(
            lead: lead,
            isSubmitting: true,
            errorMessage: null,
          ),
          UserLeadEditFailure(:final lead, :final message) => _UserEditLeadForm(
            lead: lead,
            isSubmitting: false,
            errorMessage: message,
          ),
        };
      },
    );
  }
}

class _UserEditLeadForm extends StatefulWidget {
  final Lead lead;
  final bool isSubmitting;
  final String? errorMessage;

  const _UserEditLeadForm({
    required this.lead,
    required this.isSubmitting,
    required this.errorMessage,
  });

  @override
  State<_UserEditLeadForm> createState() => _UserEditLeadFormState();
}

class _UserEditLeadFormState extends State<_UserEditLeadForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.lead.name ?? '');
    _phoneController = TextEditingController(text: widget.lead.phone ?? '');
    _emailController = TextEditingController(text: widget.lead.email ?? '');

    _nameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    final changed =
        _nameController.text.trim() != (widget.lead.name ?? '').trim() ||
        _phoneController.text.trim() != (widget.lead.phone ?? '').trim() ||
        _emailController.text.trim() != (widget.lead.email ?? '').trim();

    if (changed != _isDirty) {
      setState(() => _isDirty = changed);
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _phoneController.removeListener(_onFieldChanged);
    _emailController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<UserLeadEditCubit>().submitUpdate(
        name: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Lead'),
        leading: IconButton(
          key: const Key('user_edit_lead_cancel_button'),
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
                constraints: const BoxConstraints(maxWidth: 680),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isWide ? 28 : 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: colorScheme.primaryContainer,
                                foregroundColor: colorScheme.onPrimaryContainer,
                                child: const Icon(Icons.edit_outlined),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Edit Contact Information',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ID: ${widget.lead.id}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontFamily: 'monospace',
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Read-only context chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                avatar: const Icon(
                                  Icons.flag_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  'Status: ${formatLeadStatus(widget.lead.status)}',
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              Chip(
                                avatar: const Icon(
                                  Icons.person_outline,
                                  size: 16,
                                ),
                                label: Text(
                                  'Assigned: ${formatLeadAssignee(widget.lead)}',
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              Chip(
                                avatar: const Icon(
                                  Icons.source_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  'Source: ${formatLeadSource(widget.lead.source)}',
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 20),

                          // Error banner
                          if (widget.errorMessage != null) ...[
                            Container(
                              key: const Key('user_edit_lead_error_banner'),
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
                                      widget.errorMessage!,
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

                          // Name field
                          TextFormField(
                            key: const Key('user_edit_lead_name'),
                            controller: _nameController,
                            enabled: !widget.isSubmitting,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Lead Name',
                              hintText: 'e.g. John Doe',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Phone field
                          TextFormField(
                            key: const Key('user_edit_lead_phone'),
                            controller: _phoneController,
                            enabled: !widget.isSubmitting,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              hintText: 'e.g. +91 9876543210',
                              prefixIcon: Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Email field
                          TextFormField(
                            key: const Key('user_edit_lead_email'),
                            controller: _emailController,
                            enabled: !widget.isSubmitting,
                            textInputAction: TextInputAction.done,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (!isValidOptionalLeadEmail(value)) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'e.g. user@example.com',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                key: const Key('user_edit_lead_cancel'),
                                onPressed: widget.isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                key: const Key('user_edit_lead_save'),
                                onPressed: (widget.isSubmitting || !_isDirty)
                                    ? null
                                    : _submit,
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
                        ],
                      ),
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
