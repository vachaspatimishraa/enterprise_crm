import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_sort.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockLeadRepository repository;

  setUp(() {
    repository = MockLeadRepository(dataSource: MockLeadDataSource());
  });

  group('MockLeadRepository - Retrieval', () {
    test('returns initial dataset in LeadPage', () async {
      final page = await repository.getLeads();
      expect(page.items.length, 8);
      expect(page.totalItems, 8);
      expect(page.currentPage, 1);
      expect(page.hasNext, isFalse);
    });

    test('lookup existing ID returns lead', () async {
      final lead = await repository.getLeadById('mock-lead-1');
      expect(lead, isNotNull);
      expect(lead!.id, 'mock-lead-1');
      expect(lead.name, 'Aarav Sharma');
    });

    test('lookup unknown ID returns null without throwing', () async {
      final lead = await repository.getLeadById('unknown-id');
      expect(lead, isNull);
    });
  });

  group('MockLeadRepository - Search', () {
    test('searches case-insensitively by name', () async {
      final page = await repository.getLeads(
        const LeadQuery(searchText: 'aarav'),
      );
      expect(page.items.length, 1);
      expect(page.items.first.id, 'mock-lead-1');
    });

    test('searches by phone substring', () async {
      final page = await repository.getLeads(
        const LeadQuery(searchText: '98111'),
      );
      expect(page.items.length, 1);
      expect(page.items.first.id, 'mock-lead-2');
    });

    test('searches by email substring', () async {
      final page = await repository.getLeads(
        const LeadQuery(searchText: 'rohan.mehta'),
      );
      expect(page.items.length, 1);
      expect(page.items.first.id, 'mock-lead-3');
    });
  });

  group('MockLeadRepository - Filters', () {
    test('filters by source', () async {
      final manual = await repository.getLeads(
        const LeadQuery(source: LeadSource.manual),
      );
      expect(manual.items.every((l) => l.source == LeadSource.manual), isTrue);

      final excel = await repository.getLeads(
        const LeadQuery(source: LeadSource.excel),
      );
      expect(excel.items.every((l) => l.source == LeadSource.excel), isTrue);

      final csv = await repository.getLeads(
        const LeadQuery(source: LeadSource.csv),
      );
      expect(csv.items.every((l) => l.source == LeadSource.csv), isTrue);
    });

    test('filters by status', () async {
      final page = await repository.getLeads(
        const LeadQuery(status: LeadStatus('Sample New')),
      );
      expect(page.items.length, 3);
      expect(
        page.items.every((l) => l.status == const LeadStatus('Sample New')),
        isTrue,
      );
    });

    test('filters by assigned user', () async {
      final page = await repository.getLeads(
        const LeadQuery(assignedUserId: 'agent-1'),
      );
      expect(page.items.length, 2);
      expect(page.items.every((l) => l.assignedUserId == 'agent-1'), isTrue);
    });

    test('filters assigned only', () async {
      final page = await repository.getLeads(const LeadQuery(isAssigned: true));
      expect(page.items.length, 4);
      expect(page.items.every((l) => l.isAssigned), isTrue);
    });

    test('filters unassigned only', () async {
      final page = await repository.getLeads(
        const LeadQuery(isAssigned: false),
      );
      expect(page.items.length, 4);
      expect(page.items.every((l) => !l.isAssigned), isTrue);
    });
  });

  group('MockLeadRepository - Pagination', () {
    test('paginates results correctly across pages', () async {
      final page1 = await repository.getLeads(
        const LeadQuery(page: 1, pageSize: 3),
      );
      expect(page1.items.length, 3);
      expect(page1.currentPage, 1);
      expect(page1.totalItems, 8);
      expect(page1.hasNext, isTrue);

      final page2 = await repository.getLeads(
        const LeadQuery(page: 2, pageSize: 3),
      );
      expect(page2.items.length, 3);
      expect(page2.currentPage, 2);
      expect(page2.hasNext, isTrue);

      final page3 = await repository.getLeads(
        const LeadQuery(page: 3, pageSize: 3),
      );
      expect(page3.items.length, 2);
      expect(page3.currentPage, 3);
      expect(page3.hasNext, isFalse);

      final pageOut = await repository.getLeads(
        const LeadQuery(page: 10, pageSize: 3),
      );
      expect(pageOut.items, isEmpty);
      expect(pageOut.hasNext, isFalse);
    });
  });

  group('MockLeadRepository - Create & Update', () {
    test('creates lead with unique ID and makes it retrievable', () async {
      final created = await repository.createLead(
        const CreateLeadInput(
          draft: LeadDraft(
            name: 'New Mock Lead',
            phone: '+91 9123456780',
            email: 'new.mock@example.com',
            status: LeadStatus('Sample New'),
            source: LeadSource.manual,
          ),
        ),
      );

      expect(created.id, startsWith('mock-lead-'));
      expect(created.name, 'New Mock Lead');

      final fetched = await repository.getLeadById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'New Mock Lead');
    });

    test('updates lead and preserves unmodified fields', () async {
      final updated = await repository.updateLead(
        const UpdateLeadInput(
          leadId: 'mock-lead-1',
          draft: LeadDraft(name: 'Aarav Updated'),
        ),
      );

      expect(updated.name, 'Aarav Updated');
      expect(updated.phone, '+91 9876543210');
      expect(updated.email, 'aarav.sharma@example.com');
      expect(updated.assignedUserId, 'agent-1');

      final fetched = await repository.getLeadById('mock-lead-1');
      expect(fetched!.name, 'Aarav Updated');
    });
  });

  group('MockLeadRepository - Assignment & Reassignment', () {
    test('returns assignable users list', () async {
      final users = await repository.getAssignableUsers();
      expect(users.length, 3);
      expect(users.first.displayName, 'Mock Agent One');
    });

    test('assigns single lead', () async {
      await repository.assignLead(leadId: 'mock-lead-2', assigneeId: 'agent-3');
      final lead = await repository.getLeadById('mock-lead-2');
      expect(lead!.assignedUserId, 'agent-3');
      expect(lead.assignedUserName, 'Mock Agent Three');
      expect(lead.isAssigned, isTrue);
    });

    test('assigns multiple leads in bulk', () async {
      await repository.assignLeads(
        const LeadAssignmentRequest(
          leadIds: ['mock-lead-2', 'mock-lead-4'],
          assigneeId: 'agent-2',
        ),
      );

      final lead2 = await repository.getLeadById('mock-lead-2');
      final lead4 = await repository.getLeadById('mock-lead-4');
      expect(lead2!.assignedUserId, 'agent-2');
      expect(lead4!.assignedUserId, 'agent-2');
    });

    test('reassigns lead to new agent', () async {
      await repository.reassignLead(
        const LeadReassignmentRequest(
          leadId: 'mock-lead-1',
          newAssigneeId: 'agent-2',
          reason: 'Workload balancing',
        ),
      );

      final lead = await repository.getLeadById('mock-lead-1');
      expect(lead!.assignedUserId, 'agent-2');
      expect(lead.assignedUserName, 'Mock Agent Two');
    });
  });

  group('MockLeadRepository - Import & Export placeholders', () {
    test('returns deterministic mock import result', () async {
      final result = await repository.importLeads(
        const LeadImportRequest(
          fileReference: 'dummy-ref',
          fileName: 'leads.xlsx',
          fileType: LeadImportFileType.excel,
        ),
      );

      expect(result.totalRows, 10);
      expect(result.importedRows, 8);
      expect(result.duplicateRows, 1);
    });

    test('returns deterministic mock export result', () async {
      final result = await repository.exportLeads(
        const LeadExportRequest(
          query: LeadQuery(),
          format: LeadExportFormat.excel,
        ),
      );

      expect(result.fileName, 'mock_leads_export.xlsx');
      expect(result.fileReference, 'mock-export-ref-excel');
    });
  });

  group('MockLeadRepository - Lead Summary & Pagination Independence', () {
    test(
      'aggregates summary across all leads even when total leads > page size',
      () async {
        // Create 25 leads (where default LeadQuery pageSize is 20)
        // Page 1 (first 20 items):
        // - 12 assigned (agent-1), 8 unassigned
        // - 8 manual, 7 excel, 5 csv
        // Page 2 (items 21..25):
        // - 3 assigned (agent-2), 2 unassigned
        // - 2 manual, 2 excel, 1 csv
        // Full dataset totals:
        // - Total: 25
        // - Assigned: 15 (12 + 3)
        // - Unassigned: 10 (8 + 2)
        // - Manual: 10 (8 + 2)
        // - Excel: 9 (7 + 2)
        // - CSV: 6 (5 + 1)
        final customLeads = <Lead>[
          ...List.generate(
            8,
            (i) => Lead(
              id: 'lead-p1-man-asg-$i',
              source: LeadSource.manual,
              assignedUserId: 'agent-1',
            ),
          ),
          ...List.generate(
            4,
            (i) => Lead(
              id: 'lead-p1-exc-asg-$i',
              source: LeadSource.excel,
              assignedUserId: 'agent-1',
            ),
          ),
          ...List.generate(
            3,
            (i) => Lead(
              id: 'lead-p1-exc-unasg-$i',
              source: LeadSource.excel,
              assignedUserId: null,
            ),
          ),
          ...List.generate(
            5,
            (i) => Lead(
              id: 'lead-p1-csv-unasg-$i',
              source: LeadSource.csv,
              assignedUserId: null,
            ),
          ),
          // Records beyond page 1 (indexes 20..24):
          ...List.generate(
            2,
            (i) => Lead(
              id: 'lead-p2-man-asg-$i',
              source: LeadSource.manual,
              assignedUserId: 'agent-2',
            ),
          ),
          ...List.generate(
            1,
            (i) => Lead(
              id: 'lead-p2-exc-asg-$i',
              source: LeadSource.excel,
              assignedUserId: 'agent-2',
            ),
          ),
          ...List.generate(
            1,
            (i) => Lead(
              id: 'lead-p2-exc-unasg-$i',
              source: LeadSource.excel,
              assignedUserId: null,
            ),
          ),
          ...List.generate(
            1,
            (i) => Lead(
              id: 'lead-p2-csv-unasg-$i',
              source: LeadSource.csv,
              assignedUserId: null,
            ),
          ),
        ];

        expect(customLeads.length, 25);

        final largeRepo = MockLeadRepository(
          dataSource: MockLeadDataSource(initialLeads: customLeads),
        );

        // Verify that standard getLeads only returns first page of 20
        final page1 = await largeRepo.getLeads();
        expect(page1.items.length, 20);
        expect(page1.totalItems, 25);
        expect(page1.hasNext, isTrue);

        // Verify that getLeadSummary aggregates the full dataset of 25 leads,
        // not just the 20 items on page 1.
        final summary = await largeRepo.getLeadSummary();
        expect(summary.totalLeads, 25);
        expect(summary.assignedLeads, 15);
        expect(summary.unassignedLeads, 10);
        expect(summary.manualLeads, 10);
        expect(summary.excelLeads, 9);
        expect(summary.csvLeads, 6);
      },
    );
  });

  group('MockLeadRepository - Sorting', () {
    test('sorts by Name A–Z case-insensitively', () async {
      final customLeads = [
        const Lead(id: 'l-1', name: 'charlie'),
        const Lead(id: 'l-2', name: 'Alice'),
        const Lead(id: 'l-3', name: 'bob'),
      ];
      final repo = MockLeadRepository(
        dataSource: MockLeadDataSource(initialLeads: customLeads),
      );

      final result = await repo.getLeads(
        const LeadQuery(
          sort: LeadSort(
            field: LeadSortField.name,
            direction: LeadSortDirection.ascending,
          ),
        ),
      );

      expect(result.items.map((l) => l.name).toList(), [
        'Alice',
        'bob',
        'charlie',
      ]);
    });

    test('sorts by Name Z–A case-insensitively', () async {
      final customLeads = [
        const Lead(id: 'l-1', name: 'charlie'),
        const Lead(id: 'l-2', name: 'Alice'),
        const Lead(id: 'l-3', name: 'bob'),
      ];
      final repo = MockLeadRepository(
        dataSource: MockLeadDataSource(initialLeads: customLeads),
      );

      final result = await repo.getLeads(
        const LeadQuery(
          sort: LeadSort(
            field: LeadSortField.name,
            direction: LeadSortDirection.descending,
          ),
        ),
      );

      expect(result.items.map((l) => l.name).toList(), [
        'charlie',
        'bob',
        'Alice',
      ]);
    });

    test(
      'places null and whitespace/empty names last in Name A–Z and Name Z–A',
      () async {
        final customLeads = [
          const Lead(id: 'l-empty', name: '   '),
          const Lead(id: 'l-bob', name: 'bob'),
          const Lead(id: 'l-null', name: null),
          const Lead(id: 'l-alice', name: 'Alice'),
        ];
        final repo = MockLeadRepository(
          dataSource: MockLeadDataSource(initialLeads: customLeads),
        );

        final ascResult = await repo.getLeads(
          const LeadQuery(
            sort: LeadSort(
              field: LeadSortField.name,
              direction: LeadSortDirection.ascending,
            ),
          ),
        );
        expect(ascResult.items.map((l) => l.id).toList(), [
          'l-alice',
          'l-bob',
          'l-empty',
          'l-null',
        ]);

        final descResult = await repo.getLeads(
          const LeadQuery(
            sort: LeadSort(
              field: LeadSortField.name,
              direction: LeadSortDirection.descending,
            ),
          ),
        );
        expect(descResult.items.map((l) => l.id).toList(), [
          'l-bob',
          'l-alice',
          'l-empty',
          'l-null',
        ]);
      },
    );

    test(
      'sorts by Newest Created (createdAt descending) with nulls last',
      () async {
        final customLeads = [
          Lead(id: 'l-mid', createdAt: DateTime.parse('2026-09-03T10:00:00Z')),
          const Lead(id: 'l-null', createdAt: null),
          Lead(id: 'l-old', createdAt: DateTime.parse('2026-09-01T10:00:00Z')),
          Lead(id: 'l-new', createdAt: DateTime.parse('2026-09-05T10:00:00Z')),
        ];
        final repo = MockLeadRepository(
          dataSource: MockLeadDataSource(initialLeads: customLeads),
        );

        final result = await repo.getLeads(
          const LeadQuery(
            sort: LeadSort(
              field: LeadSortField.createdAt,
              direction: LeadSortDirection.descending,
            ),
          ),
        );

        expect(result.items.map((l) => l.id).toList(), [
          'l-new',
          'l-mid',
          'l-old',
          'l-null',
        ]);
      },
    );

    test(
      'sorts by Oldest Created (createdAt ascending) with nulls last',
      () async {
        final customLeads = [
          Lead(id: 'l-mid', createdAt: DateTime.parse('2026-09-03T10:00:00Z')),
          const Lead(id: 'l-null', createdAt: null),
          Lead(id: 'l-old', createdAt: DateTime.parse('2026-09-01T10:00:00Z')),
          Lead(id: 'l-new', createdAt: DateTime.parse('2026-09-05T10:00:00Z')),
        ];
        final repo = MockLeadRepository(
          dataSource: MockLeadDataSource(initialLeads: customLeads),
        );

        final result = await repo.getLeads(
          const LeadQuery(
            sort: LeadSort(
              field: LeadSortField.createdAt,
              direction: LeadSortDirection.ascending,
            ),
          ),
        );

        expect(result.items.map((l) => l.id).toList(), [
          'l-old',
          'l-mid',
          'l-new',
          'l-null',
        ]);
      },
    );

    test(
      'tie-break rule: deterministic secondary ordering by id ascending regardless of direction',
      () async {
        final customLeads = [
          const Lead(id: 'id-002', name: 'Alice'),
          const Lead(id: 'id-003', name: 'Bob'),
          const Lead(id: 'id-001', name: 'Alice'),
        ];
        final repo = MockLeadRepository(
          dataSource: MockLeadDataSource(initialLeads: customLeads),
        );

        // Name A-Z
        final asc = await repo.getLeads(
          const LeadQuery(
            sort: LeadSort(
              field: LeadSortField.name,
              direction: LeadSortDirection.ascending,
            ),
          ),
        );
        expect(asc.items.map((l) => '${l.name}:${l.id}').toList(), [
          'Alice:id-001',
          'Alice:id-002',
          'Bob:id-003',
        ]);

        // Name Z-A: Bob first, but between the two Alice records, id-001 is before id-002!
        final desc = await repo.getLeads(
          const LeadQuery(
            sort: LeadSort(
              field: LeadSortField.name,
              direction: LeadSortDirection.descending,
            ),
          ),
        );
        expect(desc.items.map((l) => '${l.name}:${l.id}').toList(), [
          'Bob:id-003',
          'Alice:id-001',
          'Alice:id-002',
        ]);

        // Same createdAt timestamps tie-break id ascending
        final sameDateLeads = [
          Lead(id: 'id-b', createdAt: DateTime.parse('2026-09-01T10:00:00Z')),
          Lead(id: 'id-a', createdAt: DateTime.parse('2026-09-01T10:00:00Z')),
        ];
        final dateRepo = MockLeadRepository(
          dataSource: MockLeadDataSource(initialLeads: sameDateLeads),
        );

        final dateDesc = await dateRepo.getLeads(
          const LeadQuery(
            sort: LeadSort(
              field: LeadSortField.createdAt,
              direction: LeadSortDirection.descending,
            ),
          ),
        );
        expect(dateDesc.items.map((l) => l.id).toList(), ['id-a', 'id-b']);
      },
    );

    test(
      'search + sort: filters by search term and sorts remaining items',
      () async {
        final customLeads = [
          const Lead(id: 'l-1', name: 'David Smith'),
          const Lead(id: 'l-2', name: 'Alice Smith'),
          const Lead(id: 'l-3', name: 'Bob Jones'),
          const Lead(id: 'l-4', name: 'Charlie Smith'),
        ];
        final repo = MockLeadRepository(
          dataSource: MockLeadDataSource(initialLeads: customLeads),
        );

        final result = await repo.getLeads(
          const LeadQuery(
            searchText: 'Smith',
            sort: LeadSort(
              field: LeadSortField.name,
              direction: LeadSortDirection.ascending,
            ),
          ),
        );

        expect(result.items.map((l) => l.name).toList(), [
          'Alice Smith',
          'Charlie Smith',
          'David Smith',
        ]);
      },
    );

    test(
      'filters + sort: filters by source and sorts remaining items',
      () async {
        final customLeads = [
          const Lead(id: 'l-1', name: 'David', source: LeadSource.manual),
          const Lead(id: 'l-2', name: 'Alice', source: LeadSource.excel),
          const Lead(id: 'l-3', name: 'Bob', source: LeadSource.manual),
          const Lead(id: 'l-4', name: 'Charlie', source: LeadSource.manual),
        ];
        final repo = MockLeadRepository(
          dataSource: MockLeadDataSource(initialLeads: customLeads),
        );

        final result = await repo.getLeads(
          const LeadQuery(
            source: LeadSource.manual,
            sort: LeadSort(
              field: LeadSortField.name,
              direction: LeadSortDirection.ascending,
            ),
          ),
        );

        expect(result.items.map((l) => l.name).toList(), [
          'Bob',
          'Charlie',
          'David',
        ]);
      },
    );

    test(
      'Default sort (null) restores repository natural insertion order',
      () async {
        final customLeads = [
          const Lead(id: 'l-3', name: 'Zoe'),
          const Lead(id: 'l-1', name: 'Alice'),
          const Lead(id: 'l-2', name: 'Mike'),
        ];
        final repo = MockLeadRepository(
          dataSource: MockLeadDataSource(initialLeads: customLeads),
        );

        final result = await repo.getLeads(const LeadQuery());
        expect(result.items.map((l) => l.id).toList(), ['l-3', 'l-1', 'l-2']);
      },
    );

    test(
      'MANDATORY REGRESSION TEST: sort occurs BEFORE pagination (25 leads, pageSize=20)',
      () async {
        // Insertion order:
        // First 20 items: Zulu 00 to Zulu 19
        // Last 5 items: Alpha 00 to Alpha 04
        final customLeads = <Lead>[
          for (var i = 0; i < 20; i++)
            Lead(id: 'zulu-$i', name: 'Zulu ${i.toString().padLeft(2, '0')}'),
          for (var i = 0; i < 5; i++)
            Lead(id: 'alpha-$i', name: 'Alpha ${i.toString().padLeft(2, '0')}'),
        ];

        expect(customLeads.length, 25);

        final repo = MockLeadRepository(
          dataSource: MockLeadDataSource(initialLeads: customLeads),
        );

        // If paginate -> sort was run:
        // Page 1 would take the first 20 records (all Zulu items) and sort only them.
        // None of the Alpha items would appear on Page 1!
        //
        // With sort -> paginate (correct):
        // All 25 items are sorted globally. All 5 Alpha items appear at the top of Page 1!
        final page1 = await repo.getLeads(
          const LeadQuery(
            page: 1,
            pageSize: 20,
            sort: LeadSort(
              field: LeadSortField.name,
              direction: LeadSortDirection.ascending,
            ),
          ),
        );

        expect(page1.items.length, 20);
        expect(page1.totalItems, 25);
        expect(page1.hasNext, isTrue);

        // First 5 items MUST be the Alpha records that crossed the page boundary
        final first5Names = page1.items.take(5).map((l) => l.name).toList();
        expect(first5Names, [
          'Alpha 00',
          'Alpha 01',
          'Alpha 02',
          'Alpha 03',
          'Alpha 04',
        ]);

        // Remaining 15 items on page 1 are Zulu 00 .. Zulu 14
        final remainingNames = page1.items.skip(5).map((l) => l.name).toList();
        expect(remainingNames.length, 15);
        expect(remainingNames.first, 'Zulu 00');
        expect(remainingNames.last, 'Zulu 14');

        // Page 2 contains the remaining 5 Zulu records (Zulu 15 .. Zulu 19)
        final page2 = await repo.getLeads(
          const LeadQuery(
            page: 2,
            pageSize: 20,
            sort: LeadSort(
              field: LeadSortField.name,
              direction: LeadSortDirection.ascending,
            ),
          ),
        );
        expect(page2.items.length, 5);
        expect(page2.items.map((l) => l.name).toList(), [
          'Zulu 15',
          'Zulu 16',
          'Zulu 17',
          'Zulu 18',
          'Zulu 19',
        ]);
      },
    );
  });
}
