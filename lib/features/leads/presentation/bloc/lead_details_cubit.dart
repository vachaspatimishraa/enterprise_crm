import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/lead_repository.dart';
import 'lead_details_state.dart';

class LeadDetailsCubit extends Cubit<LeadDetailsState> {
  final LeadRepository _repository;
  String? _lastLeadId;

  LeadDetailsCubit(this._repository) : super(const LeadDetailsInitial());

  String? get lastLeadId => _lastLeadId;

  Future<void> loadLead(String leadId) async {
    _lastLeadId = leadId;
    emit(const LeadDetailsLoading());
    try {
      final lead = await _repository.getLeadById(leadId);
      if (lead == null) {
        emit(LeadDetailsNotFound(leadId));
      } else {
        emit(LeadDetailsLoaded(lead));
      }
    } catch (e) {
      emit(
        LeadDetailsFailure(
          e.toString().replaceAll('Exception: ', ''),
          leadId: leadId,
        ),
      );
    }
  }

  Future<void> retry() async {
    if (_lastLeadId != null) {
      await loadLead(_lastLeadId!);
    }
  }
}
