import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_sort.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadQuery - Sort Participation', () {
    const nameAscSort = LeadSort(
      field: LeadSortField.name,
      direction: LeadSortDirection.ascending,
    );

    const createdDescSort = LeadSort(
      field: LeadSortField.createdAt,
      direction: LeadSortDirection.descending,
    );

    test('default sort is null', () {
      const query = LeadQuery();
      expect(query.sort, isNull);
    });

    test('isEmpty returns false when only sort is provided', () {
      const query = LeadQuery(sort: nameAscSort);
      expect(query.isEmpty, isFalse);
    });

    test('isEmpty returns true for empty query with default sort', () {
      const query = LeadQuery();
      expect(query.isEmpty, isTrue);
    });

    test('copyWith preserves sort when not cleared', () {
      const query = LeadQuery(sort: nameAscSort, searchText: 'Alice');
      final updated = query.copyWith(searchText: 'Bob');

      expect(updated.sort, equals(nameAscSort));
      expect(updated.searchText, 'Bob');
    });

    test('copyWith updates sort to new value', () {
      const query = LeadQuery(sort: nameAscSort);
      final updated = query.copyWith(sort: createdDescSort);

      expect(updated.sort, equals(createdDescSort));
    });

    test('copyWith with clearSort: true sets sort to null', () {
      const query = LeadQuery(
        sort: nameAscSort,
        searchText: 'Alice',
        source: LeadSource.manual,
        page: 2,
      );
      final cleared = query.copyWith(clearSort: true, page: 1);

      expect(cleared.sort, isNull);
      expect(cleared.searchText, 'Alice');
      expect(cleared.source, LeadSource.manual);
      expect(cleared.page, 1);
    });

    test('equality and hashCode participate with sort', () {
      const query1 = LeadQuery(sort: nameAscSort);
      const query2 = LeadQuery(sort: nameAscSort);
      const query3 = LeadQuery(sort: createdDescSort);
      const query4 = LeadQuery();

      expect(query1, equals(query2));
      expect(query1.hashCode, equals(query2.hashCode));

      expect(query1, isNot(equals(query3)));
      expect(query1, isNot(equals(query4)));
    });

    test('toString includes sort info', () {
      const query = LeadQuery(sort: nameAscSort);
      expect(
        query.toString(),
        contains(
          'sort: LeadSort(LeadSortField.name, LeadSortDirection.ascending)',
        ),
      );
    });
  });
}
