import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/lead_query.dart';
import '../../domain/entities/lead_source.dart';
import '../../domain/repositories/lead_repository.dart';
import 'lead_dashboard_state.dart';

class LeadDashboardCubit extends Cubit<LeadDashboardState> {
  final LeadRepository _repository;

  LeadDashboardCubit(this._repository) : super(const LeadDashboardInitial());

  Future<void> loadDashboard() async {
    emit(const LeadDashboardLoading());
    try {
      final page = await _repository.getLeads(const LeadQuery(pageSize: 1000));
      if (page.totalItems == 0 && page.items.isEmpty) {
        emit(const LeadDashboardEmpty());
        return;
      }

      int assigned = 0;
      int unassigned = 0;
      int manual = 0;
      int excel = 0;
      int csv = 0;

      for (final lead in page.items) {
        if (lead.isAssigned) {
          assigned++;
        } else {
          unassigned++;
        }

        switch (lead.source) {
          case LeadSource.manual:
            manual++;
            break;
          case LeadSource.excel:
            excel++;
            break;
          case LeadSource.csv:
            csv++;
            break;
        }
      }

      final metrics = LeadSummaryMetrics(
        totalLeads: page.totalItems > 0 ? page.totalItems : page.items.length,
        assignedLeads: assigned,
        unassignedLeads: unassigned,
        manualLeads: manual,
        excelLeads: excel,
        csvLeads: csv,
      );

      emit(LeadDashboardLoaded(metrics));
    } catch (e) {
      emit(LeadDashboardFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
