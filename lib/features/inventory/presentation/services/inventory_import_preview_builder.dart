import '../../domain/entities/inventory_import_models.dart';
import 'inventory_import_parser.dart';

/// Builder responsible for converting mapped spreadsheet sheet rows into
/// validated preview rows with duplicate and constraint checks.
class InventoryImportPreviewBuilder {
  const InventoryImportPreviewBuilder();

  /// Builds an [InventoryImportPreview] by analyzing non-blank rows after [mapping.headerRowIndex].
  InventoryImportPreview build({
    required InventoryImportParsedSheet sheet,
    required InventoryImportColumnMapping mapping,
    required Set<String> existingSkus,
  }) {
    final candidateRows = <InventoryImportPreviewRow>[];

    for (var i = mapping.headerRowIndex + 1; i < sheet.rows.length; i++) {
      final rawRow = sheet.rows[i];
      // Skip completely blank rows without inflating totals or failures.
      final isCompletelyBlank = rawRow.every((cell) => cell.trim().isEmpty);
      if (isCompletelyBlank) continue;

      final sourceRowNumber = i + 1; // 1-indexed file row

      final rawName =
          mapping.nameColumnIndex != null &&
              mapping.nameColumnIndex! < rawRow.length
          ? rawRow[mapping.nameColumnIndex!]
          : '';
      final rawSku =
          mapping.skuColumnIndex != null &&
              mapping.skuColumnIndex! < rawRow.length
          ? rawRow[mapping.skuColumnIndex!]
          : '';
      final rawOpeningStock =
          mapping.openingStockColumnIndex != null &&
              mapping.openingStockColumnIndex! < rawRow.length
          ? rawRow[mapping.openingStockColumnIndex!]
          : '';

      final trimmedName = rawName.trim();
      final trimmedSku = rawSku.trim();
      final trimmedOpeningStock = rawOpeningStock.trim();

      String? errorMessage;
      var status = InventoryImportRowStatus.valid;
      double? openingStock;

      if (trimmedName.isEmpty) {
        status = InventoryImportRowStatus.invalid;
        errorMessage = 'Name is required.';
      } else if (trimmedSku.isEmpty) {
        status = InventoryImportRowStatus.invalid;
        errorMessage = 'SKU is required.';
      } else if (trimmedOpeningStock.isNotEmpty) {
        final parsed = double.tryParse(trimmedOpeningStock);
        if (parsed == null || !parsed.isFinite) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'Opening stock must be a valid number.';
        } else if (parsed <= 0) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'Opening stock must be greater than zero.';
        } else {
          openingStock = parsed;
        }
      }

      if (status == InventoryImportRowStatus.valid) {
        if (existingSkus.contains(trimmedSku.toLowerCase())) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'An inventory item with this SKU already exists.';
        }
      }

      candidateRows.add(
        InventoryImportPreviewRow(
          sourceRowNumber: sourceRowNumber,
          rawValues: rawRow,
          name: trimmedName,
          sku: trimmedSku,
          openingStock: openingStock,
          status: status,
          errorMessage: errorMessage,
          isSelected: status == InventoryImportRowStatus.valid,
        ),
      );
    }

    // Detect same-file SKU duplicates (case-insensitive) across candidate rows
    final skuCounts = <String, int>{};
    for (final row in candidateRows) {
      if (row.sku.isNotEmpty) {
        final norm = row.sku.toLowerCase();
        skuCounts[norm] = (skuCounts[norm] ?? 0) + 1;
      }
    }

    final finalizedRows = candidateRows
        .map((row) {
          if (row.sku.isNotEmpty &&
              (skuCounts[row.sku.toLowerCase()] ?? 0) > 1) {
            // ALL occurrences of same-file duplicate SKUs are marked duplicate and non-selectable
            return row.copyWith(
              status: InventoryImportRowStatus.duplicate,
              errorMessage: 'Duplicate SKU in file.',
              isSelected: false,
            );
          }
          return row;
        })
        .toList(growable: false);

    return InventoryImportPreview(rows: finalizedRows);
  }
}
