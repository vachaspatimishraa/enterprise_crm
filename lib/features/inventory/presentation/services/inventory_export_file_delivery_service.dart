import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../domain/entities/inventory_export_artifact.dart';
import '../../domain/policies/inventory_export_policy.dart';
import '../../domain/policies/inventory_import_policy.dart';

/// Status indicating the outcome of an inventory export file delivery attempt.
enum InventoryExportDeliveryStatus {
  saved,
  downloadInitiated,
  cancelled,
  restricted,
  failure,
}

/// Typed delivery result for inventory export file delivery.
class InventoryExportDeliveryResult {
  final InventoryExportDeliveryStatus status;
  final Uri? uri;
  final String? message;

  const InventoryExportDeliveryResult._({
    required this.status,
    this.uri,
    this.message,
  });

  const InventoryExportDeliveryResult.saved({Uri? uri})
    : this._(status: InventoryExportDeliveryStatus.saved, uri: uri);

  const InventoryExportDeliveryResult.downloadInitiated()
    : this._(status: InventoryExportDeliveryStatus.downloadInitiated);

  const InventoryExportDeliveryResult.cancelled({String? message})
    : this._(status: InventoryExportDeliveryStatus.cancelled, message: message);

  const InventoryExportDeliveryResult.restricted(String message)
    : this._(
        status: InventoryExportDeliveryStatus.restricted,
        message: message,
      );

  const InventoryExportDeliveryResult.failure(String message)
    : this._(status: InventoryExportDeliveryStatus.failure, message: message);

  bool get isSaved => status == InventoryExportDeliveryStatus.saved;
  bool get isDownloadInitiated =>
      status == InventoryExportDeliveryStatus.downloadInitiated;
  bool get isCancelled => status == InventoryExportDeliveryStatus.cancelled;
  bool get isRestricted => status == InventoryExportDeliveryStatus.restricted;
  bool get isFailure => status == InventoryExportDeliveryStatus.failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryExportDeliveryResult &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          uri == other.uri &&
          message == other.message;

  @override
  int get hashCode => Object.hash(status, uri, message);

  @override
  String toString() =>
      'InventoryExportDeliveryResult(status: $status, uri: $uri, message: $message)';
}

/// Abstract platform adapter for delivering/saving prepared file bytes.
abstract interface class InventoryExportFileSaver {
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
    String? dialogTitle,
  });
}

/// Default implementation of [InventoryExportFileSaver] using `package:file_picker`.
class DefaultInventoryExportFileSaver implements InventoryExportFileSaver {
  const DefaultInventoryExportFileSaver();

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
    String? dialogTitle = 'Save Inventory Export',
  }) {
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: [extension],
    );
  }
}

/// Service orchestrating secure platform delivery of prepared [InventoryExportArtifact]s.
class InventoryExportFileDeliveryService {
  final InventoryExportFileSaver _fileSaver;
  final bool _isWeb;
  bool _isDelivering = false;

  InventoryExportFileDeliveryService({
    InventoryExportFileSaver? fileSaver,
    bool? isWeb,
  }) : _fileSaver = fileSaver ?? const DefaultInventoryExportFileSaver(),
       _isWeb = isWeb ?? kIsWeb;

  /// Returns true if a delivery operation is actively in flight.
  bool get isDelivering => _isDelivering;

  /// Delivers [artifact] to the platform file saving or download mechanism.
  ///
  /// Immediately validates:
  /// 1. Concurrency: rejects duplicate simultaneous deliveries.
  /// 2. Authentication: verifies [currentUserProvider] yields an active user.
  /// 3. Identity binding: if [boundUserId] is supplied, verifies session identity matches.
  /// 4. Authorization: evaluates format-specific [InventoryExportPolicy].
  /// 5. Filename & format integrity: validates filename and extension.
  ///
  /// Then delegates exact artifact bytes to [_fileSaver] without repository reads or reserialization.
  Future<InventoryExportDeliveryResult> deliverArtifact({
    required InventoryExportArtifact artifact,
    required CurrentUser? Function() currentUserProvider,
    String? boundUserId,
    String? customFileName,
  }) async {
    // 1. Busy guard against duplicate simultaneous calls
    if (_isDelivering) {
      return const InventoryExportDeliveryResult.restricted(
        'A file delivery operation is already in progress.',
      );
    }

    _isDelivering = true;
    try {
      // 2. Authentication check
      final currentUser = currentUserProvider();
      if (currentUser == null) {
        return const InventoryExportDeliveryResult.restricted(
          'User session expired or unauthenticated.',
        );
      }

      // 3. User identity binding check (must match preparing user if bound)
      if (boundUserId != null && currentUser.id != boundUserId) {
        return const InventoryExportDeliveryResult.restricted(
          'User identity changed since export was prepared.',
        );
      }

      // 4. Authorization policy check immediately before delivery
      final isAuthorized = switch (artifact.format) {
        InventoryExportFormat.csv => InventoryExportPolicy.canExportCsv(
          currentUser,
        ),
        InventoryExportFormat.xlsx => InventoryExportPolicy.canExportXlsx(
          currentUser,
        ),
        InventoryExportFormat.pdf => InventoryExportPolicy.canExportPdf(
          currentUser,
        ),
      };

      if (!isAuthorized) {
        return const InventoryExportDeliveryResult.restricted(
          'User is not authorized to deliver this export format.',
        );
      }

      // 4b. Field-level authorization check immediately before delivery
      for (final col in artifact.columns) {
        if (InventoryExportPolicy.isRestrictedField(col) &&
            !InventoryExportPolicy.canExportField(currentUser, col)) {
          return const InventoryExportDeliveryResult.restricted(
            'User is not authorized to deliver this export configuration.',
          );
        }
      }

      // 5. Filename determination & safety validation
      final effectiveFileName =
          (customFileName != null && customFileName.trim().isNotEmpty)
          ? customFileName.trim()
          : artifact.defaultFileName();

      final validationError = _validateFileName(
        effectiveFileName,
        artifact.fileExtension,
      );
      if (validationError != null) {
        return InventoryExportDeliveryResult.failure(validationError);
      }

      // Extension without dot for picker allowedExtensions
      final cleanExtension = artifact.fileExtension.replaceFirst('.', '');

      // 6. Platform file save delegation
      final uri = await _fileSaver.saveFile(
        fileName: effectiveFileName,
        bytes: artifact.bytes,
        mimeType: artifact.mimeType,
        extension: cleanExtension,
        dialogTitle: 'Save Inventory Export',
      );

      // Web platform saveFile returns null or an opaque URI depending on browser download initiation
      if (_isWeb) {
        // On Web, FilePicker.saveFile triggers browser download anchor
        return const InventoryExportDeliveryResult.downloadInitiated();
      }

      if (uri == null) {
        return const InventoryExportDeliveryResult.cancelled(
          message: 'User cancelled export file saving.',
        );
      }

      return InventoryExportDeliveryResult.saved(uri: uri);
    } catch (e) {
      return InventoryExportDeliveryResult.failure(
        'Failed to deliver export file: $e',
      );
    } finally {
      _isDelivering = false;
    }
  }

  /// Delivers a CSV import error report for the currently authenticated
  /// importer. This intentionally checks import authorization rather than
  /// export authorization: users may need to retrieve validation failures even
  /// when they are not allowed to export the inventory catalog.
  Future<InventoryExportDeliveryResult> deliverImportErrorReport({
    required Uint8List bytes,
    required CurrentUser? Function() currentUserProvider,
    String? boundUserId,
    String fileName = 'inventory_import_errors.csv',
  }) async {
    if (_isDelivering) {
      return const InventoryExportDeliveryResult.restricted(
        'A file delivery operation is already in progress.',
      );
    }
    _isDelivering = true;
    try {
      final currentUser = currentUserProvider();
      if (currentUser == null) {
        return const InventoryExportDeliveryResult.restricted(
          'User session expired or unauthenticated.',
        );
      }
      if (boundUserId != null && currentUser.id != boundUserId) {
        return const InventoryExportDeliveryResult.restricted(
          'User identity changed since the import was processed.',
        );
      }
      if (!InventoryImportPolicy.canImport(currentUser)) {
        return const InventoryExportDeliveryResult.restricted(
          'User is not authorized to download import error reports.',
        );
      }
      final validationError = _validateFileName(fileName, '.csv');
      if (validationError != null) {
        return InventoryExportDeliveryResult.failure(validationError);
      }
      final uri = await _fileSaver.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'text/csv',
        extension: 'csv',
        dialogTitle: 'Save Inventory Import Error Report',
      );
      if (_isWeb)
        return const InventoryExportDeliveryResult.downloadInitiated();
      if (uri == null) {
        return const InventoryExportDeliveryResult.cancelled(
          message: 'User cancelled error report saving.',
        );
      }
      return InventoryExportDeliveryResult.saved(uri: uri);
    } catch (e) {
      return InventoryExportDeliveryResult.failure(
        'Failed to deliver import error report: $e',
      );
    } finally {
      _isDelivering = false;
    }
  }

  /// Validates that filename is safe, non-empty, contains no path traversals,
  /// and terminates with the expected format extension.
  String? _validateFileName(String fileName, String expectedExtension) {
    if (fileName.trim().isEmpty) {
      return 'Filename cannot be empty.';
    }
    if (fileName.contains('/') ||
        fileName.contains('\\') ||
        fileName.contains('..')) {
      return 'Filename cannot contain path traversal or separator characters.';
    }
    // Check for control characters
    for (var i = 0; i < fileName.length; i++) {
      final code = fileName.codeUnitAt(i);
      if (code < 32 || code == 127) {
        return 'Filename contains invalid control characters.';
      }
    }
    if (!fileName.toLowerCase().endsWith(expectedExtension.toLowerCase())) {
      return 'Filename extension must match $expectedExtension.';
    }
    return null;
  }
}
