import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../features/auth/domain/entities/crm_module.dart';
import '../../../../features/auth/domain/entities/current_user.dart';
import '../../../../features/dashboard/presentation/mappers/crm_module_presentation.dart';
import '../../data/mock/mock_permission_catalog.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/inputs/update_managed_user_input.dart';
import '../../domain/repositories/user_management_repository.dart';

/// Admin-only screen for editing a standard user's display name, assigned
/// modules, and permissions.
///
/// Immutable fields: User ID and Account Type.
/// Master Admin records cannot be edited here.
class EditUserScreen extends StatefulWidget {
  final CurrentUser currentUser;
  final ManagedUser user;
  final UserManagementRepository? repository;

  const EditUserScreen({
    super.key,
    required this.currentUser,
    required this.user,
    this.repository,
  });

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;

  late final Set<CrmModule> _selectedModules;
  late final Set<String> _selectedPermissions;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.user.displayName,
    );
    _selectedModules = Set.of(widget.user.modules);
    _selectedPermissions = Set.of(widget.user.permissions);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _toggleModule(CrmModule module) {
    setState(() {
      if (_selectedModules.contains(module)) {
        _selectedModules.remove(module);
        // Deselecting a module immediately clears its assigned permissions
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

    final trimmedDisplayName = _displayNameController.text.trim();
    if (trimmedDisplayName.isEmpty) {
      setState(() {
        _errorMessage = 'Display Name cannot be empty.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repo =
          widget.repository ?? context.read<UserManagementRepository>();
      final input = UpdateManagedUserInput(
        id: widget.user.id,
        displayName: trimmedDisplayName,
        modules: _selectedModules,
        permissions: _selectedPermissions,
      );

      final updatedUser = await repo.updateUser(input);

      if (mounted) {
        Navigator.of(context).pop(updatedUser);
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
              'An unexpected error occurred while updating the user.';
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
        key: const Key('edit_user_unauthorized_screen'),
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
                  key: Key('edit_user_unauthorized_icon'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You do not have administrative privileges to edit users.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  key: const Key('edit_user_unauthorized_back_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Return'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Master Admin protection: Master Admin modules/permissions cannot be edited
    if (widget.user.isAdmin) {
      return Scaffold(
        key: const Key('edit_user_admin_protected_screen'),
        appBar: AppBar(title: const Text('Edit Restricted')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 56,
                  color: Colors.amber,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Master Administrator Protected',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Master Administrator modules and permissions cannot be modified.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  key: const Key('edit_user_admin_protected_back_button'),
                  onPressed: () => Navigator.of(context).pop(),
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
      key: const Key('edit_user_screen'),
      appBar: AppBar(
        title: Text('Edit User: @${widget.user.userId}'),
        elevation: 0,
      ),
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
                      'User ID and Account Type are immutable system identifiers.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_errorMessage != null) ...[
                      Container(
                        key: const Key('edit_user_error_banner'),
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
                            // User ID (Read-only)
                            TextFormField(
                              key: const Key('edit_user_id_field'),
                              initialValue: widget.user.userId,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'User ID (Read-only)',
                                prefixIcon: const Icon(Icons.lock_outline),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                border: const OutlineInputBorder(),
                                helperText:
                                    'User login handles cannot be renamed',
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Account Type (Read-only)
                            InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Account Type (Read-only)',
                                prefixIcon: const Icon(Icons.shield_outlined),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                border: const OutlineInputBorder(),
                              ),
                              child: Text(
                                widget.user.isAdmin
                                    ? 'Administrator'
                                    : 'Standard User',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Display Name (Editable)
                            TextFormField(
                              key: const Key('edit_user_display_name_field'),
                              controller: _displayNameController,
                              decoration: const InputDecoration(
                                labelText: 'Display Name *',
                                hintText: 'Enter full name',
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
                              key: Key('edit_user_module_${module.name}'),
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
                          key: const Key('edit_user_cancel_button'),
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          key: const Key('edit_user_submit_button'),
                          onPressed: _isSubmitting ? null : _handleSave,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save Changes'),
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
            key: Key('edit_user_permission_${def.id}'),
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
