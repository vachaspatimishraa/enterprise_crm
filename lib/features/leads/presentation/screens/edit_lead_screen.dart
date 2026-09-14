import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_draft.dart';
import '../../domain/repositories/lead_repository.dart';
import '../bloc/lead_form_cubit.dart';
import '../bloc/lead_form_state.dart';
import '../utils/lead_display_formatters.dart';

class EditLeadScreen extends StatelessWidget {
  final Lead lead;
  final LeadFormCubit? cubit;
  final LeadRepository? repository;
  final void Function(Lead lead)? onLeadUpdated;
  final VoidCallback? onCancel;

  const EditLeadScreen({
    super.key,
    required this.lead,
    this.cubit,
    this.repository,
    this.onLeadUpdated,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _EditLeadView(
          lead: lead,
          onLeadUpdated: onLeadUpdated,
          onCancel: onCancel,
        ),
      );
    }

    if (repository != null) {
      return BlocProvider(
        create: (_) => LeadFormCubit(repository!),
        child: _EditLeadView(
          lead: lead,
          onLeadUpdated: onLeadUpdated,
          onCancel: onCancel,
        ),
      );
    }

    return _EditLeadView(
      lead: lead,
      onLeadUpdated: onLeadUpdated,
      onCancel: onCancel,
    );
  }
}

class _EditLeadView extends StatefulWidget {
  final Lead lead;
  final void Function(Lead lead)? onLeadUpdated;
  final VoidCallback? onCancel;

  const _EditLeadView({required this.lead, this.onLeadUpdated, this.onCancel});

  @override
  State<_EditLeadView> createState() => _EditLeadViewState();
}

class _EditLeadViewState extends State<_EditLeadView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.lead.name ?? '');
    _phoneController = TextEditingController(text: widget.lead.phone ?? '');
    _emailController = TextEditingController(text: widget.lead.email ?? '');

    _nameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);

    // Reset cubit if it holds a stale completed/failed state
    final cubit = context.read<LeadFormCubit>();
    if (cubit.state is LeadFormSuccess || cubit.state is LeadFormFailure) {
      cubit.reset();
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

  void _onFieldChanged() {
    setState(() {});
  }

  bool get _isDirty {
    final currentName = _nameController.text.trim();
    final currentPhone = _phoneController.text.trim();
    final currentEmail = _emailController.text.trim();

    final originalName = widget.lead.name?.trim() ?? '';
    final originalPhone = widget.lead.phone?.trim() ?? '';
    final originalEmail = widget.lead.email?.trim() ?? '';

    return currentName != originalName ||
        currentPhone != originalPhone ||
        currentEmail != originalEmail;
  }

  void _handleCancel() {
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _submit() {
    final cubit = context.read<LeadFormCubit>();
    if (cubit.state is LeadFormSubmitting || !_isDirty) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    final draft = LeadDraft(
      name: name.isEmpty ? null : name,
      phone: phone.isEmpty ? null : phone,
      email: email.isEmpty ? null : email,
      source: widget.lead.source,
      status: widget.lead.status,
    );

    cubit.updateLead(widget.lead.id, draft);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Lead'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _handleCancel,
        ),
      ),
      body: BlocConsumer<LeadFormCubit, LeadFormState>(
        listener: (context, state) {
          if (state is LeadFormSuccess) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lead updated successfully'),
                duration: Duration(seconds: 2),
              ),
            );
            widget.onLeadUpdated?.call(state.lead);
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          } else if (state is LeadFormFailure) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: colorScheme.error,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        builder: (context, state) {
          final isSubmitting = state is LeadFormSubmitting;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final maxBadgeWidth = constraints.maxWidth > 80
                  ? constraints.maxWidth - 80
                  : 250.0;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 24 : 16,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isWide ? 24 : 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Form Header with Read-Only Context
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        colorScheme.primaryContainer,
                                    foregroundColor:
                                        colorScheme.onPrimaryContainer,
                                    child: const Icon(Icons.edit_outlined),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Edit Lead Details',
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
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                                fontFamily: 'monospace',
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      formatLeadSource(widget.lead.source),
                                    ),
                                    avatar: const Icon(
                                      Icons.source_outlined,
                                      size: 16,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    side: BorderSide.none,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Read-only Context Badges (Status / Assignee)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoBadge(
                                    label:
                                        'Status: ${formatLeadStatus(widget.lead.status)}',
                                    icon: Icons.flag_outlined,
                                    colorScheme: colorScheme,
                                    maxWidth: maxBadgeWidth,
                                  ),
                                  _InfoBadge(
                                    label:
                                        'Assigned: ${formatLeadAssignee(widget.lead)}',
                                    icon: widget.lead.isAssigned
                                        ? Icons.person
                                        : Icons.person_outline,
                                    colorScheme: colorScheme,
                                    maxWidth: maxBadgeWidth,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 20),

                              // Failure Banner
                              if (state is LeadFormFailure) ...[
                                Container(
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
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          state.message,
                                          style: TextStyle(
                                            color: colorScheme.onErrorContainer,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Section: Basic Information
                              Text(
                                'Basic Information',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _nameController,
                                enabled: !isSubmitting,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.name,
                                decoration: const InputDecoration(
                                  labelText: 'Lead Name',
                                  hintText: 'e.g. John Doe',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Section: Contact Information
                              Text(
                                'Contact Information',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (isWide) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildPhoneField(isSubmitting),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildEmailField(isSubmitting),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                _buildPhoneField(isSubmitting),
                                const SizedBox(height: 16),
                                _buildEmailField(isSubmitting),
                              ],
                              const SizedBox(height: 28),

                              // Form Actions
                              if (isWide) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: isSubmitting
                                          ? null
                                          : _handleCancel,
                                      child: const Text('Cancel'),
                                    ),
                                    const SizedBox(width: 12),
                                    FilledButton.icon(
                                      onPressed: (isSubmitting || !_isDirty)
                                          ? null
                                          : _submit,
                                      icon: isSubmitting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.save_outlined,
                                              size: 18,
                                            ),
                                      label: Text(
                                        isSubmitting
                                            ? 'Saving...'
                                            : 'Save Changes',
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: isSubmitting
                                            ? null
                                            : _handleCancel,
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: (isSubmitting || !_isDirty)
                                            ? null
                                            : _submit,
                                        icon: isSubmitting
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.save_outlined,
                                                size: 18,
                                              ),
                                        label: Text(
                                          isSubmitting
                                              ? 'Saving...'
                                              : 'Save Changes',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPhoneField(bool isSubmitting) {
    return TextFormField(
      controller: _phoneController,
      enabled: !isSubmitting,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(
        labelText: 'Phone',
        hintText: 'e.g. +91 9876543210',
        prefixIcon: Icon(Icons.phone_outlined),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildEmailField(bool isSubmitting) {
    return TextFormField(
      controller: _emailController,
      enabled: !isSubmitting,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null;
        }
        final email = value.trim();
        if (!email.contains('@') || !email.contains('.')) {
          return 'Enter a valid email address';
        }
        return null;
      },
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'e.g. name@example.com',
        prefixIcon: Icon(Icons.email_outlined),
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final ColorScheme colorScheme;
  final double? maxWidth;

  const _InfoBadge({
    required this.label,
    required this.icon,
    required this.colorScheme,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: maxWidth != null
          ? BoxConstraints(maxWidth: maxWidth!)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
