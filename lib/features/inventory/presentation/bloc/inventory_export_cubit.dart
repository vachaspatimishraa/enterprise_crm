import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_export_artifact.dart';
import '../../domain/entities/inventory_query.dart';
import '../../domain/policies/inventory_export_policy.dart';
import '../services/inventory_export_service.dart';
import 'inventory_export_state.dart';

/// Cubit responsible for orchestrating authorized inventory export requests.
class InventoryExportCubit extends Cubit<InventoryExportState> {
  final InventoryExportService _exportService;
  final CurrentUser? Function() _currentUserProvider;

  int _activeRequestId = 0;

  InventoryExportCubit({
    required InventoryExportService exportService,
    required CurrentUser currentUser,
    CurrentUser? Function()? currentUserProvider,
  })  : _exportService = exportService,
        _currentUserProvider = currentUserProvider ?? (() => currentUser),
        super(const InventoryExportInitial());

  /// Returns true if an export preparation is currently in progress.
  bool get isPreparing => state is InventoryExportPreparing;

  /// Initiates export generation for the specified [format] and configuration options.
  Future<void> export(
    InventoryExportFormat format, {
    InventoryExportScope scope = InventoryExportScope.all,
    InventoryExportPreset preset = InventoryExportPreset.legacyThreeColumn,
    List<String>? columns,
    InventoryQuery? query,
    Set<String>? selectedItemIds,
    List<CustomFieldDefinition>? customFieldDefinitions,
  }) async {
    // Duplicate-request guard: do not allow initiating while another export is preparing
    if (isPreparing) {
      return;
    }

    final requestId = ++_activeRequestId;
    final initialUser = _currentUserProvider();

    // Initial authorization check
    if (initialUser == null || !_isAuthorized(initialUser, format)) {
      emit(InventoryExportRestricted(format));
      return;
    }

    // Immediate field-level check for custom column selection
    if (columns != null && preset == InventoryExportPreset.custom) {
      for (final col in columns) {
        if (InventoryExportPolicy.isRestrictedField(col) &&
            !InventoryExportPolicy.canExportField(initialUser, col)) {
          emit(InventoryExportRestricted(
            format,
            message: 'You do not have permission to export restricted field: $col',
          ));
          return;
        }
      }
    }

    emit(InventoryExportPreparing(format));

    try {
      final artifact = await _exportService.prepareExport(
        format: format,
        initialUser: initialUser,
        currentUserProvider: _currentUserProvider,
        scope: scope,
        preset: preset,
        columns: columns,
        query: query,
        selectedItemIds: selectedItemIds,
        customFieldDefinitions: customFieldDefinitions,
      );

      // Guard against stale asynchronous completion or cubit closure
      if (isClosed || requestId != _activeRequestId) {
        return;
      }

      emit(InventoryExportPrepared(artifact));
    } on InventoryExportException catch (e) {
      if (isClosed || requestId != _activeRequestId) return;
      // Map security/authorization revalidation failures to restricted
      if (e.message.contains('not authorized') ||
          e.message.contains('Unauthorized') ||
          e.message.contains('revoked') ||
          e.message.contains('expired') ||
          e.message.contains('changed')) {
        emit(InventoryExportRestricted(format, message: e.message));
      } else {
        emit(InventoryExportFailure(format, e.message));
      }
    } catch (e) {
      if (isClosed || requestId != _activeRequestId) return;
      emit(InventoryExportFailure(format, 'Failed to prepare export: $e'));
    }
  }

  /// Resets state back to initial idle.
  void reset() {
    if (!isPreparing) {
      emit(const InventoryExportInitial());
    }
  }

  bool _isAuthorized(CurrentUser user, InventoryExportFormat format) {
    return switch (format) {
      InventoryExportFormat.csv => InventoryExportPolicy.canExportCsv(user),
      InventoryExportFormat.xlsx => InventoryExportPolicy.canExportXlsx(user),
      InventoryExportFormat.pdf => InventoryExportPolicy.canExportPdf(user),
    };
  }
}
