import 'dart:async';

import 'package:enterprise_crm/features/leads/data/services/lead_export_file_saver.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignee.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_summary.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_export_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_export_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements LeadRepository {
  LeadExportRequest? lastExportRequest;
  int exportLeadsCallCount = 0;
  bool shouldThrowOnExport = false;
  Completer<LeadExportResult>? exportCompleter;
  LeadExportResult exportResult = const LeadExportResult(
    fileReference: 'dummy_ref',
    fileName: 'leads_export.xlsx',
  );

  @override
  Future<LeadExportResult> exportLeads(LeadExportRequest request) async {
    exportLeadsCallCount++;
    lastExportRequest = request;
    if (exportCompleter != null) {
      return await exportCompleter!.future;
    }
    if (shouldThrowOnExport) {
      throw Exception('Repository export error');
    }
    return exportResult;
  }

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async =>
      const LeadPage(
        items: [],
        currentPage: 1,
        pageSize: 20,
        totalItems: 0,
        hasNext: false,
      );

  @override
  Future<LeadSummary> getLeadSummary() async => const LeadSummary(
    totalLeads: 0,
    assignedLeads: 0,
    unassignedLeads: 0,
    manualLeads: 0,
    excelLeads: 0,
    csvLeads: 0,
  );

  @override
  Future<Lead?> getLeadById(String leadId) async => null;

  @override
  Future<Lead> createLead(CreateLeadInput input) async =>
      throw UnimplementedError();

  @override
  Future<Lead> updateLead(UpdateLeadInput input) async =>
      throw UnimplementedError();

  @override
  Future<void> assignLead({
    required String leadId,
    required String assigneeId,
  }) async {}

  @override
  Future<void> assignLeads(LeadAssignmentRequest request) async {}

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) async {}

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async => const [];

  @override
  Future<LeadImportResult> importLeads(LeadImportRequest request) async =>
      throw UnimplementedError();
}

class _FakeLeadExportFileSaver implements LeadExportFileSaver {
  LeadExportResult? lastSavedResult;
  int saveCallCount = 0;
  bool shouldThrowOnSave = false;
  LeadExportSaveResult saveResult = const LeadExportSaveResult.saved();
  Completer<LeadExportSaveResult>? saveCompleter;

  @override
  Future<LeadExportSaveResult> save(LeadExportResult result) async {
    saveCallCount++;
    lastSavedResult = result;
    if (saveCompleter != null) {
      return await saveCompleter!.future;
    }
    if (shouldThrowOnSave) {
      throw Exception('File saver platform error');
    }
    return saveResult;
  }
}

void main() {
  group('LeadExportCubit', () {
    late _FakeRepository repository;
    late _FakeLeadExportFileSaver fileSaver;
    late LeadExportCubit cubit;

    setUp(() {
      repository = _FakeRepository();
      fileSaver = _FakeLeadExportFileSaver();
      cubit = LeadExportCubit(repository: repository, fileSaver: fileSaver);
    });

    tearDown(() {
      cubit.close();
    });

    test(
      'initial state has default Excel format, idle status, and no error',
      () {
        expect(cubit.state.status, LeadExportStatus.idle);
        expect(cubit.state.selectedFormat, LeadExportFormat.excel);
        expect(cubit.state.errorMessage, isNull);
        expect(cubit.state.isIdle, isTrue);
        expect(cubit.state.isBusy, isFalse);
        expect(cubit.state.isSuccess, isFalse);
        expect(cubit.state.isCancelled, isFalse);
        expect(cubit.state.isFailure, isFalse);
      },
    );

    test('selectFormat switches format and clears previous error', () {
      cubit.selectFormat(LeadExportFormat.csv);
      expect(cubit.state.selectedFormat, LeadExportFormat.csv);
      expect(cubit.state.status, LeadExportStatus.idle);
      expect(cubit.state.errorMessage, isNull);

      cubit.selectFormat(LeadExportFormat.excel);
      expect(cubit.state.selectedFormat, LeadExportFormat.excel);
    });

    test('selectFormat is ignored while busy', () async {
      repository.exportCompleter = Completer<LeadExportResult>();

      final exportFuture = cubit.export(query: const LeadQuery());
      expect(cubit.state.isBusy, isTrue);

      cubit.selectFormat(LeadExportFormat.csv);
      expect(cubit.state.selectedFormat, LeadExportFormat.excel);

      repository.exportCompleter!.complete(repository.exportResult);
      await exportFuture;
    });

    test(
      'export successfully transitions idle -> exporting -> saving -> success',
      () async {
        final emittedStates = <LeadExportState>[];
        final subscription = cubit.stream.listen(emittedStates.add);

        const testQuery = LeadQuery(searchText: 'Acme', isAssigned: true);
        await cubit.export(query: testQuery);
        await Future<void>.delayed(Duration.zero);

        expect(repository.exportLeadsCallCount, 1);
        expect(repository.lastExportRequest?.query, testQuery);
        expect(repository.lastExportRequest?.format, LeadExportFormat.excel);

        expect(fileSaver.saveCallCount, 1);
        expect(fileSaver.lastSavedResult, repository.exportResult);

        expect(emittedStates.map((s) => s.status).toList(), [
          LeadExportStatus.exporting,
          LeadExportStatus.saving,
          LeadExportStatus.success,
        ]);

        await subscription.cancel();
      },
    );

    test('export uses currently selected format (CSV)', () async {
      cubit.selectFormat(LeadExportFormat.csv);

      await cubit.export(query: const LeadQuery());

      expect(repository.lastExportRequest?.format, LeadExportFormat.csv);
      expect(fileSaver.saveCallCount, 1);
      expect(cubit.state.isSuccess, isTrue);
    });

    test(
      'export cancellation emits cancelled, retains format, and leaves error null',
      () async {
        fileSaver.saveResult = const LeadExportSaveResult.cancelled();

        cubit.selectFormat(LeadExportFormat.csv);
        final emittedStates = <LeadExportState>[];
        final subscription = cubit.stream.listen(emittedStates.add);

        await cubit.export(query: const LeadQuery());
        await Future<void>.delayed(Duration.zero);

        expect(repository.exportLeadsCallCount, 1);
        expect(fileSaver.saveCallCount, 1);

        expect(emittedStates.map((s) => s.status).toList(), [
          LeadExportStatus.exporting,
          LeadExportStatus.saving,
          LeadExportStatus.cancelled,
        ]);
        expect(cubit.state.isCancelled, isTrue);
        expect(cubit.state.errorMessage, isNull);
        expect(cubit.state.selectedFormat, LeadExportFormat.csv);

        // A subsequent export attempt is allowed
        fileSaver.saveResult = const LeadExportSaveResult.saved();
        await cubit.export(query: const LeadQuery());
        expect(cubit.state.isSuccess, isTrue);
        expect(repository.exportLeadsCallCount, 2);

        await subscription.cancel();
      },
    );

    test(
      'repository failure emits failure with safe message and does not call file saver',
      () async {
        repository.shouldThrowOnExport = true;

        final emittedStates = <LeadExportState>[];
        final subscription = cubit.stream.listen(emittedStates.add);

        await cubit.export(query: const LeadQuery());
        await Future<void>.delayed(Duration.zero);

        expect(repository.exportLeadsCallCount, 1);
        expect(fileSaver.saveCallCount, 0);

        expect(emittedStates.map((s) => s.status).toList(), [
          LeadExportStatus.exporting,
          LeadExportStatus.failure,
        ]);
        expect(cubit.state.isFailure, isTrue);
        expect(cubit.state.errorMessage, 'Unable to export Leads.');
        expect(cubit.state.selectedFormat, LeadExportFormat.excel);

        // Retry is possible
        repository.shouldThrowOnExport = false;
        await cubit.export(query: const LeadQuery());
        expect(cubit.state.isSuccess, isTrue);
        expect(repository.exportLeadsCallCount, 2);
        expect(fileSaver.saveCallCount, 1);

        await subscription.cancel();
      },
    );

    test(
      'file saver failure emits failure with safe message and retains format',
      () async {
        fileSaver.shouldThrowOnSave = true;

        final emittedStates = <LeadExportState>[];
        final subscription = cubit.stream.listen(emittedStates.add);

        await cubit.export(query: const LeadQuery());
        await Future<void>.delayed(Duration.zero);

        expect(repository.exportLeadsCallCount, 1);
        expect(fileSaver.saveCallCount, 1);

        expect(emittedStates.map((s) => s.status).toList(), [
          LeadExportStatus.exporting,
          LeadExportStatus.saving,
          LeadExportStatus.failure,
        ]);
        expect(cubit.state.isFailure, isTrue);
        expect(cubit.state.errorMessage, 'Unable to export Leads.');
        expect(cubit.state.selectedFormat, LeadExportFormat.excel);

        // Retry is possible
        fileSaver.shouldThrowOnSave = false;
        await cubit.export(query: const LeadQuery());
        expect(cubit.state.isSuccess, isTrue);
        expect(repository.exportLeadsCallCount, 2);
        expect(fileSaver.saveCallCount, 2);

        await subscription.cancel();
      },
    );

    test('concurrent / double submit is blocked while busy', () async {
      repository.exportCompleter = Completer<LeadExportResult>();

      final firstCall = cubit.export(query: const LeadQuery());
      expect(cubit.state.isBusy, isTrue);

      // Second export call while busy
      final secondCall = cubit.export(query: const LeadQuery());

      expect(repository.exportLeadsCallCount, 1);

      repository.exportCompleter!.complete(repository.exportResult);
      await firstCall;
      await secondCall;

      expect(repository.exportLeadsCallCount, 1);
      expect(fileSaver.saveCallCount, 1);
      expect(cubit.state.isSuccess, isTrue);
    });
  });
}
