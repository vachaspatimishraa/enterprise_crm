import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignee.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_form_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_form_state.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_list_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_list_state.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLeadRepository implements LeadRepository {
  List<Lead> leads = [];
  bool shouldThrow = false;
  String errorMessage = 'Repository error';
  LeadQuery? lastQuery;

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async {
    lastQuery = query;
    if (shouldThrow) throw Exception(errorMessage);
    return LeadPage(
      items: leads,
      currentPage: query.page,
      pageSize: query.pageSize,
      totalItems: leads.length,
      hasNext: false,
    );
  }

  @override
  Future<Lead?> getLeadById(String leadId) async {
    if (shouldThrow) throw Exception(errorMessage);
    return leads.cast<Lead?>().firstWhere(
      (l) => l?.id == leadId,
      orElse: () => null,
    );
  }

  @override
  Future<Lead> createLead(CreateLeadInput input) async {
    if (shouldThrow) throw Exception(errorMessage);
    final lead = Lead(
      id: 'generated-id',
      name: input.draft.name,
      phone: input.draft.phone,
      email: input.draft.email,
      status: input.draft.status,
      source: input.draft.source ?? const Lead(id: '').source,
    );
    leads.add(lead);
    return lead;
  }

  @override
  Future<Lead> updateLead(UpdateLeadInput input) async {
    if (shouldThrow) throw Exception(errorMessage);
    final index = leads.indexWhere((l) => l.id == input.leadId);
    final updated = Lead(
      id: input.leadId,
      name: input.draft.name,
      phone: input.draft.phone,
      email: input.draft.email,
      status: input.draft.status,
      source: input.draft.source ?? const Lead(id: '').source,
    );
    if (index != -1) {
      leads[index] = updated;
    }
    return updated;
  }

  @override
  Future<void> assignLead({
    required String leadId,
    required String assigneeId,
  }) async {
    if (shouldThrow) throw Exception(errorMessage);
  }

  @override
  Future<void> assignLeads(LeadAssignmentRequest request) async {
    if (shouldThrow) throw Exception(errorMessage);
  }

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) async {
    if (shouldThrow) throw Exception(errorMessage);
  }

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async => const [];

  @override
  Future<LeadImportResult> importLeads(LeadImportRequest request) async =>
      const LeadImportResult(
        totalRows: 0,
        importedRows: 0,
        skippedRows: 0,
        failedRows: 0,
        duplicateRows: 0,
      );

  @override
  Future<LeadExportResult> exportLeads(LeadExportRequest request) async =>
      const LeadExportResult(
        fileReference: 'mock-export',
        fileName: 'leads.xlsx',
      );
}

void main() {
  late FakeLeadRepository repository;

  setUp(() {
    repository = FakeLeadRepository();
  });

  group('LeadListCubit', () {
    test('initial state is LeadListInitial', () {
      final cubit = LeadListCubit(repository);
      expect(cubit.state, isA<LeadListInitial>());
      expect(cubit.currentQuery, equals(const LeadQuery()));
    });

    test('emits [Loading, Loaded] when leads are returned', () async {
      repository.leads = [
        const Lead(id: '1', name: 'John Doe'),
        const Lead(id: '2', name: 'Jane Doe'),
      ];

      final cubit = LeadListCubit(repository);
      final states = <LeadListState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadLeads();
      await pumpEventQueue();

      expect(states, [
        isA<LeadListLoading>(),
        isA<LeadListLoaded>().having((s) => s.leads.length, 'length', 2),
      ]);
      await sub.cancel();
    });

    test('emits [Loading, Empty] when no leads are returned', () async {
      repository.leads = [];

      final cubit = LeadListCubit(repository);
      final states = <LeadListState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadLeads();
      await pumpEventQueue();

      expect(states, [isA<LeadListLoading>(), isA<LeadListEmpty>()]);
      await sub.cancel();
    });

    test('emits [Loading, Failure] when repository throws error', () async {
      repository.shouldThrow = true;
      repository.errorMessage = 'Network connection failed';

      final cubit = LeadListCubit(repository);
      final states = <LeadListState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadLeads();
      await pumpEventQueue();

      expect(states, [
        isA<LeadListLoading>(),
        isA<LeadListFailure>().having(
          (s) => s.message,
          'message',
          'Network connection failed',
        ),
      ]);
      await sub.cancel();
    });

    test(
      'propagates query and maintains state on applyQuery and clearFilters',
      () async {
        final cubit = LeadListCubit(repository);
        const query = LeadQuery(searchText: 'Rahul');

        await cubit.applyQuery(query);
        await pumpEventQueue();
        expect(cubit.currentQuery, equals(query));
        expect(repository.lastQuery, equals(query));

        await cubit.clearFilters();
        await pumpEventQueue();
        expect(cubit.currentQuery, equals(const LeadQuery()));
        expect(repository.lastQuery, equals(const LeadQuery()));
      },
    );
  });

  group('LeadFormCubit', () {
    test('initial state is LeadFormInitial', () {
      final cubit = LeadFormCubit(repository);
      expect(cubit.state, isA<LeadFormInitial>());
    });

    test('emits [Submitting, Success] on successful createLead', () async {
      final cubit = LeadFormCubit(repository);
      const draft = LeadDraft(name: 'New Lead');

      final states = <LeadFormState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.createLead(draft);
      await pumpEventQueue();

      expect(states, [
        isA<LeadFormSubmitting>(),
        isA<LeadFormSuccess>().having((s) => s.lead.name, 'name', 'New Lead'),
      ]);
      expect(repository.leads.length, 1);
      await sub.cancel();
    });

    test(
      'emits [Submitting, Failure] on repository error during createLead',
      () async {
        repository.shouldThrow = true;
        repository.errorMessage = 'Duplicate lead';

        final cubit = LeadFormCubit(repository);
        const draft = LeadDraft(name: 'New Lead');

        final states = <LeadFormState>[];
        final sub = cubit.stream.listen(states.add);

        await cubit.createLead(draft);
        await pumpEventQueue();

        expect(states, [
          isA<LeadFormSubmitting>(),
          isA<LeadFormFailure>().having(
            (s) => s.message,
            'message',
            'Duplicate lead',
          ),
        ]);
        await sub.cancel();
      },
    );

    test('emits [Submitting, Success] on successful updateLead', () async {
      repository.leads = [const Lead(id: '10', name: 'Old Name')];
      final cubit = LeadFormCubit(repository);
      const draft = LeadDraft(name: 'Updated Name');

      final states = <LeadFormState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.updateLead('10', draft);
      await pumpEventQueue();

      expect(states, [
        isA<LeadFormSubmitting>(),
        isA<LeadFormSuccess>().having(
          (s) => s.lead.name,
          'name',
          'Updated Name',
        ),
      ]);
      expect(repository.leads.first.name, 'Updated Name');
      await sub.cancel();
    });

    test('reset emits LeadFormInitial', () {
      final cubit = LeadFormCubit(repository);
      cubit.reset();
      expect(cubit.state, isA<LeadFormInitial>());
    });
  });
}
