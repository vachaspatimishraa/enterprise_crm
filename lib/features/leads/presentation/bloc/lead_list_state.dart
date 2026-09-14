import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_query.dart';

sealed class LeadListState {
  const LeadListState();
}

final class LeadListInitial extends LeadListState {
  const LeadListInitial();
}

final class LeadListLoading extends LeadListState {
  final LeadQuery query;

  const LeadListLoading([this.query = const LeadQuery()]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadListLoading &&
          runtimeType == other.runtimeType &&
          query == other.query;

  @override
  int get hashCode => query.hashCode;
}

final class LeadListLoaded extends LeadListState {
  final List<Lead> leads;
  final LeadQuery query;
  final bool hasNext;
  final int totalItems;

  const LeadListLoaded(
    this.leads, {
    this.query = const LeadQuery(),
    this.hasNext = false,
    this.totalItems = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadListLoaded &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          hasNext == other.hasNext &&
          totalItems == other.totalItems &&
          _listEquals(leads, other.leads);

  @override
  int get hashCode =>
      Object.hash(query, hasNext, totalItems, Object.hashAll(leads));

  static bool _listEquals(List<Lead> a, List<Lead> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final class LeadListEmpty extends LeadListState {
  final LeadQuery query;

  const LeadListEmpty({this.query = const LeadQuery()});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadListEmpty &&
          runtimeType == other.runtimeType &&
          query == other.query;

  @override
  int get hashCode => query.hashCode;
}

final class LeadListFailure extends LeadListState {
  final String message;
  final LeadQuery query;

  const LeadListFailure(this.message, {this.query = const LeadQuery()});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadListFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          query == other.query;

  @override
  int get hashCode => Object.hash(message, query);
}
