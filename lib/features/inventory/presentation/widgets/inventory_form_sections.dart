import 'package:flutter/material.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../data/repositories/mock_inventory_repository.dart';
import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_stock_status.dart';
import '../../domain/repositories/inventory_repository.dart';

/// Reusable section card wrapper with consistent styling and header icons.
class InventorySectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  const InventorySectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(128),
        ),
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
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Masked / locked placeholder for sensitive fields.
class RestrictedFieldPlaceholder extends StatelessWidget {
  final String label;

  const RestrictedFieldPlaceholder({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(128)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: Access Restricted',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only stock status badge.
class StockStatusBadge extends StatelessWidget {
  final InventoryStockStatus status;

  const StockStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      InventoryStockStatus.inStock => (Colors.green.shade50, Colors.green.shade800),
      InventoryStockStatus.lowStock => (Colors.orange.shade50, Colors.orange.shade800),
      InventoryStockStatus.outOfStock => (Colors.red.shade50, Colors.red.shade800),
      InventoryStockStatus.overstock => (Colors.purple.shade50, Colors.purple.shade800),
      InventoryStockStatus.discontinued => (Colors.grey.shade100, Colors.grey.shade800),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withAlpha(64)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Dialog allowing administrators to register new custom field definitions.
class AddCustomFieldDialog extends StatefulWidget {
  final InventoryRepository repository;
  final CurrentUser user;

  const AddCustomFieldDialog({
    super.key,
    required this.repository,
    required this.user,
  });

  @override
  State<AddCustomFieldDialog> createState() => _AddCustomFieldDialogState();
}

class _AddCustomFieldDialogState extends State<AddCustomFieldDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _keyController = TextEditingController();
  final _optionsController = TextEditingController();
  final _defaultValueController = TextEditingController();

  CustomFieldDataType _selectedType = CustomFieldDataType.text;
  bool _isRequired = false;
  bool _manualKeyEdited = false;
  String? _errorMessage;

  @override
  void dispose() {
    _labelController.dispose();
    _keyController.dispose();
    _optionsController.dispose();
    _defaultValueController.dispose();
    super.dispose();
  }

  void _onLabelChanged(String val) {
    if (!_manualKeyEdited) {
      final generated = val
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      _keyController.text = generated;
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final label = _labelController.text.trim();
    final key = _keyController.text.trim().toLowerCase();

    if (CustomFieldDefinition.isReservedStandardKey(key)) {
      setState(() {
        _errorMessage = 'Key "$key" is reserved for standard inventory fields.';
      });
      return;
    }

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(key)) {
      setState(() {
        _errorMessage = 'Key must contain lowercase letters, numbers, and underscores only.';
      });
      return;
    }

    List<String> options = const [];
    if (_selectedType == CustomFieldDataType.dropdown) {
      options = _optionsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (options.isEmpty) {
        setState(() {
          _errorMessage = 'Dropdown fields require at least one option.';
        });
        return;
      }
    }

    final defaultRaw = _defaultValueController.text.trim();
    final String? defaultValue = defaultRaw.isNotEmpty ? defaultRaw : null;

    final definition = CustomFieldDefinition(
      id: 'custom_field_${DateTime.now().millisecondsSinceEpoch}',
      key: key,
      label: label,
      dataType: _selectedType,
      isRequired: _isRequired,
      options: options,
      defaultValue: defaultValue,
      createdAt: DateTime.now(),
      createdBy: widget.user.id,
    );

    try {
      final repo = widget.repository;
      if (repo is MockInventoryRepository) {
        await repo.saveCustomFieldDefinition(definition);
      }
      if (mounted) {
        Navigator.of(context).pop(definition);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Add Custom Field'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 18, color: colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                TextFormField(
                  key: const Key('custom_field_def_label'),
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Field Label *',
                    hintText: 'e.g. Storage Temperature',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _onLabelChanged,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Field label is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('custom_field_def_key'),
                  controller: _keyController,
                  decoration: const InputDecoration(
                    labelText: 'Machine Key *',
                    hintText: 'e.g. storage_temperature',
                    helperText: 'Lowercase letters, numbers, and underscores only.',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _manualKeyEdited = true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Machine key is required.';
                    }
                    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(val.trim().toLowerCase())) {
                      return 'Key must be lowercase letters, numbers, and underscores.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CustomFieldDataType>(
                  key: const Key('custom_field_def_type'),
                  isExpanded: true,
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Field Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: CustomFieldDataType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedType = val);
                    }
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const Key('custom_field_def_required'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Required Field'),
                  subtitle: const Text('Value must be provided when creating or editing items.'),
                  value: _isRequired,
                  onChanged: (val) => setState(() => _isRequired = val),
                ),
                if (_selectedType == CustomFieldDataType.dropdown) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('custom_field_def_options'),
                    controller: _optionsController,
                    decoration: const InputDecoration(
                      labelText: 'Dropdown Options *',
                      hintText: 'Comma-separated: Cold, Ambient, Frozen',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (_selectedType == CustomFieldDataType.dropdown) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter at least one option.';
                        }
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('custom_field_def_default'),
                  controller: _defaultValueController,
                  decoration: InputDecoration(
                    labelText: 'Default Value (optional)',
                    hintText: _selectedType == CustomFieldDataType.date
                        ? 'YYYY-MM-DD'
                        : _selectedType == CustomFieldDataType.boolean
                            ? 'true or false'
                            : 'Default value',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('custom_field_def_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('custom_field_def_save'),
          onPressed: _submit,
          child: const Text('Save Field'),
        ),
      ],
    );
  }
}
