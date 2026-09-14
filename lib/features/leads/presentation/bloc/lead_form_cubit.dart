import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/lead_draft.dart';
import '../../domain/repositories/lead_repository.dart';
import 'lead_form_state.dart';

class LeadFormCubit extends Cubit<LeadFormState> {
  final LeadRepository _repository;

  LeadFormCubit(this._repository) : super(const LeadFormInitial());

  Future<void> createLead(LeadDraft draft) async {
    emit(const LeadFormSubmitting());
    try {
      final created = await _repository.createLead(
        CreateLeadInput(draft: draft),
      );
      emit(LeadFormSuccess(created));
    } catch (e) {
      emit(LeadFormFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> updateLead(String leadId, LeadDraft draft) async {
    emit(const LeadFormSubmitting());
    try {
      final updated = await _repository.updateLead(
        UpdateLeadInput(leadId: leadId, draft: draft),
      );
      emit(LeadFormSuccess(updated));
    } catch (e) {
      emit(LeadFormFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  void reset() {
    emit(const LeadFormInitial());
  }
}
