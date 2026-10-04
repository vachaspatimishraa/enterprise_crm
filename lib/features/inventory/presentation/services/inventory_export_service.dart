import '../../../auth/domain/entities/current_user.dart';
import '../../domain/entities/inventory_export_artifact.dart';
import '../../domain/policies/inventory_export_policy.dart';
import 'inventory_csv_serializer.dart';
import 'inventory_export_data_loader.dart';
import 'inventory_pdf_serializer.dart';
import 'inventory_xlsx_serializer.dart';

/// Exception thrown when authorized inventory export preparation fails.
class InventoryExportException implements Exception {
  final String message;
  const InventoryExportException(this.message);

  @override
  String toString() => 'InventoryExportException: $message';
}

/// Service orchestrating authorized data loading and format serialization for Inventory Export.
class InventoryExportService {
  final InventoryExportDataLoader _dataLoader;
  final InventoryCsvSerializer _csvSerializer;
  final InventoryXlsxSerializer _xlsxSerializer;
  final InventoryPdfSerializer _pdfSerializer;

  InventoryExportService({
    required InventoryExportDataLoader dataLoader,
    InventoryCsvSerializer? csvSerializer,
    InventoryXlsxSerializer? xlsxSerializer,
    InventoryPdfSerializer? pdfSerializer,
  })  : _dataLoader = dataLoader,
        _csvSerializer = csvSerializer ?? const InventoryCsvSerializer(),
        _xlsxSerializer = xlsxSerializer ?? InventoryXlsxSerializer(),
        _pdfSerializer = pdfSerializer ?? InventoryPdfSerializer();

  /// Orchestrates export preparation with dual authorization boundaries.
  ///
  /// 1. Validates initial authorization for [format] using [initialUser].
  /// 2. Loads complete active inventory dataset through [_dataLoader].
  /// 3. Revalidates authorization using [currentUserProvider] to detect identity changes,
  ///    sign-out, or permission revocation during loading.
  /// 4. Serializes records using [InventoryCsvSerializer] or [InventoryXlsxSerializer].
  /// 5. Returns an immutable [InventoryExportArtifact].
  Future<InventoryExportArtifact> prepareExport({
    required InventoryExportFormat format,
    required CurrentUser initialUser,
    required CurrentUser? Function() currentUserProvider,
  }) async {
    // 1. Initial authorization check before accessing repository data
    if (!_isAuthorized(initialUser, format)) {
      throw const InventoryExportException(
        'User is not authorized for this export format.',
      );
    }

    final initialUserId = initialUser.id;

    // 2. Load dataset across pages
    final items = await _dataLoader.loadAllItems();

    // 3. Revalidation check after async operation
    final revalidatedUser = currentUserProvider();
    if (revalidatedUser == null) {
      throw const InventoryExportException(
        'User session expired during export preparation.',
      );
    }

    if (revalidatedUser.id != initialUserId) {
      throw const InventoryExportException(
        'User identity changed during export preparation.',
      );
    }

    if (!_isAuthorized(revalidatedUser, format)) {
      throw const InventoryExportException(
        'Export authorization revoked during export preparation.',
      );
    }

    // 4. Serialize bytes based on format
    final bytes = switch (format) {
      InventoryExportFormat.csv => _csvSerializer.convertToBytes(items),
      InventoryExportFormat.xlsx => _xlsxSerializer.convertToBytes(items),
      InventoryExportFormat.pdf => _pdfSerializer.convertToBytes(items),
    };

    // 5. Package into artifact
    return InventoryExportArtifact(
      bytes: bytes,
      format: format,
      itemCount: items.length,
    );
  }

  bool _isAuthorized(CurrentUser? user, InventoryExportFormat format) {
    if (user == null) return false;
    return switch (format) {
      InventoryExportFormat.csv => InventoryExportPolicy.canExportCsv(user),
      InventoryExportFormat.xlsx => InventoryExportPolicy.canExportXlsx(user),
      InventoryExportFormat.pdf => InventoryExportPolicy.canExportPdf(user),
    };
  }
}
