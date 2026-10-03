import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/inventory_export_artifact.dart';
import '../../domain/policies/inventory_export_policy.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../bloc/inventory_export_cubit.dart';
import '../bloc/inventory_export_state.dart';
import '../services/inventory_export_data_loader.dart';
import '../services/inventory_export_file_delivery_service.dart';
import '../services/inventory_export_service.dart';

/// Opens the inventory export modal dialog.
Future<bool?> showInventoryExportDialog({
  required BuildContext context,
  required CurrentUser user,
  required InventoryRepository repository,
  CurrentUser? Function()? currentUserProvider,
  InventoryExportCubit? cubit,
  InventoryExportFileDeliveryService? fileDeliveryService,
}) {
  CurrentUser? Function()? effectiveProvider = currentUserProvider;
  if (effectiveProvider == null) {
    try {
      final authCubit = context.read<AuthCubit?>();
      if (authCubit != null) {
        effectiveProvider = () {
          final s = authCubit.state;
          return s is AuthAuthenticated ? s.user : null;
        };
      }
    } catch (_) {}
  }
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => InventoryExportDialog(
      user: user,
      repository: repository,
      currentUserProvider: effectiveProvider,
      cubit: cubit,
      fileDeliveryService: fileDeliveryService,
    ),
  );
}

/// Reusable modal dialog for configuring, preparing, and delivering inventory exports.
class InventoryExportDialog extends StatefulWidget {
  final CurrentUser user;
  final InventoryRepository repository;
  final CurrentUser? Function()? currentUserProvider;
  final InventoryExportCubit? cubit;
  final InventoryExportFileDeliveryService? fileDeliveryService;

  const InventoryExportDialog({
    super.key,
    required this.user,
    required this.repository,
    this.currentUserProvider,
    this.cubit,
    this.fileDeliveryService,
  });

  @override
  State<InventoryExportDialog> createState() => _InventoryExportDialogState();
}

class _InventoryExportDialogState extends State<InventoryExportDialog> {
  late final InventoryExportCubit _cubit;
  late final InventoryExportFileDeliveryService _fileDeliveryService;
  late final bool _isExternalCubit;
  late final CurrentUser? Function() _currentUserProvider;

  String? _initiatingUserId;
  InventoryExportFormat? _selectedFormat;
  bool _isDelivering = false;
  String? _deliveryFeedback;
  bool _isDeliverySuccess = false;

  CurrentUser? _getSafeCurrentUser() {
    try {
      return _currentUserProvider();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUserProvider = widget.currentUserProvider ??
        () {
          try {
            final authCubit = context.read<AuthCubit?>();
            if (authCubit != null) {
              final authState = authCubit.state;
              if (authState is AuthAuthenticated) {
                return authState.user;
              }
            }
          } catch (_) {}
          return null;
        };
    _isExternalCubit = widget.cubit != null;
    if (_isExternalCubit) {
      _cubit = widget.cubit!;
    } else {
      final dataLoader = InventoryExportDataLoader(widget.repository);
      final exportService = InventoryExportService(dataLoader: dataLoader);
      _cubit = InventoryExportCubit(
        exportService: exportService,
        currentUser: widget.user,
        currentUserProvider: _getSafeCurrentUser,
      );
    }

    _fileDeliveryService = widget.fileDeliveryService ??
        InventoryExportFileDeliveryService();

    final activeUser = _getSafeCurrentUser();
    final canCsv = activeUser != null && InventoryExportPolicy.canExportCsv(activeUser);
    final canXlsx = activeUser != null && InventoryExportPolicy.canExportXlsx(activeUser);

    if (canCsv) {
      _selectedFormat = InventoryExportFormat.csv;
    } else if (canXlsx) {
      _selectedFormat = InventoryExportFormat.xlsx;
    }
  }

  @override
  void dispose() {
    if (!_isExternalCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  void _startPreparation(InventoryExportFormat format) {
    setState(() {
      _deliveryFeedback = null;
      _isDeliverySuccess = false;
    });

    final activeUser = _getSafeCurrentUser();
    if (activeUser == null) {
      setState(() {
        _deliveryFeedback = 'User session expired or unauthenticated.';
      });
      return;
    }

    final isAuthorized = format == InventoryExportFormat.csv
        ? InventoryExportPolicy.canExportCsv(activeUser)
        : InventoryExportPolicy.canExportXlsx(activeUser);

    if (!isAuthorized) {
      setState(() {
        _deliveryFeedback =
            "You don't have permission to export inventory in this format.";
      });
      return;
    }

    // Capture the initiating user identity at preparation time
    _initiatingUserId = activeUser.id;
    _cubit.export(format);
  }

  Future<void> _handleDelivery(InventoryExportArtifact artifact) async {
    if (_isDelivering) return;

    setState(() {
      _isDelivering = true;
      _deliveryFeedback = null;
    });

    final result = await _fileDeliveryService.deliverArtifact(
      artifact: artifact,
      currentUserProvider: _getSafeCurrentUser,
      boundUserId: _initiatingUserId,
    );

    if (!mounted) return;

    setState(() {
      _isDelivering = false;
      if (result.isSaved) {
        _isDeliverySuccess = true;
        _deliveryFeedback = 'Inventory exported successfully.';
      } else if (result.isDownloadInitiated) {
        _isDeliverySuccess = true;
        _deliveryFeedback = 'Inventory download started.';
      } else if (result.isCancelled) {
        _isDeliverySuccess = false;
        _deliveryFeedback = 'File save was cancelled.';
      } else if (result.isRestricted) {
        _isDeliverySuccess = false;
        _deliveryFeedback = result.message ??
            "You don't have permission to export inventory in this format.";
      } else {
        _isDeliverySuccess = false;
        _deliveryFeedback = result.message ??
            'Unable to export inventory. Please try again.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<InventoryExportCubit, InventoryExportState>(
        listener: (context, state) {
          // Delivery is NOT triggered automatically from the listener.
          // It requires an explicit user action (Download button click) in the Prepared state.
        },
        builder: (context, state) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          final activeUser = _getSafeCurrentUser();
          final canCsv = activeUser != null && InventoryExportPolicy.canExportCsv(activeUser);
          final canXlsx = activeUser != null && InventoryExportPolicy.canExportXlsx(activeUser);

          final isBusy = state is InventoryExportPreparing || _isDelivering;
          final canSelected = activeUser != null &&
              (_selectedFormat == InventoryExportFormat.csv ? canCsv : canXlsx);

          return PopScope(
            canPop: !isBusy,
            child: AlertDialog(
              key: const Key('inventory_export_dialog'),
              title: Row(
                children: [
                  Icon(
                    Icons.download_outlined,
                    size: 22,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Export Inventory',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Export all authorized active items. Exactly three columns (Item Name, SKU, Current Quantity) will be exported.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Format',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RadioGroup<InventoryExportFormat>(
                        groupValue: _selectedFormat,
                        onChanged: (format) {
                          if (!isBusy && format != null) {
                            setState(() {
                              _selectedFormat = format;
                              _deliveryFeedback = null;
                              _isDeliverySuccess = false;
                            });
                            if (state is InventoryExportPrepared) {
                              _cubit.reset();
                            }
                          }
                        },
                        child: Column(
                          children: [
                            RadioListTile<InventoryExportFormat>(
                              key: const Key('inventory_export_format_csv'),
                              value: InventoryExportFormat.csv,
                              title: const Text('CSV (.csv)'),
                              subtitle: const Text('Spreadsheet-compatible text file.'),
                              enabled: !isBusy && canCsv,
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<InventoryExportFormat>(
                              key: const Key('inventory_export_format_xlsx'),
                              value: InventoryExportFormat.xlsx,
                              title: const Text('Excel (.xlsx)'),
                              subtitle: const Text('Excel workbook with numeric stock quantities.'),
                              enabled: !isBusy && canXlsx,
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),

                      if (activeUser == null && state is! InventoryExportPrepared && _deliveryFeedback == null) ...[
                        const SizedBox(height: 12),
                        _buildFeedbackBox(
                          context,
                          key: const Key('inventory_export_dialog_unauthenticated_notice'),
                          icon: Icons.lock_outline,
                          message: 'User session expired or unauthenticated.',
                          isError: true,
                        ),
                      ],

                      if (state is InventoryExportPreparing || _isDelivering) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                key: Key('inventory_export_loading_indicator'),
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isDelivering
                                    ? 'Saving export file...'
                                    : 'Preparing inventory export...',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (state is InventoryExportPrepared) ...[
                        const SizedBox(height: 12),
                        _buildFeedbackBox(
                          context,
                          key: const Key('inventory_export_dialog_prepared_feedback'),
                          icon: Icons.check_circle_outline,
                          message: 'Inventory export ready (${state.artifact.format == InventoryExportFormat.csv ? "CSV" : "Excel"}).',
                          isError: false,
                        ),
                      ],

                      if (state is InventoryExportRestricted) ...[
                        const SizedBox(height: 12),
                        _buildFeedbackBox(
                          context,
                          key: const Key('inventory_export_dialog_restricted'),
                          icon: Icons.lock_outline,
                          message: state.message,
                          isError: true,
                        ),
                      ],

                      if (state is InventoryExportFailure) ...[
                        const SizedBox(height: 12),
                        _buildFeedbackBox(
                          context,
                          key: const Key('inventory_export_dialog_failure'),
                          icon: Icons.error_outline,
                          message: state.message,
                          isError: true,
                        ),
                      ],

                      if (_deliveryFeedback != null) ...[
                        const SizedBox(height: 12),
                        _buildFeedbackBox(
                          context,
                          key: const Key('inventory_export_dialog_delivery_feedback'),
                          icon: _isDeliverySuccess ? Icons.check_circle_outline : Icons.info_outline,
                          message: _deliveryFeedback!,
                          isError: !_isDeliverySuccess,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  key: const Key('inventory_export_dialog_cancel_button'),
                  onPressed: isBusy ? null : () => Navigator.of(context).pop(_isDeliverySuccess),
                  child: Text(_isDeliverySuccess ? 'Close' : 'Cancel'),
                ),
                if (state is InventoryExportPrepared)
                  FilledButton(
                    key: const Key('inventory_export_dialog_download_button'),
                    onPressed: isBusy ? null : () => _handleDelivery(state.artifact),
                    child: isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            state.artifact.format == InventoryExportFormat.csv
                                ? 'Download CSV'
                                : 'Download Excel',
                          ),
                  )
                else
                  FilledButton(
                    key: const Key('inventory_export_dialog_submit_button'),
                    onPressed: (isBusy || _selectedFormat == null || !canSelected)
                        ? null
                        : () => _startPreparation(_selectedFormat!),
                    child: isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Export'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedbackBox(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String message,
    required bool isError,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = isError ? colorScheme.errorContainer : colorScheme.primaryContainer;
    final fgColor = isError ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer;

    return Container(
      key: key,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fgColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: fgColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
