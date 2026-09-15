import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/lead_repository.dart';
import 'lead_filter_state.dart';

class LeadFilterCubit extends Cubit<LeadFilterState> {
  final LeadRepository _repository;

  LeadFilterCubit(this._repository) : super(const LeadFilterInitial());

  Future<void> loadAssignableUsers() async {
    emit(const LeadFilterLoading());
    try {
      final assignees = await _repository.getAssignableUsers();
      emit(LeadFilterReady(assignees));
    } catch (e) {
      emit(LeadFilterFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> retryAssignableUsers() async {
    await loadAssignableUsers();
  }
}
