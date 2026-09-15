import 'dart:async';

import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_execution_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_execution_state.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_preview.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_review.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadRepository implements LeadRepository {
  int importCalls = 0;
  LeadImportRequest? lastRequest;
  Completer<LeadImportResult>? completer;
  bool shouldThrow = false;
  LeadImportResult? resultToReturn;

  @override
  Future<LeadImportResult> importLeads(LeadImportRequest request) async {
    importCalls++;
    lastRequest = request;

    if (completer != null) {
      return completer!.future;
    }

    if (shouldThrow) {
      throw Exception('Database/Network error');
    }

    if (resultToReturn != null) {
      return resultToReturn!;
    }

    return LeadImportResult(
      totalRows: request.drafts.length,
      importedRows: request.drafts.length,
      skippedRows: 0,
      failedRows: 0,
      duplicateRows: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeLeadRepository repository;
  late LeadImportExecutionCubit cubit;

  final samplePreview = LeadImportPreview(
    fileName: 'test.csv',
    source: LeadSource.csv,
    sheetIndex: 0,
    sheetName: 'Sheet1',
    headerRowIndex: 0,
    mapping: const LeadImportColumnMapping(
      sheetIndex: 0,
      headerRowIndex: 0,
      nameColumnIndex: 0,
    ),
    rows: const [
      LeadImportPreviewRow(
        sourceRowIndex: 1,
        name: 'Lead 1',
        status: LeadImportPreviewRowStatus.valid,
      ),
    ],
  );

  final sampleDecision = LeadImportReviewDecision({1});

  setUp(() {
    repository = _FakeLeadRepository();
    cubit = LeadImportExecutionCubit(repository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  group('LeadImportExecutionCubit', () {
    test('initial state is LeadImportExecutionInitial', () {
      expect(cubit.state, isA<LeadImportExecutionInitial>());
    });

    test(
      'successful execution flows from Executing to Success with exact result',
      () async {
        final states = <LeadImportExecutionState>[];
        cubit.stream.listen(states.add);

        await cubit.execute(preview: samplePreview, decision: sampleDecision);
        await pumpEventQueue();

        expect(states.length, equals(2));
        expect(states[0], isA<LeadImportExecuting>());
        expect(states[1], isA<LeadImportExecutionSuccess>());

        final success = states[1] as LeadImportExecutionSuccess;
        expect(success.result.totalRows, equals(1));
        expect(success.result.importedRows, equals(1));
        expect(success.preview, equals(samplePreview));
        expect(success.decision, equals(sampleDecision));
        expect(repository.importCalls, equals(1));
      },
    );

    test(
      'preparation failure emits non-retriable LeadImportExecutionFailure with safe message',
      () async {
        final states = <LeadImportExecutionState>[];
        cubit.stream.listen(states.add);

        // Empty decision triggers preparation exception
        final emptyDecision = LeadImportReviewDecision({});

        await cubit.execute(preview: samplePreview, decision: emptyDecision);
        await pumpEventQueue();

        expect(states.length, equals(2));
        expect(states[0], isA<LeadImportExecuting>());
        expect(states[1], isA<LeadImportExecutionFailure>());

        final failure = states[1] as LeadImportExecutionFailure;
        expect(
          failure.message,
          equals('The selected import rows are no longer valid.'),
        );
        expect(failure.canRetry, isFalse);
        expect(failure.preview, equals(samplePreview));
        expect(failure.decision, equals(emptyDecision));
        expect(repository.importCalls, equals(0));
      },
    );

    test(
      'repository failure emits retriable LeadImportExecutionFailure with safe user message',
      () async {
        repository.shouldThrow = true;

        final states = <LeadImportExecutionState>[];
        cubit.stream.listen(states.add);

        await cubit.execute(preview: samplePreview, decision: sampleDecision);
        await pumpEventQueue();

        expect(states.length, equals(2));
        expect(states[0], isA<LeadImportExecuting>());
        expect(states[1], isA<LeadImportExecutionFailure>());

        final failure = states[1] as LeadImportExecutionFailure;
        expect(failure.message, equals('Unable to import the selected Leads.'));
        expect(failure.canRetry, isTrue);
        // Does not leak exception type or stack trace
        expect(failure.message.contains('Exception'), isFalse);
        expect(failure.preview, equals(samplePreview));
        expect(failure.decision, equals(sampleDecision));
        expect(repository.importCalls, equals(1));
      },
    );

    test(
      'rejects negative result counts from repository and emits retriable failure',
      () async {
        repository.resultToReturn = const LeadImportResult(
          totalRows: 1,
          importedRows: -1,
          skippedRows: 0,
          failedRows: 0,
          duplicateRows: 0,
        );

        final states = <LeadImportExecutionState>[];
        cubit.stream.listen(states.add);

        await cubit.execute(preview: samplePreview, decision: sampleDecision);
        await pumpEventQueue();

        expect(states.length, equals(2));
        expect(states[0], isA<LeadImportExecuting>());
        expect(states[1], isA<LeadImportExecutionFailure>());

        final failure = states[1] as LeadImportExecutionFailure;
        expect(failure.message, equals('Unable to import the selected Leads.'));
        expect(failure.canRetry, isTrue);
        expect(repository.importCalls, equals(1));
      },
    );

    test(
      'duplicate concurrent execute call while Executing is ignored',
      () async {
        repository.completer = Completer<LeadImportResult>();

        // Launch first execution (async, held by completer)
        final future1 = cubit.execute(
          preview: samplePreview,
          decision: sampleDecision,
        );
        expect(cubit.state, isA<LeadImportExecuting>());

        // Attempt second execution while still executing
        final future2 = cubit.execute(
          preview: samplePreview,
          decision: sampleDecision,
        );

        expect(repository.importCalls, equals(1));

        // Complete the first call
        repository.completer!.complete(
          const LeadImportResult(
            totalRows: 1,
            importedRows: 1,
            skippedRows: 0,
            failedRows: 0,
            duplicateRows: 0,
          ),
        );

        await Future.wait([future1, future2]);

        expect(repository.importCalls, equals(1));
        expect(cubit.state, isA<LeadImportExecutionSuccess>());
      },
    );

    test(
      'retry re-executes with identical preview and decision after failure',
      () async {
        repository.shouldThrow = true;

        await cubit.execute(preview: samplePreview, decision: sampleDecision);
        expect(cubit.state, isA<LeadImportExecutionFailure>());
        expect(repository.importCalls, equals(1));

        // Fix failure condition and retry
        repository.shouldThrow = false;
        await cubit.retry();

        expect(repository.importCalls, equals(2));
        expect(cubit.state, isA<LeadImportExecutionSuccess>());
        final success = cubit.state as LeadImportExecutionSuccess;
        expect(success.preview, equals(samplePreview));
        expect(success.decision, equals(sampleDecision));
      },
    );

    test('calling retry when not in failure state does nothing', () async {
      await cubit.retry();
      expect(cubit.state, isA<LeadImportExecutionInitial>());
      expect(repository.importCalls, equals(0));
    });

    test(
      'calling retry when canRetry is false does not call repository',
      () async {
        final emptyDecision = LeadImportReviewDecision({});
        await cubit.execute(preview: samplePreview, decision: emptyDecision);
        expect(cubit.state, isA<LeadImportExecutionFailure>());
        final failure = cubit.state as LeadImportExecutionFailure;
        expect(failure.canRetry, isFalse);
        expect(repository.importCalls, equals(0));

        await cubit.retry();
        expect(repository.importCalls, equals(0));
      },
    );
  });
}
