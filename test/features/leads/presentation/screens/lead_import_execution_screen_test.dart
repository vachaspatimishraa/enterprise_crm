import 'dart:async';

import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_import_execution_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_preview.dart';
import 'package:enterprise_crm/features/leads/presentation/models/lead_import_review.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_import_execution_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExecutionLeadRepository implements LeadRepository {
  Completer<LeadImportResult>? completer;
  bool shouldThrow = false;
  int importCalls = 0;

  @override
  Future<LeadImportResult> importLeads(LeadImportRequest request) async {
    importCalls++;
    if (completer != null) {
      return completer!.future;
    }
    if (shouldThrow) {
      throw Exception('Network error');
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
        name: 'Alice',
        status: LeadImportPreviewRowStatus.valid,
      ),
    ],
  );

  final sampleDecision = LeadImportReviewDecision({1});

  Widget buildScreen({
    required LeadImportPreview preview,
    required LeadImportReviewDecision decision,
    required VoidCallback onDone,
    VoidCallback? onCancel,
    required LeadImportExecutionCubit cubit,
  }) {
    return MaterialApp(
      home: LeadImportExecutionScreen(
        preview: preview,
        decision: decision,
        onDone: onDone,
        onCancel: onCancel,
        cubit: cubit,
      ),
    );
  }

  group('LeadImportExecutionScreen', () {
    testWidgets('shows progress indicator and importing text while executing', (
      tester,
    ) async {
      final repository = _FakeExecutionLeadRepository();
      repository.completer = Completer<LeadImportResult>();
      final cubit = LeadImportExecutionCubit(repository: repository);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        buildScreen(
          preview: samplePreview,
          decision: sampleDecision,
          onDone: () {},
          cubit: cubit,
        ),
      );

      // Trigger execution
      cubit.execute(preview: samplePreview, decision: sampleDecision);
      await tester.pump();

      expect(
        find.byKey(const Key('lead_import_execution_progress_indicator')),
        findsOneWidget,
      );
      expect(find.text('Importing Leads...'), findsOneWidget);
    });

    testWidgets(
      'shows safe message and Retry button on repository failure, and tapping Retry re-executes',
      (tester) async {
        final repository = _FakeExecutionLeadRepository()..shouldThrow = true;
        final cubit = LeadImportExecutionCubit(repository: repository);
        addTearDown(cubit.close);

        await tester.pumpWidget(
          buildScreen(
            preview: samplePreview,
            decision: sampleDecision,
            onDone: () {},
            cubit: cubit,
          ),
        );

        await cubit.execute(preview: samplePreview, decision: sampleDecision);
        await tester.pumpAndSettle();

        expect(
          find.text('Unable to import the selected Leads.'),
          findsOneWidget,
        );
        final retryButton = find.byKey(
          const Key('lead_import_execution_retry_button'),
        );
        expect(retryButton, findsOneWidget);

        // Fix failure condition and tap retry
        repository.shouldThrow = false;
        await tester.tap(retryButton);
        await tester.pumpAndSettle();

        expect(repository.importCalls, equals(2));
        expect(find.text('Import Complete'), findsWidgets);
      },
    );

    testWidgets(
      'shows safe message without Retry button on preparation failure, and Cancel button works',
      (tester) async {
        final repository = _FakeExecutionLeadRepository();
        final cubit = LeadImportExecutionCubit(repository: repository);
        addTearDown(cubit.close);
        int cancelCalls = 0;

        await tester.pumpWidget(
          buildScreen(
            preview: samplePreview,
            decision: sampleDecision,
            onDone: () {},
            onCancel: () => cancelCalls++,
            cubit: cubit,
          ),
        );

        // Execute with empty decision causing preparation failure
        await cubit.execute(
          preview: samplePreview,
          decision: LeadImportReviewDecision({}),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('The selected import rows are no longer valid.'),
          findsOneWidget,
        );
        // Retry button must NOT be present
        expect(
          find.byKey(const Key('lead_import_execution_retry_button')),
          findsNothing,
        );

        // Cancel button is present and clickable
        final cancelButton = find.byKey(
          const Key('lead_import_execution_failure_cancel_button'),
        );
        expect(cancelButton, findsOneWidget);
        await tester.tap(cancelButton);
        expect(cancelCalls, equals(1));
      },
    );

    testWidgets('renders result UI on successful execution', (tester) async {
      final repository = _FakeExecutionLeadRepository();
      final cubit = LeadImportExecutionCubit(repository: repository);
      addTearDown(cubit.close);
      int doneCalls = 0;

      await tester.pumpWidget(
        buildScreen(
          preview: samplePreview,
          decision: sampleDecision,
          onDone: () => doneCalls++,
          cubit: cubit,
        ),
      );

      await cubit.execute(preview: samplePreview, decision: sampleDecision);
      await tester.pumpAndSettle();

      expect(find.text('Import Complete'), findsWidgets);
      expect(
        find.byKey(const Key('lead_import_result_importer_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('lead_import_result_review_summary_card')),
        findsOneWidget,
      );

      final doneButton = find.byKey(
        const Key('lead_import_result_done_button'),
      );
      expect(doneButton, findsOneWidget);
      await tester.ensureVisible(doneButton);
      await tester.tap(doneButton);
      expect(doneCalls, equals(1));
    });
  });
}
