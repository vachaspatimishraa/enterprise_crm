import '../../../auth/domain/entities/current_user.dart';
import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_catalogs.dart';
import '../../domain/entities/inventory_import_models.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/policies/inventory_import_policy.dart';
import 'inventory_import_parser.dart';

/// Builder responsible for converting mapped spreadsheet sheet rows into
/// validated preview rows with duplicate, catalog, and permission checks.
class InventoryImportPreviewBuilder {
  const InventoryImportPreviewBuilder();

  /// Builds an [InventoryImportPreview] by analyzing non-blank rows after [mapping.headerRowIndex].
  InventoryImportPreview build({
    required InventoryImportParsedSheet sheet,
    required InventoryImportColumnMapping mapping,
    required Set<String> existingSkus,
    CurrentUser? user,
    InventoryCatalogs? catalogs,
    List<CustomFieldDefinition>? customFieldDefinitions,
    Map<String, InventoryItem>? existingItemsBySku,
    DateTime? referenceDate,
  }) {
    final candidateRows = <InventoryImportPreviewRow>[];
    final allDefinitions = [
      if (customFieldDefinitions != null) ...customFieldDefinitions,
      ...mapping.stagedCustomFieldDefinitions,
    ];

    final refDate = referenceDate ?? DateTime(2026, 10, 3);

    for (var i = mapping.headerRowIndex + 1; i < sheet.rows.length; i++) {
      final rawRow = sheet.rows[i];
      // Skip completely blank rows without inflating totals or failures.
      final isCompletelyBlank = rawRow.every((cell) => cell.trim().isEmpty);
      if (isCompletelyBlank) continue;

      final sourceRowNumber = i + 1; // 1-indexed file row

      String getCell(int? colIdx) {
        if (colIdx != null && colIdx >= 0 && colIdx < rawRow.length) {
          return rawRow[colIdx].trim();
        }
        return '';
      }

      final rawName = getCell(mapping.getColumnFor(InventoryImportField.name));
      final rawSku = getCell(mapping.getColumnFor(InventoryImportField.sku));
      final rawCategory =
          getCell(mapping.getColumnFor(InventoryImportField.category));
      final rawBrand = getCell(mapping.getColumnFor(InventoryImportField.brand));
      final rawUnit = getCell(mapping.getColumnFor(InventoryImportField.unit));
      final rawBarcode =
          getCell(mapping.getColumnFor(InventoryImportField.barcode));
      final rawWarehouse =
          getCell(mapping.getColumnFor(InventoryImportField.warehouse));
      final rawBinLocation =
          getCell(mapping.getColumnFor(InventoryImportField.binLocation));
      final rawSupplier =
          getCell(mapping.getColumnFor(InventoryImportField.supplier));
      final rawUnitCost =
          getCell(mapping.getColumnFor(InventoryImportField.unitCostInr));
      final rawSellingPrice =
          getCell(mapping.getColumnFor(InventoryImportField.sellingPriceInr));
      final rawOpeningStock =
          getCell(mapping.getColumnFor(InventoryImportField.openingStock));
      final rawReorderLevel =
          getCell(mapping.getColumnFor(InventoryImportField.reorderLevel));
      final rawMaxStock =
          getCell(mapping.getColumnFor(InventoryImportField.maxStock));
      final rawGstPercent =
          getCell(mapping.getColumnFor(InventoryImportField.gstPercent));
      final rawBatchNumber =
          getCell(mapping.getColumnFor(InventoryImportField.batchNumber));
      final rawExpiryDate =
          getCell(mapping.getColumnFor(InventoryImportField.expiryDate));
      final rawLastRestockedDate =
          getCell(mapping.getColumnFor(InventoryImportField.lastRestockedDate));
      final rawIsActive =
          getCell(mapping.getColumnFor(InventoryImportField.isActive));
      final rawNotes = getCell(mapping.getColumnFor(InventoryImportField.notes));

      String? errorMessage;
      String? warningMessage;
      var status = InventoryImportRowStatus.valid;

      // 1. Mandatory SKU validation (INV-001, INV-016)
      if (rawSku.isEmpty) {
        status = InventoryImportRowStatus.invalid;
        errorMessage = 'SKU is required.';
      } else if (rawSku.length > 64) {
        status = InventoryImportRowStatus.invalid;
        errorMessage = 'Item SKU cannot exceed 64 characters.';
      }

      // 2. Mandatory Name validation (INV-009)
      if (status == InventoryImportRowStatus.valid && rawName.isEmpty) {
        status = InventoryImportRowStatus.invalid;
        errorMessage = 'Name is required.';
      } else if (status == InventoryImportRowStatus.valid &&
          rawName.length > 255) {
        status = InventoryImportRowStatus.invalid;
        errorMessage = 'Item name cannot exceed 255 characters.';
      }

      // 3. Planned Action and SKU duplicate/existence check
      final normSku = rawSku.toLowerCase();
      final existsInRepo = existingSkus.contains(normSku);
      InventoryImportAction action = InventoryImportAction.create;
      String? existingItemId;

      if (status == InventoryImportRowStatus.valid) {
        switch (mapping.importMode) {
          case InventoryImportMode.createOnly:
            if (existsInRepo) {
              status = InventoryImportRowStatus.invalid;
              errorMessage = 'An inventory item with this SKU already exists.';
            } else {
              action = InventoryImportAction.create;
            }
            break;

          case InventoryImportMode.updateOnly:
            if (!existsInRepo) {
              status = InventoryImportRowStatus.invalid;
              errorMessage =
                  'Item with SKU "$rawSku" does not exist in inventory.';
            } else {
              action = InventoryImportAction.update;
              if (existingItemsBySku != null &&
                  existingItemsBySku.containsKey(normSku)) {
                existingItemId = existingItemsBySku[normSku]!.id;
              }
            }
            break;

          case InventoryImportMode.createAndUpdate:
            if (existsInRepo) {
              action = InventoryImportAction.update;
              if (existingItemsBySku != null &&
                  existingItemsBySku.containsKey(normSku)) {
                existingItemId = existingItemsBySku[normSku]!.id;
              }
            } else {
              action = InventoryImportAction.create;
            }
            break;
        }
      }

      // 4. Opening Stock validation
      double? openingStock;
      if (rawOpeningStock.isNotEmpty) {
        final parsed = double.tryParse(rawOpeningStock);
        if (action == InventoryImportAction.update) {
          if (parsed != null && parsed.isFinite) {
            openingStock = parsed;
          }
          warningMessage =
              'Stock quantity cannot be overwritten via bulk update; balance preserved.';
        } else if (status == InventoryImportRowStatus.valid) {
          if (parsed == null || !parsed.isFinite) {
            status = InventoryImportRowStatus.invalid;
            errorMessage = 'Opening stock must be a valid number.';
          } else if (parsed < 0) {
            status = InventoryImportRowStatus.invalid;
            errorMessage = 'Opening stock cannot be negative.';
          } else {
            openingStock = parsed;
          }
        }
      }

      // 4. Catalog validations if catalogs provided
      if (status == InventoryImportRowStatus.valid && catalogs != null) {
        if (rawCategory.isNotEmpty && !catalogs.isValidCategory(rawCategory)) {
          status = InventoryImportRowStatus.invalid;
          errorMessage =
              'Category "$rawCategory" is not recognized in the configured catalog.';
        } else if (rawUnit.isNotEmpty && !catalogs.isValidUnit(rawUnit)) {
          status = InventoryImportRowStatus.invalid;
          errorMessage =
              'Unit "$rawUnit" is not recognized in the configured catalog.';
        } else if (rawWarehouse.isNotEmpty &&
            !catalogs.isValidWarehouse(rawWarehouse)) {
          status = InventoryImportRowStatus.invalid;
          errorMessage =
              'Warehouse "$rawWarehouse" is not recognized in the configured catalog.';
        }
      }

      // 5. Barcode validation (INV-005, INV-016)
      if (status == InventoryImportRowStatus.valid && rawBarcode.isNotEmpty) {
        if (rawBarcode.length == 13 &&
            !RegExp(r'^\d{13}$').hasMatch(rawBarcode)) {
          status = InventoryImportRowStatus.invalid;
          errorMessage =
              '13-character barcode "$rawBarcode" must consist of numeric digits only.';
        }
      }

      // 6. Cost & Price validation (INV-004)
      double? unitCost;
      if (status == InventoryImportRowStatus.valid && rawUnitCost.isNotEmpty) {
        final parsed = double.tryParse(rawUnitCost);
        if (parsed == null || !parsed.isFinite) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'Unit cost must be a finite number.';
        } else if (parsed < 0) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'Unit cost cannot be below zero.';
        } else {
          unitCost = parsed;
        }
      }

      double? sellingPrice;
      if (status == InventoryImportRowStatus.valid &&
          rawSellingPrice.isNotEmpty) {
        final parsed = double.tryParse(rawSellingPrice);
        if (parsed == null || !parsed.isFinite) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'Selling price must be a finite number.';
        } else if (parsed < 0) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'Selling price cannot be below zero.';
        } else {
          sellingPrice = parsed;
        }
      }

      // 7. Thresholds validation (INV-012, INV-013)
      double? reorderLevel;
      if (status == InventoryImportRowStatus.valid &&
          rawReorderLevel.isNotEmpty) {
        final parsed = double.tryParse(rawReorderLevel);
        if (parsed == null || !parsed.isFinite) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'Reorder level must be a finite number.';
        } else if (parsed < 0) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'Reorder level cannot be negative.';
        } else {
          reorderLevel = parsed;
        }
      }

      double? maxStock;
      if (status == InventoryImportRowStatus.valid && rawMaxStock.isNotEmpty) {
        final parsed = double.tryParse(rawMaxStock);
        if (parsed == null || !parsed.isFinite) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'Max stock must be a finite number.';
        } else if (parsed < 0) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'Max stock cannot be negative.';
        } else if (reorderLevel != null && parsed < reorderLevel) {
          status = InventoryImportRowStatus.invalid;
          errorMessage =
              'Max stock ($parsed) cannot be lower than reorder level ($reorderLevel).';
        } else {
          maxStock = parsed;
        }
      }

      // 8. GST percent
      double? gstPercent;
      if (status == InventoryImportRowStatus.valid && rawGstPercent.isNotEmpty) {
        final parsed = double.tryParse(rawGstPercent);
        if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > 100) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'GST percent must be between 0.0 and 100.0.';
        } else {
          gstPercent = parsed;
        }
      }

      // 9. Dates & Expired Lot check (INV-006, INV-014)
      DateTime? expiryDate;
      if (status == InventoryImportRowStatus.valid && rawExpiryDate.isNotEmpty) {
        final parsed = DateTime.tryParse(rawExpiryDate);
        if (parsed == null) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'Invalid Expiry Date format: "$rawExpiryDate".';
        } else {
          expiryDate = parsed;
          if (parsed.isBefore(refDate)) {
            warningMessage =
                'Expired lot warning: Expiry date ($rawExpiryDate) is in the past.';
          }
        }
      }

      DateTime? lastRestockedDate;
      if (status == InventoryImportRowStatus.valid &&
          rawLastRestockedDate.isNotEmpty) {
        final parsed = DateTime.tryParse(rawLastRestockedDate);
        if (parsed == null) {
          status = InventoryImportRowStatus.invalid;
          errorMessage =
              'Invalid Last Restocked Date format: "$rawLastRestockedDate".';
        } else {
          lastRestockedDate = parsed;
        }
      }

      // 10. Notes length
      if (status == InventoryImportRowStatus.valid && rawNotes.length > 1000) {
        status = InventoryImportRowStatus.invalid;
        errorMessage = 'Notes cannot exceed 1000 characters.';
      }

      // 11. Custom fields evaluation
      final customFields = <String, dynamic>{};
      if (status == InventoryImportRowStatus.valid) {
        for (final entry in mapping.customFieldMappings.entries) {
          final colIdx = entry.key;
          final defKey = entry.value;
          final rawVal = getCell(colIdx);
          final def = allDefinitions.firstWhere(
            (d) => d.key == defKey,
            orElse: () => CustomFieldDefinition(
              id: 'custom_$defKey',
              key: defKey,
              label: defKey,
              dataType: CustomFieldDataType.text,
            ),
          );

          if (rawVal.isEmpty) {
            if (def.isRequired) {
              status = InventoryImportRowStatus.invalid;
              errorMessage = 'Custom field "${def.label}" is required.';
              break;
            }
          } else {
            try {
              final validatedVal = def.validateValue(rawVal);
              if (validatedVal != null) {
                customFields[def.key] = validatedVal;
              }
            } catch (e) {
              status = InventoryImportRowStatus.invalid;
              errorMessage = 'Custom field "${def.label}": $e';
              break;
            }
          }
        }
      }

      // Planned Action already evaluated in step 3

      // 13. Operation permissions per row
      if (status == InventoryImportRowStatus.valid && user != null) {
        if (action == InventoryImportAction.create &&
            !InventoryImportPolicy.canCreate(user)) {
          status = InventoryImportRowStatus.invalid;
          errorMessage =
              'You do not have permission to create inventory items.';
        } else if (action == InventoryImportAction.update &&
            !InventoryImportPolicy.canEdit(user)) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'You do not have permission to edit inventory items.';
        } else if (action == InventoryImportAction.create &&
            openingStock != null &&
            openingStock > 0 &&
            !InventoryImportPolicy.canImportWithStock(user)) {
          status = InventoryImportRowStatus.invalid;
          errorMessage = 'You do not have permission to manage opening stock.';
        }
      }

      // Sensitive field masking in preview for display
      final isCostMasked =
          user != null && !InventoryImportPolicy.canViewCost(user);
      final isSupplierMasked =
          user != null && !InventoryImportPolicy.canViewSupplier(user);

      final mappedValues = <String, dynamic>{
        'name': rawName,
        'sku': rawSku,
        'category': rawCategory.isNotEmpty ? rawCategory : null,
        'brand': rawBrand.isNotEmpty ? rawBrand : null,
        'unit': rawUnit.isNotEmpty ? rawUnit : null,
        'barcode': rawBarcode.isNotEmpty ? rawBarcode : null,
        'warehouse': rawWarehouse.isNotEmpty ? rawWarehouse : null,
        'binLocation': rawBinLocation.isNotEmpty ? rawBinLocation : null,
        'supplier': isSupplierMasked
            ? null
            : (rawSupplier.isNotEmpty ? rawSupplier : null),
        'unitCostInr': isCostMasked ? null : unitCost,
        'sellingPriceInr': sellingPrice,
        'openingStock': openingStock,
        'reorderLevel': reorderLevel,
        'maxStock': maxStock,
        'gstPercent': gstPercent,
        'batchNumber': rawBatchNumber.isNotEmpty ? rawBatchNumber : null,
        'expiryDate': expiryDate,
        'lastRestockedDate': lastRestockedDate,
        'isActive': rawIsActive.isNotEmpty
            ? (rawIsActive == '1' ||
                rawIsActive.toLowerCase() == 'true' ||
                rawIsActive.toLowerCase() == 'yes')
            : true,
        'notes': rawNotes.isNotEmpty ? rawNotes : null,
        'customFields': customFields,
      };

      if (status == InventoryImportRowStatus.valid && warningMessage != null) {
        status = InventoryImportRowStatus.warning;
      }

      candidateRows.add(
        InventoryImportPreviewRow(
          sourceRowNumber: sourceRowNumber,
          rawValues: rawRow,
          name: rawName,
          sku: rawSku,
          openingStock: openingStock,
          status: status,
          errorMessage: errorMessage,
          warningMessage: warningMessage,
          isSelected: status == InventoryImportRowStatus.valid ||
              status == InventoryImportRowStatus.warning,
          action: action,
          mappedValues: mappedValues,
          existingItemId: existingItemId,
        ),
      );
    }

    // 14. Same-file duplicate SKU detection
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
