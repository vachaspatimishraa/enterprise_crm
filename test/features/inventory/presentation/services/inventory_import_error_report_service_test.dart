import 'dart:convert';

import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_error_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'creates a CSV report with source row, SKU, and formula-safe error text',
    () {
      const service = InventoryImportErrorReportService();
      final bytes = service.toBytes([
        const InventoryImportRowFailure(
          sourceRowNumber: 7,
          sku: '=DANGEROUS',
          reason: '@invalid quantity',
        ),
      ]);

      final csv = utf8.decode(bytes);
      expect(csv, contains('Source Row,SKU,Error'));
      expect(csv, contains("'=DANGEROUS"));
      expect(csv, contains("'@invalid quantity"));
      expect(csv, contains('7'));
    },
  );
}
