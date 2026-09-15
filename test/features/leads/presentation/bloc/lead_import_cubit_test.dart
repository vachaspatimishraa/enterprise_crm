import 'dart:async';
import 'dart:typed_data';

import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_state.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_selected_file.dart';
import 'package:enterprise_crm/features/leads/presentation/services/lead_import_file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLeadImportFilePicker implements LeadImportFilePicker {
  LeadImportSelectedFile? fileToReturn;
  Exception? exceptionToThrow;
  Completer<LeadImportSelectedFile?>? delayCompleter;
  int pickCallsCount = 0;

  @override
  Future<LeadImportSelectedFile?> pickFile() async {
    pickCallsCount++;
    if (delayCompleter != null) {
      final delayed = await delayCompleter!.future;
      if (delayed != null) return delayed;
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return fileToReturn;
  }
}

void main() {
  group('LeadImportCubit', () {
    late FakeLeadImportFilePicker fakePicker;
    late LeadImportCubit cubit;

    setUp(() {
      fakePicker = FakeLeadImportFilePicker();
      cubit = LeadImportCubit(fakePicker);
    });

    tearDown(() {
      cubit.close();
    });

    final validCsvFile = LeadImportSelectedFile(
      name: 'customers.csv',
      extension: 'csv',
      sizeBytes: 2048,
      source: LeadSource.csv,
      content: InMemoryLeadImportFileContent(Uint8List(0)),
    );

    final validXlsxFile = LeadImportSelectedFile(
      name: 'leads_q3.xlsx',
      extension: 'xlsx',
      sizeBytes: 10240,
      source: LeadSource.excel,
      content: InMemoryLeadImportFileContent(Uint8List(0)),
    );

    test('initial state is LeadImportInitial and currentFile is null', () {
      expect(cubit.state, isA<LeadImportInitial>());
      expect(cubit.currentFile, isNull);
    });

    test(
      'picks CSV file successfully and sets source to LeadSource.csv',
      () async {
        fakePicker.fileToReturn = validCsvFile;

        final future = cubit.pickFile();
        expect(cubit.state, isA<LeadImportPicking>());
        await future;

        expect(cubit.state, equals(LeadImportFileSelected(validCsvFile)));
        expect(cubit.currentFile, equals(validCsvFile));
        expect(cubit.currentFile?.source, equals(LeadSource.csv));
      },
    );

    test(
      'picks XLSX file successfully and sets source to LeadSource.excel',
      () async {
        fakePicker.fileToReturn = validXlsxFile;

        await cubit.pickFile();

        expect(cubit.state, equals(LeadImportFileSelected(validXlsxFile)));
        expect(cubit.currentFile, equals(validXlsxFile));
        expect(cubit.currentFile?.source, equals(LeadSource.excel));
      },
    );

    test(
      'picker cancellation when empty restores LeadImportInitial without error',
      () async {
        fakePicker.fileToReturn = null;

        await cubit.pickFile();

        expect(cubit.state, equals(const LeadImportInitial()));
        expect(cubit.currentFile, isNull);
      },
    );

    test(
      'picker cancellation when a file is already selected restores previous file',
      () async {
        fakePicker.fileToReturn = validCsvFile;
        await cubit.pickFile();
        expect(cubit.state, equals(LeadImportFileSelected(validCsvFile)));

        // Second pick cancelled by user
        fakePicker.fileToReturn = null;
        await cubit.pickFile();

        expect(cubit.state, equals(LeadImportFileSelected(validCsvFile)));
        expect(cubit.currentFile, equals(validCsvFile));
      },
    );

    test(
      'replacement failure preserves previous valid file in error state',
      () async {
        fakePicker.fileToReturn = validCsvFile;
        await cubit.pickFile();
        expect(cubit.state, equals(LeadImportFileSelected(validCsvFile)));

        // Second pick throws an unexpected error
        fakePicker.exceptionToThrow = Exception('Disk read error');
        await cubit.pickFile();

        expect(
          cubit.state,
          equals(
            LeadImportFileError(
              'Unable to read the selected file.',
              previousFile: validCsvFile,
            ),
          ),
        );
        expect(cubit.currentFile, equals(validCsvFile));
      },
    );

    test('rejects file with unsupported extension', () async {
      fakePicker.fileToReturn = LeadImportSelectedFile(
        name: 'notes.pdf',
        extension: 'pdf',
        sizeBytes: 5000,
        source: LeadSource.manual,
        content: InMemoryLeadImportFileContent(Uint8List(0)),
      );

      await cubit.pickFile();

      expect(cubit.state, isA<LeadImportFileError>());
      final error = cubit.state as LeadImportFileError;
      expect(error.message, contains('Unsupported file type'));
      expect(cubit.currentFile, isNull);
    });

    test('rejects empty file (0 bytes)', () async {
      fakePicker.fileToReturn = LeadImportSelectedFile(
        name: 'empty.csv',
        extension: 'csv',
        sizeBytes: 0,
        source: LeadSource.csv,
        content: InMemoryLeadImportFileContent(Uint8List(0)),
      );

      await cubit.pickFile();

      expect(cubit.state, isA<LeadImportFileError>());
      final error = cubit.state as LeadImportFileError;
      expect(error.message, equals('The selected file is empty.'));
      expect(cubit.currentFile, isNull);
    });

    test('handles LeadImportFileException with specific message', () async {
      fakePicker.exceptionToThrow = const LeadImportFileException(
        'Unable to determine the selected file size.',
      );

      await cubit.pickFile();

      expect(cubit.state, isA<LeadImportFileError>());
      final error = cubit.state as LeadImportFileError;
      expect(
        error.message,
        equals('Unable to determine the selected file size.'),
      );
    });

    test(
      'prevents duplicate picker launches when picking is already in progress',
      () async {
        final completer = Completer<LeadImportSelectedFile?>();
        fakePicker.delayCompleter = completer;

        final firstPick = cubit.pickFile();
        expect(cubit.state, isA<LeadImportPicking>());
        expect(fakePicker.pickCallsCount, equals(1));

        // Attempt second pick while first is still pending
        final secondPick = cubit.pickFile();
        expect(fakePicker.pickCallsCount, equals(1)); // Was not invoked again

        completer.complete(validCsvFile);
        await firstPick;
        await secondPick;

        expect(cubit.state, equals(LeadImportFileSelected(validCsvFile)));
      },
    );

    test('removeFile resets state to LeadImportInitial', () async {
      fakePicker.fileToReturn = validCsvFile;
      await cubit.pickFile();
      expect(cubit.currentFile, isNotNull);

      cubit.removeFile();

      expect(cubit.state, equals(const LeadImportInitial()));
      expect(cubit.currentFile, isNull);
    });

    test(
      'clearError restores previous file if one existed or initial if not',
      () async {
        // Case 1: no previous file
        fakePicker.exceptionToThrow = Exception('Fail');
        await cubit.pickFile();
        expect(cubit.state, isA<LeadImportFileError>());
        cubit.clearError();
        expect(cubit.state, equals(const LeadImportInitial()));

        // Case 2: had previous file
        fakePicker.exceptionToThrow = null;
        fakePicker.fileToReturn = validCsvFile;
        await cubit.pickFile();
        expect(cubit.state, equals(LeadImportFileSelected(validCsvFile)));

        fakePicker.exceptionToThrow = Exception('Fail 2');
        await cubit.pickFile();
        expect(cubit.state, isA<LeadImportFileError>());

        cubit.clearError();
        expect(cubit.state, equals(LeadImportFileSelected(validCsvFile)));
      },
    );
  });
}
