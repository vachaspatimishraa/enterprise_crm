import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/domain/entities/crm_module.dart';
import '../../../notifications/domain/entities/notification_priority.dart';
import '../../../notifications/domain/services/notification_dispatcher.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_draft.dart';
import '../../domain/repositories/lead_repository.dart';
import 'lead_form_state.dart';

class LeadFormCubit extends Cubit<LeadFormState> {
  final LeadRepository _repository;
  final NotificationDispatcher? _notificationDispatcher;

  LeadFormCubit(
    this._repository, {
    NotificationDispatcher? notificationDispatcher,
  }) : _notificationDispatcher = notificationDispatcher,
       super(const LeadFormInitial());

  Future<void> createLead(LeadDraft draft, {String? assigneeId}) async {
    emit(const LeadFormSubmitting());
    try {
      final created = await _repository.createLead(
        CreateLeadInput(draft: draft),
      );
      Lead resultLead = created;
      final normalizedAssigneeId = assigneeId?.trim();
      if (normalizedAssigneeId != null && normalizedAssigneeId.isNotEmpty) {
        await _repository.assignLead(
          leadId: created.id,
          assigneeId: normalizedAssigneeId,
        );
        resultLead = (await _repository.getLeadById(created.id)) ?? created;
        final dispatcher = _notificationDispatcher;
        if (dispatcher != null) {
          try {
            final leadTitle = resultLead.name ?? 'Lead #${resultLead.id}';
            await dispatcher.notifySystemAlert(
              recipientUserId: normalizedAssigneeId,
              title: 'New Lead Assignment: $leadTitle',
              message: 'Lead "$leadTitle" has been assigned to you.',
              priority: NotificationPriority.info,
              module: CrmModule.leadManagement,
            );
          } catch (_) {
            // Non-blocking notification dispatch
          }
        }
      }
      emit(LeadFormSuccess(resultLead));
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
