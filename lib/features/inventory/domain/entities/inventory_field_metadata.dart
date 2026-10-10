import 'package:flutter/foundation.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../policies/inventory_field_access_policy.dart';

/// Metadata definition describing an inventory field, its sensitivity, and authorization requirements.
@immutable
class InventoryFieldMetadata {
  final String key;
  final String label;
  final String dataTypeDescription;
  final bool isRequired;
  final bool isSensitive;
  final bool isDerived;
  final String? requiredPermission;

  const InventoryFieldMetadata({
    required this.key,
    required this.label,
    required this.dataTypeDescription,
    this.isRequired = false,
    this.isSensitive = false,
    this.isDerived = false,
    this.requiredPermission,
  });

  /// Evaluates whether [user] is authorized to view this field.
  bool canView(CurrentUser? user) {
    if (!isSensitive) {
      return true;
    }
    if (requiredPermission == InventoryFieldAccessPolicy.costViewPermission) {
      return InventoryFieldAccessPolicy.canViewCost(user);
    }
    if (requiredPermission == InventoryFieldAccessPolicy.supplierViewPermission) {
      return InventoryFieldAccessPolicy.canViewSupplier(user);
    }
    return user != null && user.isAdmin;
  }

  /// All 21 standard inventory fields in canonical workbook order.
  static const List<InventoryFieldMetadata> allStandardFields = [
    InventoryFieldMetadata(
      key: 'sku',
      label: 'SKU',
      dataTypeDescription: 'Text',
      isRequired: true,
    ),
    InventoryFieldMetadata(
      key: 'product_name',
      label: 'Product Name',
      dataTypeDescription: 'Text',
      isRequired: true,
    ),
    InventoryFieldMetadata(
      key: 'category',
      label: 'Category',
      dataTypeDescription: 'Taxonomy',
      isRequired: true,
    ),
    InventoryFieldMetadata(
      key: 'brand',
      label: 'Brand',
      dataTypeDescription: 'Text',
    ),
    InventoryFieldMetadata(
      key: 'unit',
      label: 'Unit of Measure',
      dataTypeDescription: 'Taxonomy',
      isRequired: true,
    ),
    InventoryFieldMetadata(
      key: 'barcode',
      label: 'Barcode',
      dataTypeDescription: 'Text (EAN/UPC)',
    ),
    InventoryFieldMetadata(
      key: 'warehouse',
      label: 'Warehouse',
      dataTypeDescription: 'Location Code',
      isRequired: true,
    ),
    InventoryFieldMetadata(
      key: 'bin_location',
      label: 'Bin Location',
      dataTypeDescription: 'Text',
    ),
    InventoryFieldMetadata(
      key: 'supplier',
      label: 'Supplier',
      dataTypeDescription: 'Text',
      isSensitive: true,
      requiredPermission: InventoryFieldAccessPolicy.supplierViewPermission,
    ),
    InventoryFieldMetadata(
      key: 'unit_cost_inr',
      label: 'Unit Cost (INR)',
      dataTypeDescription: 'Currency (Decimal)',
      isSensitive: true,
      requiredPermission: InventoryFieldAccessPolicy.costViewPermission,
    ),
    InventoryFieldMetadata(
      key: 'selling_price_inr',
      label: 'Selling Price (INR)',
      dataTypeDescription: 'Currency (Decimal)',
    ),
    InventoryFieldMetadata(
      key: 'stock_quantity',
      label: 'Stock Quantity',
      dataTypeDescription: 'Quantity (Derived from Movement Ledger)',
      isRequired: true,
      isDerived: true,
    ),
    InventoryFieldMetadata(
      key: 'reorder_level',
      label: 'Reorder Level',
      dataTypeDescription: 'Quantity',
    ),
    InventoryFieldMetadata(
      key: 'max_stock',
      label: 'Max Stock',
      dataTypeDescription: 'Quantity',
    ),
    InventoryFieldMetadata(
      key: 'gst_percent',
      label: 'GST (%)',
      dataTypeDescription: 'Percentage',
    ),
    InventoryFieldMetadata(
      key: 'batch_number',
      label: 'Batch Number',
      dataTypeDescription: 'Text',
    ),
    InventoryFieldMetadata(
      key: 'expiry_date',
      label: 'Expiry Date',
      dataTypeDescription: 'Date (ISO-8601)',
    ),
    InventoryFieldMetadata(
      key: 'last_restocked_date',
      label: 'Last Restocked Date',
      dataTypeDescription: 'Date (ISO-8601)',
    ),
    InventoryFieldMetadata(
      key: 'is_active',
      label: 'Is Active',
      dataTypeDescription: 'Boolean',
      isRequired: true,
    ),
    InventoryFieldMetadata(
      key: 'expected_stock_status',
      label: 'Stock Status',
      dataTypeDescription: 'Status Enum (Derived)',
      isRequired: true,
      isDerived: true,
    ),
    InventoryFieldMetadata(
      key: 'notes',
      label: 'Notes',
      dataTypeDescription: 'Text',
    ),
  ];

  static InventoryFieldMetadata? findByKey(String key) {
    final normalized = key.trim().toLowerCase();
    for (final field in allStandardFields) {
      if (field.key == normalized ||
          (field.key == 'product_name' && normalized == 'name')) {
        return field;
      }
    }
    return null;
  }
}
