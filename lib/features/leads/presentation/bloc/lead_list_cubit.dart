import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/lead_query.dart';
import '../../domain/repositories/lead_repository.dart';
import 'lead_list_state.dart';

class LeadListCubit extends Cubit<LeadListState> {
  final LeadRepository _repository;
  LeadQuery _currentQuery = const LeadQuery();

  LeadListCubit(this._repository) : super(const LeadListInitial());

  LeadQuery get currentQuery => _currentQuery;

  Future<void> loadLeads({LeadQuery? query}) async {
    if (query != null) {
      _currentQuery = query;
    }
    emit(LeadListLoading(_currentQuery));
    try {
      final page = await _repository.getLeads(_currentQuery);
      if (page.items.isEmpty) {
        emit(LeadListEmpty(query: _currentQuery));
      } else {
        emit(
          LeadListLoaded(
            page.items,
            query: _currentQuery,
            hasNext: page.hasNext,
            totalItems: page.totalItems,
            currentPage: page.currentPage,
            pageSize: page.pageSize,
          ),
        );
      }
    } catch (e) {
      emit(
        LeadListFailure(
          e.toString().replaceAll('Exception: ', ''),
          query: _currentQuery,
        ),
      );
    }
  }

  Future<void> refreshLeads() async {
    await loadLeads(query: _currentQuery);
  }

  Future<void> applyQuery(LeadQuery query) async {
    await loadLeads(query: query);
  }

  Future<void> clearFilters() async {
    await loadLeads(query: const LeadQuery());
  }
}
