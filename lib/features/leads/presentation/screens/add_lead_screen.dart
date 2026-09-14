import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_draft.dart';
import '../../domain/entities/lead_source.dart';
import '../../domain/repositories/lead_repository.dart';
import '../bloc/lead_form_cubit.dart';
import '../bloc/lead_form_state.dart';

class AddLeadScreen extends StatelessWidget {
  final LeadFormCubit? cubit;
  final LeadRepository? repository;
  final void Function(Lead lead)? onLeadCreated;
  final VoidCallback? onCancel;

  const AddLeadScreen({
    super.key,
    this.cubit,
    this.repository,
    this.onLeadCreated,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _AddLeadView(onLeadCreated: onLeadCreated, onCancel: onCancel),
      );
    }

    if (repository != null) {
      return BlocProvider(
        create: (_) => LeadFormCubit(repository!),
        child: _AddLeadView(onLeadCreated: onLeadCreated, onCancel: onCancel),
      );
    }

    return _AddLeadView(onLeadCreated: onLeadCreated, onCancel: onCancel);
  }
}

class _AddLeadView extends StatefulWidget {
  final void Function(Lead lead)? onLeadCreated;
  final VoidCallback? onCancel;

  const _AddLeadView({this.onLeadCreated, this.onCancel});

  @override
  State<_AddLeadView> createState() => _AddLeadViewState();
}

class _AddLeadViewState extends State<_AddLeadView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
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
    if (cubit.state is LeadFormSubmitting) {
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
      source: LeadSource.manual,
    );

    cubit.createLead(draft);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Lead'),
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
                content: Text('Lead created successfully'),
                duration: Duration(seconds: 2),
              ),
            );
            widget.onLeadCreated?.call(state.lead);
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
                              // Form Header
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        colorScheme.primaryContainer,
                                    foregroundColor:
                                        colorScheme.onPrimaryContainer,
                                    child: const Icon(
                                      Icons.person_add_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'New Lead',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          'Manual lead entry',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Chip(
                                    label: const Text('Manual'),
                                    avatar: const Icon(
                                      Icons.edit_note,
                                      size: 16,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    side: BorderSide.none,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
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
                                      onPressed: isSubmitting ? null : _submit,
                                      icon: isSubmitting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.add, size: 18),
                                      label: Text(
                                        isSubmitting
                                            ? 'Creating...'
                                            : 'Create Lead',
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
                                        onPressed: isSubmitting
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
                                            : const Icon(Icons.add, size: 18),
                                        label: Text(
                                          isSubmitting
                                              ? 'Creating...'
                                              : 'Create Lead',
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
