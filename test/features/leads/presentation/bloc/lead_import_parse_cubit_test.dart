import 'dart:async';
import 'dart:typed_data';

import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_parse_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_parse_state.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_parsed_file.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_selected_file.dart';
import 'package:enterprise_crm/features/leads/presentation/services/lead_import_parser.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLeadImportParser implements LeadImportParser {
  LeadImportParsedFile? fileToReturn;
  Exception? exceptionToThrow;
  Completer<LeadImportParsedFile>? delayCompleter;
  int parseCallsCount = 0;

  @override
  Future<LeadImportParsedFile> parse(LeadImportSelectedFile file) async {
    parseCallsCount++;
    if (delayCompleter != null) {
      final delayed = await delayCompleter!.future;
      return delayed;
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return fileToReturn!;
  }
}

void main() {
  group('LeadImportParseCubit', () {
    late FakeLeadImportParser fakeParser;
    late LeadImportParseCubit cubit;

    setUp(() {
      fakeParser = FakeLeadImportParser();
      cubit = LeadImportParseCubit(fakeParser);
    });

    tearDown(() {
      cubit.close();
    });

    final testSelectedFile = LeadImportSelectedFile(
      name: 'leads.csv',
      extension: 'csv',
      sizeBytes: 1024,
      source: LeadSource.csv,
      content: InMemoryLeadImportFileContent(Uint8List(0)),
    );

    final testParsedFile = LeadImportParsedFile(
      fileName: 'leads.csv',
      source: LeadSource.csv,
      sheets: [
        LeadImportParsedSheet(
          name: 'CSV',
          rows: [
            ['Name', 'Email'],
            ['Alice', 'alice@example.com'],
          ],
        ),
      ],
    );

    test('initial state is LeadImportParseInitial', () {
      expect(cubit.state, isA<LeadImportParseInitial>());
    });

    test(
      'emits [LeadImportParsing, LeadImportParseSuccess] on successful parse',
      () async {
        fakeParser.fileToReturn = testParsedFile;

        final future = cubit.parse(testSelectedFile);
        expect(cubit.state, isA<LeadImportParsing>());
        await future;

        expect(cubit.state, equals(LeadImportParseSuccess(testParsedFile)));
      },
    );

    test(
      'emits [LeadImportParsing, LeadImportParseFailure] on LeadImportParseException',
      () async {
        fakeParser.exceptionToThrow = const LeadImportParseException(
          'Unable to read this CSV file.',
        );

        await cubit.parse(testSelectedFile);

        expect(
          cubit.state,
          equals(const LeadImportParseFailure('Unable to read this CSV file.')),
        );
      },
    );

    test(
      'emits [LeadImportParsing, LeadImportParseFailure] with safe message on unknown error',
      () async {
        fakeParser.exceptionToThrow = Exception('Internal crash');

        await cubit.parse(testSelectedFile);

        expect(
          cubit.state,
          equals(const LeadImportParseFailure('Failed to parse import file.')),
        );
      },
    );

    test(
      'prevents duplicate parse invocations while already parsing',
      () async {
        final completer = Completer<LeadImportParsedFile>();
        fakeParser.delayCompleter = completer;

        final firstParse = cubit.parse(testSelectedFile);
        expect(cubit.state, isA<LeadImportParsing>());
        expect(fakeParser.parseCallsCount, equals(1));

        // Second parse while first is pending
        final secondParse = cubit.parse(testSelectedFile);
        expect(fakeParser.parseCallsCount, equals(1)); // Not invoked again

        completer.complete(testParsedFile);
        await firstParse;
        await secondParse;

        expect(cubit.state, equals(LeadImportParseSuccess(testParsedFile)));
      },
    );

    test('reset resets state back to LeadImportParseInitial', () async {
      fakeParser.fileToReturn = testParsedFile;
      await cubit.parse(testSelectedFile);
      expect(cubit.state, isA<LeadImportParseSuccess>());

      cubit.reset();
      expect(cubit.state, isA<LeadImportParseInitial>());
    });
  });
}
