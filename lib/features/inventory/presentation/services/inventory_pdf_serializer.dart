import 'dart:convert';
import 'dart:typed_data';

import '../../domain/entities/inventory_item_summary.dart';

/// Exception thrown when PDF export serialization fails.
class InventoryPdfSerializerException implements Exception {
  const InventoryPdfSerializerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Creates a dependency-free, printable PDF report using the frozen Inventory
/// export schema: Item Name, SKU, and Current Quantity.
///
/// The serializer deliberately uses only PDF built-in fonts so it works on
/// Flutter Web and mobile without bundling or licensing a font asset. Characters
/// outside PDF's built-in Helvetica character set are replaced with `?`.
class InventoryPdfSerializer {
  const InventoryPdfSerializer();

  static const String headerName = 'Item Name';
  static const String headerSku = 'SKU';
  static const String headerQuantity = 'Current Quantity';

  static const double _pageWidth = 595;
  static const double _pageHeight = 842;
  static const double _leftMargin = 36;
  static const double _topMargin = 806;
  static const double _rowHeight = 18;
  static const int _maxNameChars = 38;
  static const int _maxSkuChars = 26;
  static const int _maxQuantityChars = 18;

  /// Converts Inventory summaries into a valid multi-page PDF byte array.
  Uint8List convertToBytes(List<InventoryItemSummary> items) {
    for (final summary in items) {
      if (!summary.quantityOnHand.isFinite) {
        throw InventoryPdfSerializerException(
          'Invalid non-finite quantity for item SKU "${summary.item.sku}": ${summary.quantityOnHand}',
        );
      }
    }

    final dataRows = items
        .map(
          (summary) => [
            _fit(_pdfSafeText(summary.item.name), _maxNameChars),
            _fit(_pdfSafeText(summary.item.sku), _maxSkuChars),
            _fit(_formatQuantity(summary.quantityOnHand), _maxQuantityChars),
          ],
        )
        .toList(growable: false);

    const rowsPerPage = 40;
    final pageCount = dataRows.isEmpty
        ? 1
        : (dataRows.length + rowsPerPage - 1) ~/ rowsPerPage;
    final objects = <int, String>{};
    objects[1] = '<< /Type /Catalog /Pages 2 0 R >>';

    final pageObjectIds = <int>[];
    final contentObjectIds = <int>[];
    for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
      pageObjectIds.add(3 + pageIndex);
      contentObjectIds.add(3 + pageCount + pageIndex);
    }

    final regularFontId = 3 + (pageCount * 2);
    final boldFontId = regularFontId + 1;
    final kids = pageObjectIds.map((id) => '$id 0 R').join(' ');
    objects[2] = '<< /Type /Pages /Kids [$kids] /Count $pageCount >>';

    for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
      final content = _buildPageContent(
        dataRows.skip(pageIndex * rowsPerPage).take(rowsPerPage).toList(),
      );
      final contentBytes = ascii.encode(content);
      final pageId = pageObjectIds[pageIndex];
      final contentId = contentObjectIds[pageIndex];

      objects[pageId] =
          '<< /Type /Page /Parent 2 0 R '
          '/MediaBox [0 0 $_pageWidth $_pageHeight] '
          '/Resources << /Font << /F1 $regularFontId 0 R /F2 $boldFontId 0 R >> >> '
          '/Contents $contentId 0 R >>';
      objects[contentId] =
          '<< /Length ${contentBytes.length} >>\nstream\n$content\nendstream';
    }

    objects[regularFontId] =
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>';
    objects[boldFontId] =
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>';

    return _buildPdf(objects);
  }

  String _buildPageContent(List<List<String>> rows) {
    final buffer = StringBuffer();
    buffer.writeln('BT');
    buffer.writeln('/F2 16 Tf');
    buffer.writeln('$_leftMargin $_topMargin Td');
    buffer.writeln('(${_escapeText('Inventory Export')}) Tj');
    buffer.writeln('/F1 9 Tf');
    buffer.writeln('0 -22 Td');
    buffer.writeln('(${_escapeText('Item Name')}) Tj');
    buffer.writeln('220 0 Td');
    buffer.writeln('(${_escapeText('SKU')}) Tj');
    buffer.writeln('160 0 Td');
    buffer.writeln('(${_escapeText('Current Quantity')}) Tj');
    buffer.writeln('ET');

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final y = _topMargin - 44 - (index * _rowHeight);
      buffer.writeln('BT');
      buffer.writeln('/F1 9 Tf');
      buffer.writeln('$_leftMargin $y Td');
      buffer.writeln('(${_escapeText(row[0])}) Tj');
      buffer.writeln('220 0 Td');
      buffer.writeln('(${_escapeText(row[1])}) Tj');
      buffer.writeln('160 0 Td');
      buffer.writeln('(${_escapeText(row[2])}) Tj');
      buffer.writeln('ET');
    }

    return buffer.toString();
  }

  Uint8List _buildPdf(Map<int, String> objects) {
    final buffer = BytesBuilder();
    buffer.add(ascii.encode('%PDF-1.4\n%PDF\n'));
    final offsets = <int, int>{};
    final maxObjectId = objects.keys.reduce((a, b) => a > b ? a : b);

    for (var objectId = 1; objectId <= maxObjectId; objectId++) {
      final object = objects[objectId];
      if (object == null) {
        throw const InventoryPdfSerializerException(
          'Failed to assemble PDF export.',
        );
      }
      offsets[objectId] = buffer.length;
      buffer.add(ascii.encode('$objectId 0 obj\n$object\nendobj\n'));
    }

    final xrefOffset = buffer.length;
    buffer.add(ascii.encode('xref\n0 ${maxObjectId + 1}\n'));
    buffer.add(ascii.encode('0000000000 65535 f \n'));
    for (var objectId = 1; objectId <= maxObjectId; objectId++) {
      buffer.add(
        ascii.encode('${offsets[objectId]!.toString().padLeft(10, '0')} 00000 n \n'),
      );
    }
    buffer.add(
      ascii.encode(
        'trailer\n<< /Size ${maxObjectId + 1} /Root 1 0 R >>\n'
        'startxref\n$xrefOffset\n%%EOF\n',
      ),
    );
    return Uint8List.fromList(buffer.takeBytes());
  }

  static String _pdfSafeText(String value) {
    final codeUnits = value.runes.map((rune) {
      if (rune >= 32 && rune <= 126) return String.fromCharCode(rune);
      return '?';
    });
    return codeUnits.join();
  }

  static String _escapeText(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

  static String _fit(String value, int maxChars) {
    if (value.length <= maxChars) return value;
    if (maxChars <= 3) return value.substring(0, maxChars);
    return '${value.substring(0, maxChars - 3)}...';
  }

  static String _formatQuantity(double quantity) {
    if (quantity == quantity.toInt()) return quantity.toInt().toString();
    return quantity.toString();
  }
}
