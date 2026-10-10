import 'dart:typed_data';

import '../../../auth/domain/entities/current_user.dart';
import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_export_artifact.dart';
import '../../domain/entities/inventory_export_fields.dart';
import '../../domain/entities/inventory_query.dart';
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
        _pdfSerializer = pdfSerializer ?? const InventoryPdfSerializer();

  /// Prepares an export artifact after strictly verifying format authorization,
  /// field-level access, record scope, and live session continuity.
  Future<InventoryExportArtifact> prepareExport({
    required InventoryExportFormat format,
    required CurrentUser initialUser,
    required CurrentUser? Function() currentUserProvider,
    InventoryExportScope scope = InventoryExportScope.all,
    InventoryExportPreset preset = InventoryExportPreset.allDetails,
    List<String>? columns,
    InventoryQuery? query,
    Set<String>? selectedItemIds,
    List<CustomFieldDefinition>? customFieldDefinitions,
    PdfLayoutOrientation orientation = PdfLayoutOrientation.auto,
  }) async {
    // 1. Initial format authorization check
    if (!_isAuthorized(initialUser, format)) {
      throw const InventoryExportException(
        'User is not authorized to export in this format.',
      );
    }

    final initialUserId = initialUser.id;

    // Resolve column list based on preset
    List<String> effectiveColumns;
    if (preset == InventoryExportPreset.legacyThreeColumn) {
      effectiveColumns = InventoryExportFields.legacyHeaders;
    } else if (preset == InventoryExportPreset.allDetails) {
      final permitted = InventoryExportFields.getAllPermittedColumns(
        user: initialUser,
        customFieldDefinitions: customFieldDefinitions,
        extraCustomKeys: columns,
      );
      effectiveColumns = (columns != null && columns.isNotEmpty)
          ? columns
              .where((c) =>
                  permitted.contains(c) ||
                  permitted.contains(InventoryExportFields.normalizeKey(c)))
              .toList()
          : permitted;
      if (effectiveColumns.isEmpty) {
        effectiveColumns = permitted;
      }
    } else {
      if (columns == null || columns.isEmpty) {
        throw const InventoryExportException('No export columns selected.');
      }
      if (columns.toSet().length != columns.length) {
        throw const InventoryExportException('Duplicate export columns are not permitted.');
      }
      for (final col in columns) {
        if (!InventoryExportFields.isValidKey(col, customFieldDefinitions: customFieldDefinitions)) {
          throw InventoryExportException('Unknown export column: $col');
        }
        if (InventoryExportPolicy.isRestrictedField(col) &&
            !InventoryExportPolicy.canExportField(initialUser, col)) {
          throw InventoryExportException('Unauthorized field requested: $col');
        }
      }
      effectiveColumns = List.unmodifiable(columns);
    }

    // Selected scope validation
    if (scope == InventoryExportScope.selected &&
        (selectedItemIds == null || selectedItemIds.isEmpty)) {
      throw const InventoryExportException('No items selected for export.');
    }

    // 2. Load dataset across pages or resolved IDs
    final items = await _dataLoader.loadItems(
      scope: scope,
      query: query,
      selectedItemIds: selectedItemIds,
    );

    // Discover any custom fields saved on items when exporting all details
    if (preset == InventoryExportPreset.allDetails) {
      final discoveredCustomKeys = <String>{};
      for (final s in items) {
        discoveredCustomKeys.addAll(s.item.customFields.keys);
      }
      if (discoveredCustomKeys.isNotEmpty) {
        final merged = List<String>.from(effectiveColumns);
        for (final k in discoveredCustomKeys) {
          if (!merged.contains(k) && !merged.contains(InventoryExportFields.normalizeKey(k))) {
            merged.add(k);
          }
        }
        effectiveColumns = List.unmodifiable(merged);
      }
    }

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

    // Verify field-level permissions were not revoked
    for (final col in effectiveColumns) {
      if (InventoryExportPolicy.isRestrictedField(col) &&
          !InventoryExportPolicy.canExportField(revalidatedUser, col)) {
        throw InventoryExportException(
          'Field authorization revoked during export preparation: $col',
        );
      }
    }

    // 4. Serialize bytes based on format
    final Uint8List bytes = switch (format) {
      InventoryExportFormat.csv => _csvSerializer.convertToBytes(
          items,
          columns: effectiveColumns,
          customFieldDefinitions: customFieldDefinitions,
          isLegacy: preset == InventoryExportPreset.legacyThreeColumn,
        ),
      InventoryExportFormat.xlsx => _xlsxSerializer.convertToBytes(
          items,
          columns: effectiveColumns,
          customFieldDefinitions: customFieldDefinitions,
          isLegacy: preset == InventoryExportPreset.legacyThreeColumn,
        ),
      InventoryExportFormat.pdf => _pdfSerializer.convertToBytes(
          items,
          columns: effectiveColumns,
          customFieldDefinitions: customFieldDefinitions,
          isLegacy: preset == InventoryExportPreset.legacyThreeColumn,
          scope: scope,
          orientation: orientation,
        ),
    };

    // 5. Package into artifact
    return InventoryExportArtifact(
      bytes: bytes,
      format: format,
      itemCount: items.length,
      columns: effectiveColumns,
      scope: scope,
      preset: preset,
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
