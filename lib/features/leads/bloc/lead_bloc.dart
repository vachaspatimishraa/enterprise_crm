import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/lead_repository.dart';
import 'lead_event.dart';
import 'lead_state.dart';

class LeadBloc extends Bloc<LeadEvent, LeadState> {
  final LeadRepository _leadRepository;

  LeadBloc(this._leadRepository) : super(const LeadState()) {
    on<LeadSubscriptionRequested>(_onSubscriptionRequested);
    on<LeadAdded>(_onLeadAdded);
    on<LeadStatusChanged>(_onStatusChanged);
    on<LeadDeleted>(_onLeadDeleted);
  }

  Future<void> _onSubscriptionRequested(
    LeadSubscriptionRequested event,
    Emitter<LeadState> emit,
  ) async {
    emit(state.copyWith(status: LeadStatus.loading));
    await emit.forEach(
      _leadRepository.watchLeads(),
      onData: (leads) => state.copyWith(status: LeadStatus.success, leads: leads),
      onError: (_, __) => state.copyWith(
        status: LeadStatus.error,
        errorMessage: 'Failed to load leads',
      ),
    );
  }

  Future<void> _onLeadAdded(LeadAdded event, Emitter<LeadState> emit) async {
    try {
      await _leadRepository.addLead(event.lead);
      // Real-time stream will push the update automatically
    } catch (e) {
      emit(state.copyWith(status: LeadStatus.error, errorMessage: 'Failed to add lead'));
    }
  }

  Future<void> _onStatusChanged(
    LeadStatusChanged event,
    Emitter<LeadState> emit,
  ) async {
    try {
      await _leadRepository.updateLead(event.id, {'status': event.newStatus});
    } catch (e) {
      emit(state.copyWith(status: LeadStatus.error, errorMessage: 'Failed to update status'));
    }
  }

  Future<void> _onLeadDeleted(LeadDeleted event, Emitter<LeadState> emit) async {
    try {
      await _leadRepository.deleteLead(event.id);
    } catch (e) {
      emit(state.copyWith(status: LeadStatus.error, errorMessage: 'Failed to delete lead'));
    }
  }
}