import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../leads/domain/entities/lead.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import '../../data/repositories/mock_lead_call_activity_repository.dart';
import '../../data/services/mock_calling_workflow_service.dart';
import '../../domain/entities/call_outcome.dart';
import '../../domain/policies/user_calling_policy.dart';
import '../../domain/repositories/lead_call_activity_repository.dart';
import '../../domain/repositories/lead_follow_up_repository.dart';
import '../../domain/services/calling_workflow_service.dart';
import 'record_call_activity_state.dart';

/// Cubit managing authorization, validation, and mutation for recording a call activity.
///
/// Enforces complete gate chain on load and on save:
/// Calling module -> calling.use -> Lead module -> lead.view_assigned -> link -> assignee validation -> fresh Lead -> ownership.
class RecordCallActivityCubit extends Cubit<RecordCallActivityState> {
  final CurrentUser _user;
  final String _leadId;
  final Lead? _initialLead;
  final UserLeadLinkRepository _linkRepository;
  final LeadRepository _leadRepository;
  final CallingWorkflowService _workflowService;
  final NowProvider _now;

  RecordCallActivityCubit({
    required CurrentUser user,
    required String leadId,
    Lead? initialLead,
    required UserLeadLinkRepository linkRepository,
    required LeadRepository leadRepository,
    CallingWorkflowService? workflowService,
    LeadCallActivityRepository? callActivityRepository,
    LeadFollowUpRepository? followUpRepository,
    NowProvider? now,
  }) : _user = user,
       _leadId = leadId,
       _initialLead = initialLead,
       _linkRepository = linkRepository,
       _leadRepository = leadRepository,
       _workflowService = workflowService ??
           (callActivityRepository != null && followUpRepository != null
               ? MockCallingWorkflowService(
                   callActivityRepository: callActivityRepository,
                   followUpRepository: followUpRepository,
                 )
               : (throw ArgumentError(
                   'Either workflowService or both callActivityRepository and followUpRepository must be provided.',
                 ))),
       _now = now ?? DateTime.now,
       super(const RecordCallActivityInitial());

  /// Runs complete gate checks and prepares the form.
  Future<void> load() async {
    emit(const RecordCallActivityLoading());

    // 1. Calling module guard
    if (!AccessPolicy.canAccessModule(_user, CrmModule.calling)) {
      emit(
        const RecordCallActivityAccessDenied('Calling module not assigned.'),
      );
      return;
    }

    // 2. calling.use permission guard
    if (!AccessPolicy.hasPermission(_user, CrmPermissions.callingUse)) {
      emit(
        const RecordCallActivityAccessDenied(
          'calling.use permission not granted.',
        ),
      );
      return;
    }

    // 3. Lead Management module guard
    if (!AccessPolicy.canAccessModule(_user, CrmModule.leadManagement)) {
      emit(
        const RecordCallActivityAccessDenied(
          'Lead Management module not assigned.',
        ),
      );
      return;
    }

    // 4. lead.view_assigned permission guard
    if (!AccessPolicy.hasPermission(_user, CrmPermissions.leadViewAssigned)) {
      emit(
        const RecordCallActivityAccessDenied(
          'lead.view_assigned permission not granted.',
        ),
      );
      return;
    }

    try {
      // 5. Resolve identity link
      final link = await _linkRepository.getLinkForUser(_user.id);
      if (link == null) {
        emit(
          const RecordCallActivityAccessDenied(
            'User is not linked to an assignee identity.',
          ),
        );
        return;
      }

      // 6. Validate assignee identity exists
      final assignees = await _leadRepository.getAssignableUsers();
      final assigneeExists = assignees.any((a) => a.id == link.leadAssigneeId);
      if (!assigneeExists) {
        emit(
          const RecordCallActivityAccessDenied('Assigned identity is invalid.'),
        );
        return;
      }

      // 7. Retrieve lead
      final lead = _initialLead ?? await _leadRepository.getLeadById(_leadId);
      if (lead == null) {
        emit(const RecordCallActivityAccessDenied('Lead not found.'));
        return;
      }

      // 8. Strict ownership check
      if (!UserCallingPolicy.canRecordActivityForLead(
        user: _user,
        lead: lead,
        linkedAssigneeId: link.leadAssigneeId,
      )) {
        emit(
          const RecordCallActivityAccessDenied(
            'Access restricted to assigned leads only.',
          ),
        );
        return;
      }

      emit(
        RecordCallActivityReady(
          lead: lead,
          linkedAssigneeId: link.leadAssigneeId,
        ),
      );
    } catch (_) {
      emit(
        const RecordCallActivityAccessDenied('Unable to verify lead access.'),
      );
    }
  }

  /// Records the call activity.
  ///
  /// The acting CRM user is derived strictly from [_user.id] and cannot be chosen by the UI.
  /// Fresh repository state is queried to prevent recording against a reassigned lead.
  Future<void> submitActivity({
    required CallOutcome outcome,
    DateTime? rescheduleAt,
  }) async {
    final currentState = state;
    if (currentState is RecordCallActivitySubmitting) {
      // Double-submit protection
      return;
    }

    Lead currentLead;
    String currentAssigneeId;
    if (currentState is RecordCallActivityReady) {
      currentLead = currentState.lead;
      currentAssigneeId = currentState.linkedAssigneeId;
    } else if (currentState is RecordCallActivityFailure) {
      currentLead = currentState.lead;
      currentAssigneeId = currentState.linkedAssigneeId;
    } else {
      return;
    }

    // Schedule validation: must not be in the past
    if (rescheduleAt != null && rescheduleAt.isBefore(_now())) {
      emit(
        RecordCallActivityFailure(
          lead: currentLead,
          linkedAssigneeId: currentAssigneeId,
          message: 'Reschedule date and time must be in the future.',
        ),
      );
      return;
    }

    emit(
      RecordCallActivitySubmitting(
        lead: currentLead,
        linkedAssigneeId: currentAssigneeId,
      ),
    );

    // Save-time permission & module checks
    if (!UserCallingPolicy.canUseCalling(_user) ||
        !AccessPolicy.canAccessModule(_user, CrmModule.leadManagement) ||
        !AccessPolicy.hasPermission(_user, CrmPermissions.leadViewAssigned)) {
      emit(
        const RecordCallActivityAccessDenied(
          'Calling or Lead permissions revoked.',
        ),
      );
      return;
    }

    try {
      // 1. Re-resolve link at save time
      final link = await _linkRepository.getLinkForUser(_user.id);
      if (link == null) {
        emit(
          const RecordCallActivityAccessDenied(
            'Identity link is no longer valid.',
          ),
        );
        return;
      }

      // 2. Validate assignee exists
      final assignees = await _leadRepository.getAssignableUsers();
      final assigneeExists = assignees.any((a) => a.id == link.leadAssigneeId);
      if (!assigneeExists) {
        emit(
          const RecordCallActivityAccessDenied('Assigned identity is invalid.'),
        );
        return;
      }

      // 3. Re-fetch fresh lead from repository
      final freshLead = await _leadRepository.getLeadById(_leadId);
      if (freshLead == null) {
        emit(const RecordCallActivityAccessDenied('Lead not found.'));
        return;
      }

      // 4. Strict fresh ownership verification (anti-reassignment guard)
      if (!UserCallingPolicy.canRecordActivityForLead(
        user: _user,
        lead: freshLead,
        linkedAssigneeId: link.leadAssigneeId,
      )) {
        emit(
          const RecordCallActivityAccessDenied(
            'Lead ownership has changed or is no longer accessible.',
          ),
        );
        return;
      }

      // 5. Record activity and schedule follow-up via workflow service
      final workflowResult = await _workflowService.recordOutcome(
        leadId: freshLead.id,
        performedByUserId: _user.id,
        outcome: outcome,
        rescheduleAt: rescheduleAt,
      );

      emit(RecordCallActivitySuccess(
        workflowResult.activity,
        followUp: workflowResult.followUp,
      ));
    } catch (_) {
      emit(
        RecordCallActivityFailure(
          lead: currentLead,
          linkedAssigneeId: currentAssigneeId,
          message: 'Unable to record call outcome.',
        ),
      );
    }
  }
}
