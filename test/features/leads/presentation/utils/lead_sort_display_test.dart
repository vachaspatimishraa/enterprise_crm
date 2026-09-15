import 'package:enterprise_crm/features/leads/domain/entities/lead_sort.dart';
import 'package:enterprise_crm/features/leads/presentation/utils/lead_sort_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadSortDisplay', () {
    test('maps all five sort options to exact labels', () {
      expect(leadSortToDisplayName(null), 'Default');

      expect(
        leadSortToDisplayName(
          const LeadSort(
            field: LeadSortField.name,
            direction: LeadSortDirection.ascending,
          ),
        ),
        'Name A–Z',
      );

      expect(
        leadSortToDisplayName(
          const LeadSort(
            field: LeadSortField.name,
            direction: LeadSortDirection.descending,
          ),
        ),
        'Name Z–A',
      );

      expect(
        leadSortToDisplayName(
          const LeadSort(
            field: LeadSortField.createdAt,
            direction: LeadSortDirection.descending,
          ),
        ),
        'Newest Created',
      );

      expect(
        leadSortToDisplayName(
          const LeadSort(
            field: LeadSortField.createdAt,
            direction: LeadSortDirection.ascending,
          ),
        ),
        'Oldest Created',
      );
    });

    test('leadSortOptions contains exactly the 5 approved choices', () {
      expect(leadSortOptions.length, 5);
      expect(leadSortOptions[0], isNull);
      expect(leadSortOptions[1]?.field, LeadSortField.name);
      expect(leadSortOptions[1]?.direction, LeadSortDirection.ascending);
      expect(leadSortOptions[2]?.field, LeadSortField.name);
      expect(leadSortOptions[2]?.direction, LeadSortDirection.descending);
      expect(leadSortOptions[3]?.field, LeadSortField.createdAt);
      expect(leadSortOptions[3]?.direction, LeadSortDirection.descending);
      expect(leadSortOptions[4]?.field, LeadSortField.createdAt);
      expect(leadSortOptions[4]?.direction, LeadSortDirection.ascending);
    });
  });
}
