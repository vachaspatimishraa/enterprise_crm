import 'lead.dart';

class LeadPage {
  const LeadPage({
    required this.items,
    required this.currentPage,
    required this.pageSize,
    required this.totalItems,
    required this.hasNext,
  });

  final List<Lead> items;
  final int currentPage;
  final int pageSize;
  final int totalItems;
  final bool hasNext;
}
