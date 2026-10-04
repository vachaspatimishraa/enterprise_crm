import 'dart:convert';

import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_pdf_serializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const serializer = InventoryPdfSerializer();

  InventoryItemSummary summary({
    String name = 'Wireless Mouse',
    String sku = 'ELE-0002',
    double quantity = 19,
  }) {
    return InventoryItemSummary(
      item: InventoryItem(id: sku, name: name, sku: sku),
      quantityOnHand: quantity,
    );
  }

  group('InventoryPdfSerializer', () {
    test('creates a valid PDF with the frozen three-column schema', () {
      final bytes = serializer.convertToBytes([
        summary(),
        summary(name: 'Cable (2m)', sku: r'SKU\\01', quantity: 2.5),
      ]);
      final text = ascii.decode(bytes);

      expect(text, startsWith('%PDF-1.4'));
      expect(text, contains('/Type /Catalog'));
      expect(text, contains('/Type /Page'));
      expect(text, contains('Item Name'));
      expect(text, contains('Current Quantity'));
      expect(text, contains('Wireless Mouse'));
      expect(text, contains('2.5'));
      expect(text, endsWith('%%EOF\n'));
    });

    test('empty export still contains the header row', () {
      final text = ascii.decode(serializer.convertToBytes(const []));

      expect(text, contains('Inventory Export'));
      expect(text, contains('Item Name'));
      expect(text, contains('SKU'));
      expect(text, contains('Current Quantity'));
    });

    test('rejects non-finite quantities', () {
      expect(
        () => serializer.convertToBytes([
          summary(quantity: double.infinity),
        ]),
        throwsA(isA<InventoryPdfSerializerException>()),
      );
    });

    test('sanitizes unsupported characters and escapes PDF delimiters', () {
      final text = ascii.decode(
        serializer.convertToBytes([
          summary(name: 'Café (Blue)', sku: 'SKU-हिन्दी'),
        ]),
      );

      expect(text, contains(r'Caf? \(Blue\)'));
      expect(text, contains('SKU-??????'));
    });

    test('splits large inventories across pages', () {
      final items = List.generate(41, (index) => summary(sku: 'SKU-$index'));
      final text = ascii.decode(serializer.convertToBytes(items));

      expect(RegExp(r'/Type /Page\b').allMatches(text).length, 2);
      expect(text, contains('SKU-40'));
    });
  });
}
