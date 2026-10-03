import 'package:flutter/foundation.dart';
import '../exceptions/inventory_exception.dart';

/// Supported data types for user-defined reusable custom inventory fields.
enum CustomFieldDataType {
  text,
  number,
  date,
  boolean,
  dropdown;

  static CustomFieldDataType? fromString(String value) {
    final normalized = value.trim().toLowerCase();
    for (final type in values) {
      if (type.name.toLowerCase() == normalized) {
        return type;
      }
    }
    return null;
  }
}

/// Domain model representing the definition of a user-defined custom field.
@immutable
class CustomFieldDefinition {
  final String id;
  final String key;
  final String label;
  final CustomFieldDataType dataType;
  final bool isRequired;
  final List<String> options;
  final String? defaultValue;
  final DateTime createdAt;
  final String createdBy;

  CustomFieldDefinition({
    required this.id,
    required this.key,
    required this.label,
    required this.dataType,
    this.isRequired = false,
    List<String> options = const [],
    this.defaultValue,
    DateTime? createdAt,
    this.createdBy = 'system',
  })  : options = List.unmodifiable(options),
        createdAt = createdAt ?? DateTime.now() {
    _validateDefinition();
  }

  void _validateDefinition() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Custom field ID cannot be blank.');
    }
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      throw ArgumentError.value(key, 'key', 'Custom field key cannot be blank.');
    }
    final validKeyRegex = RegExp(r'^[a-z0-9_]+$');
    if (!validKeyRegex.hasMatch(normalizedKey)) {
      throw ArgumentError.value(
        key,
        'key',
        'Custom field key must be lowercase alphanumeric with underscores only.',
      );
    }
    if (label.trim().isEmpty) {
      throw ArgumentError.value(
        label,
        'label',
        'Custom field label cannot be blank.',
      );
    }
    if (isReservedStandardKey(normalizedKey)) {
      throw ArgumentError.value(
        key,
        'key',
        'Custom field key "$normalizedKey" is reserved for standard fields.',
      );
    }
    if (dataType == CustomFieldDataType.dropdown) {
      if (options.isEmpty || options.every((o) => o.trim().isEmpty)) {
        throw ArgumentError.value(
          options,
          'options',
          'Dropdown custom field must provide at least one valid non-empty option.',
        );
      }
    }
    if (defaultValue != null && defaultValue!.isNotEmpty) {
      // Validate that defaultValue matches the dataType
      validateValue(defaultValue);
    }
  }

  /// Evaluates whether [key] conflicts with any reserved standard inventory field.
  static bool isReservedStandardKey(String key) {
    return _reservedStandardKeys.contains(key.trim().toLowerCase());
  }

  static const Set<String> _reservedStandardKeys = {
    'id',
    'sku',
    'product_name',
    'productname',
    'name',
    'category',
    'brand',
    'unit',
    'barcode',
    'warehouse',
    'bin_location',
    'binlocation',
    'supplier',
    'unit_cost_inr',
    'unitcostinr',
    'unit_cost',
    'unitcost',
    'cost',
    'selling_price_inr',
    'sellingpriceinr',
    'selling_price',
    'sellingprice',
    'price',
    'stock_quantity',
    'stockquantity',
    'current_quantity',
    'quantity',
    'reorder_level',
    'reorderlevel',
    'max_stock',
    'maxstock',
    'gst_percent',
    'gstpercent',
    'gst',
    'batch_number',
    'batchnumber',
    'batch',
    'expiry_date',
    'expirydate',
    'last_restocked_date',
    'lastrestockeddate',
    'is_active',
    'isactive',
    'expected_stock_status',
    'expectedstockstatus',
    'stock_status',
    'status',
    'notes',
    'custom_fields',
    'customfields',
  };

  /// Validates and normalizes [value] against this definition's [dataType].
  ///
  /// Throws [InventoryValidationException] if the value fails type or constraint checks.
  dynamic validateValue(dynamic value) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      if (isRequired) {
        throw InventoryValidationException(
          'Custom field "$label" is required.',
        );
      }
      return null;
    }

    switch (dataType) {
      case CustomFieldDataType.text:
        return value.toString().trim();

      case CustomFieldDataType.number:
        if (value is num) {
          if (!value.toDouble().isFinite) {
            throw InventoryValidationException(
              'Custom field "$label" must be a finite number.',
            );
          }
          return value.toDouble();
        }
        if (value is String) {
          final parsed = double.tryParse(value.trim());
          if (parsed == null || !parsed.isFinite) {
            throw InventoryValidationException(
              'Invalid numeric value for custom field "$label": "$value".',
            );
          }
          return parsed;
        }
        throw InventoryValidationException(
          'Invalid numeric type for custom field "$label".',
        );

      case CustomFieldDataType.date:
        if (value is DateTime) {
          return value;
        }
        if (value is String) {
          final parsed = DateTime.tryParse(value.trim());
          if (parsed == null) {
            throw InventoryValidationException(
              'Invalid date format for custom field "$label": "$value". Expected ISO-8601.',
            );
          }
          return parsed;
        }
        throw InventoryValidationException(
          'Invalid date type for custom field "$label".',
        );

      case CustomFieldDataType.boolean:
        if (value is bool) {
          return value;
        }
        if (value is String) {
          final lower = value.trim().toLowerCase();
          if (lower == 'true' || lower == '1' || lower == 'yes') return true;
          if (lower == 'false' || lower == '0' || lower == 'no') return false;
          throw InventoryValidationException(
            'Invalid boolean value for custom field "$label": "$value".',
          );
        }
        if (value is num) {
          if (value == 1) return true;
          if (value == 0) return false;
        }
        throw InventoryValidationException(
          'Invalid boolean type for custom field "$label".',
        );

      case CustomFieldDataType.dropdown:
        final str = value.toString().trim();
        final matched = options.firstWhere(
          (opt) => opt.trim().toLowerCase() == str.toLowerCase(),
          orElse: () => '',
        );
        if (matched.isEmpty) {
          throw InventoryValidationException(
            'Value "$str" is not a valid option for dropdown "$label". Options: ${options.join(', ')}.',
          );
        }
        return matched;
    }
  }

  CustomFieldDefinition copyWith({
    String? id,
    String? key,
    String? label,
    CustomFieldDataType? dataType,
    bool? isRequired,
    List<String>? options,
    String? defaultValue,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return CustomFieldDefinition(
      id: id ?? this.id,
      key: key ?? this.key,
      label: label ?? this.label,
      dataType: dataType ?? this.dataType,
      isRequired: isRequired ?? this.isRequired,
      options: options ?? this.options,
      defaultValue: defaultValue ?? this.defaultValue,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomFieldDefinition &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          key == other.key &&
          label == other.label &&
          dataType == other.dataType &&
          isRequired == other.isRequired &&
          listEquals(options, other.options) &&
          defaultValue == other.defaultValue &&
          createdAt == other.createdAt &&
          createdBy == other.createdBy;

  @override
  int get hashCode => Object.hash(
        id,
        key,
        label,
        dataType,
        isRequired,
        Object.hashAll(options),
        defaultValue,
        createdAt,
        createdBy,
      );

  @override
  String toString() =>
      'CustomFieldDefinition(id: $id, key: $key, label: $label, dataType: $dataType, isRequired: $isRequired)';
}
