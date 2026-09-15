import 'package:enterprise_crm/features/leads/domain/entities/lead_sort.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadSort', () {
    test('value equality works when field and direction match', () {
      const sort1 = LeadSort(
        field: LeadSortField.name,
        direction: LeadSortDirection.ascending,
      );
      const sort2 = LeadSort(
        field: LeadSortField.name,
        direction: LeadSortDirection.ascending,
      );

      expect(sort1, equals(sort2));
      expect(sort1.hashCode, equals(sort2.hashCode));
    });

    test('value inequality when field differs', () {
      const sort1 = LeadSort(
        field: LeadSortField.name,
        direction: LeadSortDirection.ascending,
      );
      const sort2 = LeadSort(
        field: LeadSortField.createdAt,
        direction: LeadSortDirection.ascending,
      );

      expect(sort1, isNot(equals(sort2)));
    });

    test('value inequality when direction differs', () {
      const sort1 = LeadSort(
        field: LeadSortField.name,
        direction: LeadSortDirection.ascending,
      );
      const sort2 = LeadSort(
        field: LeadSortField.name,
        direction: LeadSortDirection.descending,
      );

      expect(sort1, isNot(equals(sort2)));
    });

    test('toString includes field and direction', () {
      const sort = LeadSort(
        field: LeadSortField.name,
        direction: LeadSortDirection.ascending,
      );
      expect(
        sort.toString(),
        equals('LeadSort(LeadSortField.name, LeadSortDirection.ascending)'),
      );
    });
  });
}
