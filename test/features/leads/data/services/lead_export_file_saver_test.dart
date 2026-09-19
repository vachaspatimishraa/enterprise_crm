import 'dart:typed_data';

import 'package:enterprise_crm/features/leads/data/services/lead_export_file_saver.dart';
import 'package:enterprise_crm/features/leads/data/services/lead_export_serializer.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExportSavePicker implements ExportSavePicker {
  String? lastFileName;
  Uint8List? lastBytes;
  String? lastMimeType;
  String? lastExtension;
  String? lastDialogTitle;
  int callCount = 0;

  Uri? returnUri;
  Exception? throwException;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
    String? dialogTitle,
  }) async {
    callCount++;
    lastFileName = fileName;
    lastBytes = bytes;
    lastMimeType = mimeType;
    lastExtension = extension;
    lastDialogTitle = dialogTitle;

    if (throwException != null) {
      throw throwException!;
    }
    return returnUri;
  }
}

void main() {
  late _FakeExportSavePicker picker;
  late DefaultLeadExportFileSaver saver;

  setUp(() {
    picker = _FakeExportSavePicker();
    saver = DefaultLeadExportFileSaver(picker: picker);
  });

  group('DefaultLeadExportFileSaver - CSV Forwarding', () {
    test(
      'forwards CSV export metadata and exact bytes to the save picker',
      () async {
        final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final exportResult = LeadExportResult(
          fileName: 'leads_export.csv',
          fileReference: LeadExportContent(
            bytes: sampleBytes,
            extension: 'csv',
            mimeType: 'text/csv',
          ),
        );

        final saveResult = await saver.save(exportResult);

        expect(picker.callCount, 1);
        expect(picker.lastFileName, 'leads_export.csv');
        expect(picker.lastExtension, 'csv');
        expect(picker.lastMimeType, 'text/csv');
        expect(picker.lastBytes, same(sampleBytes));
        expect(picker.lastDialogTitle, 'Save Lead Export');
        expect(saveResult.isCancelled, isTrue);
      },
    );
  });

  group('DefaultLeadExportFileSaver - XLSX Forwarding', () {
    test(
      'forwards XLSX export metadata and exact bytes to the save picker',
      () async {
        final sampleBytes = Uint8List.fromList([80, 75, 3, 4, 10, 20, 30, 40]);
        final exportResult = LeadExportResult(
          fileName: 'leads_export.xlsx',
          fileReference: LeadExportContent(
            bytes: sampleBytes,
            extension: 'xlsx',
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        );

        final saveResult = await saver.save(exportResult);

        expect(picker.callCount, 1);
        expect(picker.lastFileName, 'leads_export.xlsx');
        expect(picker.lastExtension, 'xlsx');
        expect(
          picker.lastMimeType,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        expect(picker.lastBytes, same(sampleBytes));
        expect(picker.lastDialogTitle, 'Save Lead Export');
        expect(saveResult.isCancelled, isTrue);
      },
    );
  });

  group('DefaultLeadExportFileSaver - Outcome Semantics', () {
    test(
      'returns saved status with URI when picker completes successfully',
      () async {
        final expectedUri = Uri.parse(
          'file:///home/user/downloads/leads_export.csv',
        );
        picker.returnUri = expectedUri;

        final exportResult = LeadExportResult(
          fileName: 'leads_export.csv',
          fileReference: LeadExportContent(
            bytes: Uint8List.fromList([10, 20]),
            extension: 'csv',
            mimeType: 'text/csv',
          ),
        );

        final saveResult = await saver.save(exportResult);

        expect(saveResult.status, LeadExportSaveStatus.saved);
        expect(saveResult.isSaved, isTrue);
        expect(saveResult.isCancelled, isFalse);
        expect(saveResult.uri, expectedUri);
      },
    );

    test(
      'returns cancelled status without throwing when user dismisses dialog',
      () async {
        picker.returnUri = null;

        final exportResult = LeadExportResult(
          fileName: 'leads_export.csv',
          fileReference: LeadExportContent(
            bytes: Uint8List.fromList([10, 20]),
            extension: 'csv',
            mimeType: 'text/csv',
          ),
        );

        final saveResult = await saver.save(exportResult);

        expect(saveResult.status, LeadExportSaveStatus.cancelled);
        expect(saveResult.isCancelled, isTrue);
        expect(saveResult.isSaved, isFalse);
        expect(saveResult.uri, isNull);
      },
    );

    test(
      'propagates platform exception naturally when picker throws',
      () async {
        picker.throwException = Exception('Platform picker failure');

        final exportResult = LeadExportResult(
          fileName: 'leads_export.csv',
          fileReference: LeadExportContent(
            bytes: Uint8List.fromList([10, 20]),
            extension: 'csv',
            mimeType: 'text/csv',
          ),
        );

        expect(() => saver.save(exportResult), throwsA(isA<Exception>()));
      },
    );
  });

  group('DefaultLeadExportFileSaver - Artifact Validation & Byte Safety', () {
    test(
      'throws explicit UnsupportedError when fileReference is not LeadExportContent',
      () async {
        const invalidResult = LeadExportResult(
          fileName: 'legacy.csv',
          fileReference: 'mock-opaque-string-reference',
        );

        expect(
          () => saver.save(invalidResult),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              contains('Expected LeadExportContent'),
            ),
          ),
        );
        expect(picker.callCount, 0);
      },
    );

    test('preserves byte identity without tampering or re-encoding', () async {
      final pristineBytes = Uint8List.fromList([
        0,
        255,
        128,
        64,
        32,
        16,
        8,
        4,
        2,
        1,
      ]);
      final exportResult = LeadExportResult(
        fileName: 'leads_export.csv',
        fileReference: LeadExportContent(
          bytes: pristineBytes,
          extension: 'csv',
          mimeType: 'text/csv',
        ),
      );

      await saver.save(exportResult);

      expect(picker.lastBytes, orderedEquals(pristineBytes));
      expect(identical(picker.lastBytes, pristineBytes), isTrue);
    });

    test('successfully processes headers-only empty export artifact', () async {
      const serializer = DefaultLeadExportSerializer();
      final headersOnly = serializer.serialize(
        leads: const [],
        format: LeadExportFormat.csv,
      );

      final exportResult = LeadExportResult(
        fileName: 'leads_export.csv',
        fileReference: headersOnly,
      );

      final saveResult = await saver.save(exportResult);

      expect(picker.callCount, 1);
      expect(picker.lastBytes, headersOnly.bytes);
      expect(saveResult.isCancelled, isTrue);
    });
  });

  group('LeadExportSaveResult - Value Equality', () {
    test('supports value equality and toString', () {
      final uri = Uri.parse('file:///tmp/export.csv');
      final result1 = LeadExportSaveResult.saved(uri: uri);
      final result2 = LeadExportSaveResult.saved(uri: uri);
      const cancelled1 = LeadExportSaveResult.cancelled();
      const cancelled2 = LeadExportSaveResult.cancelled();

      expect(result1, result2);
      expect(result1.hashCode, result2.hashCode);
      expect(cancelled1, cancelled2);
      expect(cancelled1.hashCode, cancelled2.hashCode);
      expect(result1, isNot(cancelled1));

      expect(result1.toString(), contains('saved'));
      expect(cancelled1.toString(), contains('cancelled'));
    });
  });
}
