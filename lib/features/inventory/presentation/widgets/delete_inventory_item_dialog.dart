import 'package:flutter/material.dart';

import '../../domain/entities/inventory_item.dart';
import '../utils/inventory_display_formatters.dart';

/// Confirmation dialog for permanent inventory item deletion.
///
/// Requires the user to type the item's exact SKU before the confirmation action is enabled.
/// Displays item name, SKU, current quantity, and explicit explanation of the 60-second undo window.
class DeleteInventoryItemDialog extends StatefulWidget {
  final InventoryItem item;
  final double currentQuantity;

  const DeleteInventoryItemDialog({
    super.key,
    required this.item,
    required this.currentQuantity,
  });

  /// Displays the confirmation dialog and returns `true` if deletion was confirmed.
  static Future<bool?> show(
    BuildContext context, {
    required InventoryItem item,
    required double currentQuantity,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteInventoryItemDialog(
        item: item,
        currentQuantity: currentQuantity,
      ),
    );
  }

  @override
  State<DeleteInventoryItemDialog> createState() =>
      _DeleteInventoryItemDialogState();
}

class _DeleteInventoryItemDialogState extends State<DeleteInventoryItemDialog> {
  final _skuController = TextEditingController();
  bool _isConfirmed = false;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _skuController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final matches = _skuController.text == widget.item.sku;
    if (matches != _isConfirmed) {
      setState(() {
        _isConfirmed = matches;
      });
    }
  }

  @override
  void dispose() {
    _skuController.removeListener(_onTextChanged);
    _skuController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_isConfirmed || _hasSubmitted) return;
    setState(() {
      _hasSubmitted = true;
    });
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final qtyStr = InventoryDisplayFormatters.formatQuantity(
      widget.currentQuantity,
    );

    return AlertDialog(
      key: const Key('delete_inventory_item_dialog'),
      icon: Icon(
        Icons.warning_amber_rounded,
        color: colorScheme.error,
        size: 36,
      ),
      title: const Text('Delete Inventory Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This item and its complete stock history will be permanently deleted after the Undo period expires.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item: ${widget.item.name}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SKU: ${widget.item.sku}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current Stock: $qtyStr',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Type ${widget.item.sku} to confirm:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('delete_inventory_item_sku_input'),
              controller: _skuController,
              enabled: !_hasSubmitted,
              decoration: InputDecoration(
                hintText: widget.item.sku,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('delete_inventory_item_cancel_button'),
          onPressed: _hasSubmitted
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('delete_inventory_item_confirm_button'),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: _isConfirmed && !_hasSubmitted ? _submit : null,
          child: const Text('Confirm Delete'),
        ),
      ],
    );
  }
}
