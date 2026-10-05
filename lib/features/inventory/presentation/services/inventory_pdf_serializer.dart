import 'dart:convert';
import 'dart:typed_data';

import 'package:enterprise_crm/features/inventory/domain/entities/custom_field_definition.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_artifact.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_fields.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_item_summary.dart';

/// Exception thrown when PDF export serialization fails.
class InventoryPdfSerializerException implements Exception {
  const InventoryPdfSerializerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Page layout orientation options for PDF export.
enum PdfLayoutOrientation {
  auto,
  portrait,
  landscape,
}

/// Creates a dependency-free, printable PDF report supporting both the frozen
/// legacy three-column schema and fully customizable column selections.
///
/// Features:
/// - Deterministic layout policy: Portrait for <= 4 columns, Landscape for 5-10
///   columns, and structured Record Card layout for > 10 columns.
/// - Enterprise-grade report header: Document title, record scope, generated timestamp.
/// - Repeated table headers on every page for multi-page exports.
/// - Page numbering ("Page X of Y") in footer of every page.
/// - Zero dependencies outside Dart core: uses standard PDF 1.4 objects.
/// - Built-in Helvetica fonts with graceful sanitization of unsupported characters to `?`.
class InventoryPdfSerializer {
  const InventoryPdfSerializer();

  static const String headerName = 'Item Name';
  static const String headerSku = 'SKU';
  static const String headerQuantity = 'Current Quantity';

  // Standard A4 dimensions in points
  static const double _a4Width = 595.0;
  static const double _a4Height = 842.0;
  static const double _margin = 36.0;

  /// Converts Inventory summaries into a valid multi-page PDF byte array.
  Uint8List convertToBytes(
    List<InventoryItemSummary> items, {
    List<String>? columns,
    List<CustomFieldDefinition>? customFieldDefinitions,
    bool isLegacy = true,
    InventoryExportScope scope = InventoryExportScope.all,
    DateTime? generatedAt,
    String? title,
    PdfLayoutOrientation orientation = PdfLayoutOrientation.auto,
  }) {
    if (isLegacy || columns == null) {
      return _buildLegacyPdf(items);
    }

    return _buildCustomPdf(
      items,
      columns: columns,
      customFieldDefinitions: customFieldDefinitions,
      scope: scope,
      generatedAt: generatedAt,
      title: title,
      orientation: orientation,
    );
  }

  // =========================================================================
  // LEGACY THREE-COLUMN PDF (Backward Compatible)
  // =========================================================================

  Uint8List _buildLegacyPdf(List<InventoryItemSummary> items) {
    const pageWidth = _a4Width;
    const pageHeight = _a4Height;
    const leftMargin = _margin;
    const topMargin = 806.0;
    const rowHeight = 18.0;
    const maxNameChars = 38;
    const maxSkuChars = 26;
    const maxQuantityChars = 18;

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
            _fit(_pdfSafeText(summary.item.name), maxNameChars),
            _fit(_pdfSafeText(summary.item.sku), maxSkuChars),
            _fit(_formatQuantity(summary.quantityOnHand), maxQuantityChars),
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
      final content = _buildLegacyPageContent(
        dataRows.skip(pageIndex * rowsPerPage).take(rowsPerPage).toList(),
        leftMargin: leftMargin,
        topMargin: topMargin,
        rowHeight: rowHeight,
      );
      final contentBytes = ascii.encode(content);
      final pageId = pageObjectIds[pageIndex];
      final contentId = contentObjectIds[pageIndex];

      objects[pageId] =
          '<< /Type /Page /Parent 2 0 R '
          '/MediaBox [0 0 $pageWidth $pageHeight] '
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

  String _buildLegacyPageContent(
    List<List<String>> rows, {
    required double leftMargin,
    required double topMargin,
    required double rowHeight,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('BT');
    buffer.writeln('/F2 16 Tf');
    buffer.writeln('$leftMargin $topMargin Td');
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
      final y = topMargin - 44 - (index * rowHeight);
      buffer.writeln('BT');
      buffer.writeln('/F1 9 Tf');
      buffer.writeln('$leftMargin $y Td');
      buffer.writeln('(${_escapeText(row[0])}) Tj');
      buffer.writeln('220 0 Td');
      buffer.writeln('(${_escapeText(row[1])}) Tj');
      buffer.writeln('160 0 Td');
      buffer.writeln('(${_escapeText(row[2])}) Tj');
      buffer.writeln('ET');
    }

    return buffer.toString();
  }

  // =========================================================================
  // CUSTOM CONFIGURABLE PDF (INVENTORY-7.6)
  // =========================================================================

  Uint8List _buildCustomPdf(
    List<InventoryItemSummary> items, {
    required List<String> columns,
    List<CustomFieldDefinition>? customFieldDefinitions,
    required InventoryExportScope scope,
    DateTime? generatedAt,
    String? title,
    required PdfLayoutOrientation orientation,
  }) {
    if (columns.isEmpty) {
      throw const InventoryPdfSerializerException('No export columns selected.');
    }
    if (columns.toSet().length != columns.length) {
      throw const InventoryPdfSerializerException('Duplicate export columns are not permitted.');
    }
    for (final col in columns) {
      if (!InventoryExportFields.isValidKey(col, customFieldDefinitions: customFieldDefinitions)) {
        throw InventoryPdfSerializerException('Unknown export column: $col');
      }
    }

    // Validate non-finite numbers across all items
    for (final summary in items) {
      for (final col in columns) {
        final val = InventoryExportFields.extractValue(
          summary,
          col,
          customFieldDefinitions: customFieldDefinitions,
        );
        if (val is num && !val.isFinite) {
          throw InventoryPdfSerializerException(
            'Invalid non-finite value for item "${summary.item.sku}" in column "$col": $val',
          );
        }
      }
    }

    final reportTitle = title ?? 'Inventory Export Report';
    final timestamp = generatedAt ?? DateTime.now();
    final dateStr = _formatTimestamp(timestamp);
    final scopeLabel = _getScopeLabel(scope, items.length);

    // Layout decision:
    // <= 10 columns -> Table Layout (Portrait for <= 4, Landscape for 5-10)
    // > 10 columns -> Record Card Layout
    final isTableLayout = columns.length <= 10;

    if (isTableLayout) {
      return _renderTableReport(
        items,
        columns: columns,
        customFieldDefinitions: customFieldDefinitions,
        reportTitle: reportTitle,
        scopeLabel: scopeLabel,
        dateStr: dateStr,
        orientation: orientation,
      );
    } else {
      return _renderCardReport(
        items,
        columns: columns,
        customFieldDefinitions: customFieldDefinitions,
        reportTitle: reportTitle,
        scopeLabel: scopeLabel,
        dateStr: dateStr,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Table Layout (< = 10 columns)
  // -------------------------------------------------------------------------

  Uint8List _renderTableReport(
    List<InventoryItemSummary> items, {
    required List<String> columns,
    List<CustomFieldDefinition>? customFieldDefinitions,
    required String reportTitle,
    required String scopeLabel,
    required String dateStr,
    required PdfLayoutOrientation orientation,
  }) {
    final bool isLandscape;
    switch (orientation) {
      case PdfLayoutOrientation.portrait:
        isLandscape = false;
        break;
      case PdfLayoutOrientation.landscape:
        isLandscape = true;
        break;
      case PdfLayoutOrientation.auto:
        isLandscape = columns.length > 4;
        break;
    }

    final double pageWidth = isLandscape ? _a4Height : _a4Width;
    final double pageHeight = isLandscape ? _a4Width : _a4Height;
    final double usableWidth = pageWidth - (2 * _margin);

    // Proportional column widths calculation
    final colWeights = columns.map(_getColumnWeight).toList();
    final totalWeight = colWeights.reduce((a, b) => a + b);
    final colWidths = colWeights.map((w) => usableWidth * (w / totalWeight)).toList();

    final colHeaders = columns.map((col) {
      return InventoryExportFields.getHeaderLabel(
        col,
        customFieldDefinitions: customFieldDefinitions,
        isLegacy: false,
      );
    }).toList();

    // Data rows formatted and fitted
    final dataRows = items.map((summary) {
      final row = <String>[];
      for (var i = 0; i < columns.length; i++) {
        final col = columns[i];
        final val = InventoryExportFields.extractValue(
          summary,
          col,
          customFieldDefinitions: customFieldDefinitions,
        );
        final formatted = _formatCustomValue(val, col);
        final maxChars = ((colWidths[i] - 6) / 5.2).floor().clamp(4, 80);
        row.add(_fit(_pdfSafeText(formatted), maxChars));
      }
      return row;
    }).toList(growable: false);

    const rowHeight = 18.0;
    // Page 1 has large header (110pt top reserved), Page 2+ has compact header (88pt)
    final p1UsableHeight = pageHeight - 110.0 - 50.0;
    final p2UsableHeight = pageHeight - 88.0 - 50.0;
    final p1Capacity = (p1UsableHeight / rowHeight).floor();
    final p2Capacity = (p2UsableHeight / rowHeight).floor();

    // Calculate pagination slices
    final pageSlices = <List<List<String>>>[];
    if (dataRows.isEmpty) {
      pageSlices.add(const []);
    } else {
      var remaining = dataRows;
      pageSlices.add(remaining.take(p1Capacity).toList());
      remaining = remaining.skip(p1Capacity).toList();
      while (remaining.isNotEmpty) {
        pageSlices.add(remaining.take(p2Capacity).toList());
        remaining = remaining.skip(p2Capacity).toList();
      }
    }

    final pageCount = pageSlices.length;
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
      final rows = pageSlices[pageIndex];
      final isFirstPage = pageIndex == 0;
      final buffer = StringBuffer();

      // Background header rectangle on table
      final tableTopY = isFirstPage ? pageHeight - 92.0 : pageHeight - 70.0;
      buffer.writeln('q');
      buffer.writeln('0.93 0.93 0.93 rg');
      buffer.writeln('$_margin ${tableTopY - 4} $usableWidth 16 re');
      buffer.writeln('f');
      buffer.writeln('0.7 0.7 0.7 RG');
      buffer.writeln('0.5 w');
      buffer.writeln('$_margin ${tableTopY - 4} m ${pageWidth - _margin} ${tableTopY - 4} l S');
      buffer.writeln('Q');

      // Top Document Header
      if (isFirstPage) {
        buffer.writeln('BT');
        buffer.writeln('/F2 14 Tf');
        buffer.writeln('$_margin ${pageHeight - 48} Td');
        buffer.writeln('(${_escapeText(_pdfSafeText(reportTitle))}) Tj');
        buffer.writeln('/F1 8 Tf');
        buffer.writeln('0 -16 Td');
        buffer.writeln('(${_escapeText(_pdfSafeText('$scopeLabel  |  Generated: $dateStr'))}) Tj');
        buffer.writeln('ET');

        // Divider under report header
        buffer.writeln('q');
        buffer.writeln('0.7 0.7 0.7 RG');
        buffer.writeln('0.5 w');
        buffer.writeln('$_margin ${pageHeight - 74} m ${pageWidth - _margin} ${pageHeight - 74} l S');
        buffer.writeln('Q');
      } else {
        buffer.writeln('BT');
        buffer.writeln('/F2 10 Tf');
        buffer.writeln('$_margin ${pageHeight - 44} Td');
        buffer.writeln('(${_escapeText(_pdfSafeText('$reportTitle (cont.)'))}) Tj');
        buffer.writeln('ET');

        buffer.writeln('q');
        buffer.writeln('0.7 0.7 0.7 RG');
        buffer.writeln('0.5 w');
        buffer.writeln('$_margin ${pageHeight - 52} m ${pageWidth - _margin} ${pageHeight - 52} l S');
        buffer.writeln('Q');
      }

      // Column Headers (repeated on every page!)
      var currentX = _margin;
      for (var colIdx = 0; colIdx < columns.length; colIdx++) {
        final label = _fit(colHeaders[colIdx], ((colWidths[colIdx] - 4) / 5.2).floor().clamp(3, 40));
        buffer.writeln('BT');
        buffer.writeln('/F2 8 Tf');
        buffer.writeln('$currentX $tableTopY Td');
        buffer.writeln('(${_escapeText(_pdfSafeText(label))}) Tj');
        buffer.writeln('ET');
        currentX += colWidths[colIdx];
      }

      // Rows
      final firstRowY = isFirstPage ? pageHeight - 110.0 : pageHeight - 88.0;
      if (rows.isEmpty && isFirstPage) {
        buffer.writeln('BT');
        buffer.writeln('/F1 9 Tf');
        buffer.writeln('$_margin ${firstRowY - 10} Td');
        buffer.writeln('(${_escapeText('No inventory items found matching the selected scope.')}) Tj');
        buffer.writeln('ET');
      } else {
        for (var rowIdx = 0; rowIdx < rows.length; rowIdx++) {
          final rowData = rows[rowIdx];
          final y = firstRowY - (rowIdx * rowHeight);

          // Subtle horizontal divider between rows
          buffer.writeln('q');
          buffer.writeln('0.9 0.9 0.9 RG');
          buffer.writeln('0.3 w');
          buffer.writeln('$_margin ${y - 3} m ${pageWidth - _margin} ${y - 3} l S');
          buffer.writeln('Q');

          var cellX = _margin;
          for (var colIdx = 0; colIdx < rowData.length; colIdx++) {
            buffer.writeln('BT');
            buffer.writeln('/F1 8 Tf');
            buffer.writeln('$cellX $y Td');
            buffer.writeln('(${_escapeText(rowData[colIdx])}) Tj');
            buffer.writeln('ET');
            cellX += colWidths[colIdx];
          }
        }
      }

      // Footer: Divider & Page Numbering
      buffer.writeln('q');
      buffer.writeln('0.8 0.8 0.8 RG');
      buffer.writeln('0.5 w');
      buffer.writeln('$_margin 34 m ${pageWidth - _margin} 34 l S');
      buffer.writeln('Q');

      buffer.writeln('BT');
      buffer.writeln('/F1 8 Tf');
      buffer.writeln('$_margin 22 Td');
      buffer.writeln('(${_escapeText('Enterprise CRM - Inventory Report')}) Tj');
      buffer.writeln('ET');

      final pageStr = 'Page ${pageIndex + 1} of $pageCount';
      final pageStrX = pageWidth - _margin - (pageStr.length * 5.0);
      buffer.writeln('BT');
      buffer.writeln('/F1 8 Tf');
      buffer.writeln('$pageStrX 22 Td');
      buffer.writeln('(${_escapeText(pageStr)}) Tj');
      buffer.writeln('ET');

      final content = buffer.toString();
      final contentBytes = ascii.encode(content);
      final pageId = pageObjectIds[pageIndex];
      final contentId = contentObjectIds[pageIndex];

      objects[pageId] =
          '<< /Type /Page /Parent 2 0 R '
          '/MediaBox [0 0 $pageWidth $pageHeight] '
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

  // -------------------------------------------------------------------------
  // Record Card Layout (> 10 columns)
  // -------------------------------------------------------------------------

  Uint8List _renderCardReport(
    List<InventoryItemSummary> items, {
    required List<String> columns,
    List<CustomFieldDefinition>? customFieldDefinitions,
    required String reportTitle,
    required String scopeLabel,
    required String dateStr,
  }) {
    const pageWidth = _a4Width;
    const pageHeight = _a4Height;
    const usableWidth = pageWidth - (2 * _margin);

    final colHeaders = <String, String>{};
    for (final col in columns) {
      colHeaders[col] = InventoryExportFields.getHeaderLabel(
        col,
        customFieldDefinitions: customFieldDefinitions,
        isLegacy: false,
      );
    }

    // Number of lines per card = ceil(columns.length / 2)
    final linesPerCard = (columns.length + 1) ~/ 2;
    // Card height = header (20pt) + lines (14pt each) + padding (12pt)
    final cardHeight = 24.0 + (linesPerCard * 14.0) + 10.0;

    const p1Top = pageHeight - 85.0;
    const p2Top = pageHeight - 65.0;
    const footerReservation = 45.0;

    final p1Capacity = ((p1Top - footerReservation) / cardHeight).floor().clamp(1, 10);
    final p2Capacity = ((p2Top - footerReservation) / cardHeight).floor().clamp(1, 10);

    final pageItemSlices = <List<InventoryItemSummary>>[];
    if (items.isEmpty) {
      pageItemSlices.add(const []);
    } else {
      var remaining = items;
      pageItemSlices.add(remaining.take(p1Capacity).toList());
      remaining = remaining.skip(p1Capacity).toList();
      while (remaining.isNotEmpty) {
        pageItemSlices.add(remaining.take(p2Capacity).toList());
        remaining = remaining.skip(p2Capacity).toList();
      }
    }

    final pageCount = pageItemSlices.length;
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

    var globalItemIndex = 0;

    for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
      final pageItems = pageItemSlices[pageIndex];
      final isFirstPage = pageIndex == 0;
      final buffer = StringBuffer();

      // Top Document Header
      if (isFirstPage) {
        buffer.writeln('BT');
        buffer.writeln('/F2 14 Tf');
        buffer.writeln('$_margin ${pageHeight - 48} Td');
        buffer.writeln('(${_escapeText(_pdfSafeText(reportTitle))}) Tj');
        buffer.writeln('/F1 8 Tf');
        buffer.writeln('0 -16 Td');
        buffer.writeln('(${_escapeText(_pdfSafeText('$scopeLabel  |  Generated: $dateStr'))}) Tj');
        buffer.writeln('ET');

        buffer.writeln('q');
        buffer.writeln('0.7 0.7 0.7 RG');
        buffer.writeln('0.5 w');
        buffer.writeln('$_margin ${pageHeight - 74} m ${pageWidth - _margin} ${pageHeight - 74} l S');
        buffer.writeln('Q');
      } else {
        buffer.writeln('BT');
        buffer.writeln('/F2 10 Tf');
        buffer.writeln('$_margin ${pageHeight - 44} Td');
        buffer.writeln('(${_escapeText(_pdfSafeText('$reportTitle (cont.)'))}) Tj');
        buffer.writeln('ET');

        buffer.writeln('q');
        buffer.writeln('0.7 0.7 0.7 RG');
        buffer.writeln('0.5 w');
        buffer.writeln('$_margin ${pageHeight - 52} m ${pageWidth - _margin} ${pageHeight - 52} l S');
        buffer.writeln('Q');
      }

      final startY = isFirstPage ? pageHeight - 96.0 : pageHeight - 74.0;

      if (pageItems.isEmpty && isFirstPage) {
        buffer.writeln('BT');
        buffer.writeln('/F1 9 Tf');
        buffer.writeln('$_margin ${startY - 10} Td');
        buffer.writeln('(${_escapeText('No inventory items found matching the selected scope.')}) Tj');
        buffer.writeln('ET');
      } else {
        for (var cardIdx = 0; cardIdx < pageItems.length; cardIdx++) {
          final summary = pageItems[cardIdx];
          final item = summary.item;
          globalItemIndex++;
          final cardTop = startY - (cardIdx * cardHeight);

          // Card header background
          buffer.writeln('q');
          buffer.writeln('0.94 0.94 0.94 rg');
          buffer.writeln('$_margin ${cardTop - 18} $usableWidth 18 re');
          buffer.writeln('f');
          buffer.writeln('0.7 0.7 0.7 RG');
          buffer.writeln('0.5 w');
          buffer.writeln('$_margin ${cardTop - 18} $usableWidth 18 re');
          buffer.writeln('S');
          buffer.writeln('Q');

          // Card title text: Item #X: Name | SKU: sku
          final cardTitle = 'Item #$globalItemIndex: ${_fit(item.name, 45)}';
          final skuStr = 'SKU: ${item.sku}';
          buffer.writeln('BT');
          buffer.writeln('/F2 9 Tf');
          buffer.writeln('${_margin + 6} ${cardTop - 13} Td');
          buffer.writeln('(${_escapeText(_pdfSafeText(cardTitle))}) Tj');
          buffer.writeln('ET');

          final skuX = pageWidth - _margin - (skuStr.length * 5.4) - 6;
          buffer.writeln('BT');
          buffer.writeln('/F2 9 Tf');
          buffer.writeln('$skuX ${cardTop - 13} Td');
          buffer.writeln('(${_escapeText(_pdfSafeText(skuStr))}) Tj');
          buffer.writeln('ET');

          // Card fields in 2 columns
          const leftColX = _margin + 8;
          final rightColX = _margin + (usableWidth / 2) + 8;
          final colWidth = (usableWidth / 2) - 16;
          final maxValChars = ((colWidth - 80) / 4.8).floor().clamp(10, 40);

          for (var fieldIdx = 0; fieldIdx < columns.length; fieldIdx++) {
            final colKey = columns[fieldIdx];
            final label = colHeaders[colKey] ?? colKey;
            final val = InventoryExportFields.extractValue(
              summary,
              colKey,
              customFieldDefinitions: customFieldDefinitions,
            );
            final formattedVal = _fit(_formatCustomValue(val, colKey), maxValChars);

            final lineIdx = fieldIdx ~/ 2;
            final isRight = fieldIdx % 2 == 1;
            final x = isRight ? rightColX : leftColX;
            final y = cardTop - 32 - (lineIdx * 14.0);

            buffer.writeln('BT');
            buffer.writeln('/F2 8 Tf');
            buffer.writeln('$x $y Td');
            buffer.writeln('(${_escapeText(_pdfSafeText('$label:'))}) Tj');
            buffer.writeln('/F1 8 Tf');
            buffer.writeln('75 0 Td');
            buffer.writeln('(${_escapeText(_pdfSafeText(formattedVal))}) Tj');
            buffer.writeln('ET');
          }

          // Card outer boundary line
          final cardBottom = cardTop - cardHeight + 6;
          buffer.writeln('q');
          buffer.writeln('0.85 0.85 0.85 RG');
          buffer.writeln('0.4 w');
          buffer.writeln('$_margin $cardBottom m ${pageWidth - _margin} $cardBottom l S');
          buffer.writeln('Q');
        }
      }

      // Footer: Divider & Page Numbering
      buffer.writeln('q');
      buffer.writeln('0.8 0.8 0.8 RG');
      buffer.writeln('0.5 w');
      buffer.writeln('$_margin 34 m ${pageWidth - _margin} 34 l S');
      buffer.writeln('Q');

      buffer.writeln('BT');
      buffer.writeln('/F1 8 Tf');
      buffer.writeln('$_margin 22 Td');
      buffer.writeln('(${_escapeText('Enterprise CRM - Inventory Report')}) Tj');
      buffer.writeln('ET');

      final pageStr = 'Page ${pageIndex + 1} of $pageCount';
      final pageStrX = pageWidth - _margin - (pageStr.length * 5.0);
      buffer.writeln('BT');
      buffer.writeln('/F1 8 Tf');
      buffer.writeln('$pageStrX 22 Td');
      buffer.writeln('(${_escapeText(pageStr)}) Tj');
      buffer.writeln('ET');

      final content = buffer.toString();
      final contentBytes = ascii.encode(content);
      final pageId = pageObjectIds[pageIndex];
      final contentId = contentObjectIds[pageIndex];

      objects[pageId] =
          '<< /Type /Page /Parent 2 0 R '
          '/MediaBox [0 0 $pageWidth $pageHeight] '
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

  // =========================================================================
  // HELPER METHODS
  // =========================================================================

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

  static String _formatCustomValue(Object? value, String colKey) {
    if (value == null) return '-';
    if (value is num) {
      final norm = InventoryExportFields.normalizeKey(colKey);
      if (norm == 'unit_cost_inr' || norm == 'selling_price_inr') {
        return 'INR ${value.toStringAsFixed(2)}';
      }
      if (norm == 'gst_percent') {
        return '${_formatQuantity(value.toDouble())}%';
      }
      return _formatQuantity(value.toDouble());
    }
    if (value is DateTime) {
      return InventoryExportFields.formatDate(value);
    }
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }
    final str = value.toString().trim();
    return str.isEmpty ? '-' : str;
  }

  static double _getColumnWeight(String key) {
    final norm = InventoryExportFields.normalizeKey(key);
    switch (norm) {
      case 'product_name':
      case 'notes':
        return 2.4;
      case 'sku':
      case 'barcode':
      case 'category':
      case 'brand':
      case 'supplier':
      case 'warehouse':
      case 'batch_number':
        return 1.4;
      case 'unit_cost_inr':
      case 'selling_price_inr':
      case 'current_quantity':
      case 'reorder_level':
      case 'max_stock':
      case 'gst_percent':
      case 'expiry_date':
      case 'last_restocked_date':
      case 'is_active':
      case 'stock_status':
      case 'unit':
      case 'bin_location':
        return 1.0;
      default:
        return 1.2;
    }
  }

  static String _getScopeLabel(InventoryExportScope scope, int count) {
    return switch (scope) {
      InventoryExportScope.all => 'Scope: All Records ($count items)',
      InventoryExportScope.filtered => 'Scope: Filtered Results ($count items)',
      InventoryExportScope.selected => 'Scope: Selected Items ($count items)',
    };
  }

  static String _formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}
