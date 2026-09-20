import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../features/auth/domain/entities/crm_module.dart';
import '../../../../features/auth/domain/entities/current_user.dart';
import '../../../../features/dashboard/presentation/mappers/crm_module_presentation.dart';
import '../../data/mock/mock_permission_catalog.dart';
import '../../domain/inputs/create_managed_user_input.dart';
import '../../domain/repositories/user_management_repository.dart';

/// Admin-only screen for creating new standard user accounts with assigned
/// modules and permissions.
class CreateUserScreen extends StatefulWidget {
  final CurrentUser currentUser;
  final UserManagementRepository? repository;

  const CreateUserScreen({
    super.key,
    required this.currentUser,
    this.repository,
  });

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();

  final Set<CrmModule> _selectedModules = {};
  final Set<String> _selectedPermissions = {};

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _userIdController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleModule(CrmModule module) {
    setState(() {
      if (_selectedModules.contains(module)) {
        _selectedModules.remove(module);
        // Deselecting a module immediately clears its permissions
        _selectedPermissions.removeWhere(
          (p) => MockPermissionCatalog.getModuleForPermission(p) == module,
        );
      } else {
        _selectedModules.add(module);
      }
    });
  }

  void _togglePermission(String permissionId) {
    setState(() {
      if (_selectedPermissions.contains(permissionId)) {
        _selectedPermissions.remove(permissionId);
      } else {
        _selectedPermissions.add(permissionId);
      }
    });
  }

  Future<void> _handleSave() async {
    if (_isSubmitting) return;

    setState(() {
      _errorMessage = null;
    });

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final trimmedUserId = _userIdController.text.trim();
    final trimmedDisplayName = _displayNameController.text.trim();
    final trimmedPassword = _passwordController.text.trim();

    if (trimmedUserId.isEmpty ||
        trimmedDisplayName.isEmpty ||
        trimmedPassword.isEmpty) {
      setState(() {
        _errorMessage = 'All required fields must be provided.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repo =
          widget.repository ?? context.read<UserManagementRepository>();
      final input = CreateManagedUserInput(
        userId: trimmedUserId,
        displayName: trimmedDisplayName,
        modules: _selectedModules,
        permissions: _selectedPermissions,
      );

      await repo.createUser(input, temporaryPassword: trimmedPassword);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on UserManagementException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isSubmitting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'An unexpected error occurred while creating the user.';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Route guard: only administrators may access this screen
    if (!widget.currentUser.isAdmin) {
      return Scaffold(
        key: const Key('create_user_unauthorized_screen'),
        appBar: AppBar(title: const Text('Access Denied')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.gpp_bad_outlined,
                  size: 56,
                  color: Colors.redAccent,
                  key: Key('create_user_unauthorized_icon'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You do not have administrative privileges to create users.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  key: const Key('create_user_unauthorized_back_button'),
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Return'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      key: const Key('create_user_screen'),
      appBar: AppBar(title: const Text('Create User'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: width < 600 ? 16.0 : 24.0,
            vertical: 20.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCOUNT DETAILS',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All accounts created here are assigned Standard User permissions.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_errorMessage != null) ...[
                      Container(
                        key: const Key('create_user_error_banner'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colorScheme.error),
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
                                _errorMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      color: colorScheme.surfaceContainerLowest,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User ID
                            TextFormField(
                              key: const Key('create_user_id_field'),
                              controller: _userIdController,
                              decoration: const InputDecoration(
                                labelText: 'User ID *',
                                hintText: 'e.g. jsmith, sales_01',
                                helperText:
                                    'Unique login handle (case-insensitive, cannot be changed later)',
                                prefixIcon: Icon(Icons.alternate_email),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'User ID is required.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Display Name
                            TextFormField(
                              key: const Key('create_user_display_name_field'),
                              controller: _displayNameController,
                              decoration: const InputDecoration(
                                labelText: 'Display Name *',
                                hintText: 'e.g. Jane Smith',
                                helperText:
                                    'Full name displayed in the CRM header and records',
                                prefixIcon: Icon(Icons.badge_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Display Name is required.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Temporary Password
                            TextFormField(
                              key: const Key('create_user_password_field'),
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Temporary Password *',
                                hintText: 'Enter initial password',
                                helperText:
                                    'Initial credential for first user login',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  key: const Key(
                                    'create_user_password_visibility_button',
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Temporary Password is required.';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Module Access
                    Text(
                      'MODULE ACCESS',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select which business modules this user can view and interact with.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      color: colorScheme.surfaceContainerLowest,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: CrmModule.values.map((module) {
                            final isSelected = _selectedModules.contains(
                              module,
                            );
                            return FilterChip(
                              key: Key('create_user_module_${module.name}'),
                              avatar: Icon(
                                module.icon,
                                size: 18,
                                color: isSelected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                              label: Text(module.displayName),
                              selected: isSelected,
                              onSelected: (_) => _toggleModule(module),
                              showCheckmark: true,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Permissions
                    Text(
                      'PERMISSIONS',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Granular permissions based strictly on selected modules.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      color: colorScheme.surfaceContainerLowest,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _selectedModules.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                ),
                                child: Text(
                                  'Select one or more modules above to configure permissions.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildPermissionSections(
                                  theme,
                                  colorScheme,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Actions Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          key: const Key('create_user_cancel_button'),
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          key: const Key('create_user_submit_button'),
                          onPressed: _isSubmitting ? null : _handleSave,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.person_add_outlined),
                          label: const Text('Create User'),
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
  }

  List<Widget> _buildPermissionSections(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final widgets = <Widget>[];

    for (final module in _selectedModules) {
      final moduleDefs = MockPermissionCatalog.definitions
          .where((d) => d.module == module)
          .toList();

      if (moduleDefs.isEmpty) continue;

      if (widgets.isNotEmpty) {
        widgets.add(const Divider(height: 24));
      }

      widgets.add(
        Row(
          children: [
            Icon(module.icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              module.displayName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
      widgets.add(const SizedBox(height: 8));

      for (final def in moduleDefs) {
        final isChecked = _selectedPermissions.contains(def.id);
        widgets.add(
          CheckboxListTile(
            key: Key('create_user_permission_${def.id}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(def.displayName),
            subtitle: Text(
              def.id,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            value: isChecked,
            onChanged: (_) => _togglePermission(def.id),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
      }
    }

    if (widgets.isEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'The selected module(s) do not define granular permissions.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}
