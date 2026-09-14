import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/lead_repository.dart';
import 'lead_dashboard_state.dart';

class LeadDashboardCubit extends Cubit<LeadDashboardState> {
  final LeadRepository _repository;

  LeadDashboardCubit(this._repository) : super(const LeadDashboardInitial());

  Future<void> loadDashboard() async {
    emit(const LeadDashboardLoading());
    try {
      final summary = await _repository.getLeadSummary();
      if (summary.isEmpty) {
        emit(const LeadDashboardEmpty());
      } else {
        emit(LeadDashboardLoaded(summary));
      }
    } catch (e) {
      emit(LeadDashboardFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
