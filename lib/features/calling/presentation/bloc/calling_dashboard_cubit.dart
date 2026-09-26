import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../leads/domain/entities/lead.dart';
import '../../../leads/domain/entities/lead_query.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import '../../data/repositories/mock_lead_call_activity_repository.dart';
import '../../data/services/follow_up_migration_adapter.dart';
import '../../domain/entities/follow_up_status.dart';
import '../../domain/entities/follow_up_timing.dart';
import '../../domain/entities/lead_call_activity.dart';
import '../../domain/policies/user_calling_policy.dart';
import '../../domain/repositories/lead_call_activity_repository.dart';
import '../../domain/repositories/lead_follow_up_repository.dart';
import '../models/follow_up_queue_item.dart';
import 'calling_dashboard_state.dart';

/// Cubit managing the operational Calling Dashboard and actionable Follow-Up Queue.
///
/// Pipeline (strictly ordered — early failures guarantee 0 downstream queries):
///   1. Calling module + calling.use (defensive Cubit check)
///   2. Lead Management module + lead.view_assigned
///   3. Resolve UserLeadLink (CRM user -> LeadAssignee)
///   4. Validate LeadAssignee exists in Lead domain
///   5. Paginated retrieval of ALL currently assigned Leads (scoped by assignedUserId)
///      with Lead.id deduplication
///   6. Historical bootstrap migration scoped strictly to authorized lead IDs
///   7. Query pending follow-ups for authorized lead IDs (status == pending)
///   8. Classify timing (Overdue, Due Today, Upcoming) via injected [NowProvider] using followUp.scheduledAt
///   9. Calculate full-queue summary metrics, apply filter & search, and emit [CallingDashboardLoaded]
class CallingDashboardCubit extends Cubit<CallingDashboardState> {
  final CurrentUser _user;
  final LeadRepository _leadRepository;
  final UserLeadLinkRepository _linkRepository;
  final LeadFollowUpRepository _followUpRepository;
  final LeadCallActivityRepository? _callActivityRepository;
  final FollowUpMigrationAdapter? _migrationAdapter;
  final NowProvider _now;

  CallingDashboardCubit({
    required CurrentUser user,
    required LeadRepository leadRepository,
    required UserLeadLinkRepository linkRepository,
    required LeadFollowUpRepository followUpRepository,
    LeadCallActivityRepository? callActivityRepository,
    FollowUpMigrationAdapter? migrationAdapter,
    NowProvider? now,
  }) : _user = user,
       _leadRepository = leadRepository,
       _linkRepository = linkRepository,
       _followUpRepository = followUpRepository,
       _callActivityRepository = callActivityRepository,
       _migrationAdapter = migrationAdapter,
       _now = now ?? DateTime.now,
       super(const CallingDashboardInitial());

  /// Runs the full authorization and queue construction pipeline.
  Future<void> load() async {
    emit(const CallingDashboardLoading());

    // 1. Calling access guard (defensive)
    if (!UserCallingPolicy.canUseCalling(_user)) {
      emit(const CallingDashboardFailure('Calling access not authorized.'));
      return;
    }

    // 2. Lead Management module + lead.view_assigned guard
    // Unauthorized users see an informational state without reading Lead or Activity repositories.
    final hasLeadViewAccess =
        AccessPolicy.canAccessModule(_user, CrmModule.leadManagement) &&
        AccessPolicy.hasPermission(_user, CrmPermissions.leadViewAssigned);

    if (!hasLeadViewAccess) {
      emit(const CallingDashboardNoLeadAccess());
      return;
    }

    try {
      // 3. Resolve CRM user -> LeadAssignee link
      final link = await _linkRepository.getLinkForUser(_user.id);
      if (link == null) {
        emit(const CallingDashboardNoLink());
        return;
      }

      // 4. Validate that the mapped assignee exists in the Lead domain
      final assignees = await _leadRepository.getAssignableUsers();
      final assigneeExists = assignees.any((a) => a.id == link.leadAssigneeId);
      if (!assigneeExists) {
        emit(const CallingDashboardInvalidLink());
        return;
      }

      // 5. Safely retrieve ALL currently assigned Leads across pages
      // Every page retains assignedUserId = linkedAssigneeId
      // Deduplicate by Lead.id into a Map to prevent accidental page overlap duplicates
      final leadsById = <String, Lead>{};
      var page = 1;
      bool hasNext = true;

      while (hasNext) {
        final leadPage = await _leadRepository.getLeads(
          LeadQuery(assignedUserId: link.leadAssigneeId, page: page),
        );

        for (final lead in leadPage.items) {
          leadsById[lead.id] = lead;
        }

        hasNext = leadPage.hasNext && leadPage.items.isNotEmpty;
        page++;
      }

      // If user currently owns zero leads, skip follow-up query
      if (leadsById.isEmpty) {
        emit(const CallingDashboardEmpty());
        return;
      }

      final authorizedLeadIds = leadsById.keys.toSet();

      // 6. Run historical bootstrap migration strictly scoped to authorized lead IDs
      if (_callActivityRepository != null) {
        final adapter =
            _migrationAdapter ??
            FollowUpMigrationAdapter(
              callActivityRepository: _callActivityRepository,
              followUpRepository: _followUpRepository,
            );
        await adapter.ensureMigratedForLeadIds(authorizedLeadIds);
      }

      // 7. Query pending follow-ups for authorized lead IDs
      final followUps = await _followUpRepository.getFollowUpsForLeadIds(
        authorizedLeadIds,
      );
      final pendingFollowUps = followUps
          .where((f) => f.status == FollowUpStatus.pending)
          .toList();

      if (pendingFollowUps.isEmpty) {
        emit(const CallingDashboardEmpty());
        return;
      }

      // Optional: Query activities to provide source call activity details
      final activitiesById = <String, LeadCallActivity>{};
      if (_callActivityRepository != null) {
        final activities = await _callActivityRepository
            .getScheduledActivitiesForLeadIds(authorizedLeadIds);
        for (final act in activities) {
          activitiesById[act.id] = act;
        }
      }

      // 8. Combine Lead + FollowUp into queue items with timing classification
      final now = _now();
      final allItems = <FollowUpQueueItem>[];

      for (final followUp in pendingFollowUps) {
        final lead = leadsById[followUp.leadId];
        if (lead != null) {
          final timing = classifyFollowUpTiming(followUp.scheduledAt, now);
          final activity = activitiesById[followUp.sourceCallActivityId];
          allItems.add(
            FollowUpQueueItem(
              lead: lead,
              followUp: followUp,
              activity: activity,
              timing: timing,
            ),
          );
        }
      }

      // Sort chronological ascending (earliest scheduledAt first, tie-break ID ascending)
      allItems.sort((a, b) {
        final cmp = a.followUp.scheduledAt.compareTo(b.followUp.scheduledAt);
        if (cmp != 0) return cmp;
        return a.followUp.id.compareTo(b.followUp.id);
      });

      // 9. Derive summary counts from the complete authorized queue
      final overdueCount = allItems
          .where((i) => i.timing == FollowUpTiming.overdue)
          .length;
      final dueTodayCount = allItems
          .where((i) => i.timing == FollowUpTiming.dueToday)
          .length;
      final upcomingCount = allItems
          .where((i) => i.timing == FollowUpTiming.upcoming)
          .length;

      final visibleItems = _filterAndSearchItems(
        allItems: allItems,
        filter: FollowUpTimingFilter.all,
        searchQuery: '',
      );

      emit(
        CallingDashboardLoaded(
          allItems: allItems,
          visibleItems: visibleItems,
          selectedFilter: FollowUpTimingFilter.all,
          searchQuery: '',
          overdueCount: overdueCount,
          dueTodayCount: dueTodayCount,
          upcomingCount: upcomingCount,
        ),
      );
    } catch (e) {
      emit(
        CallingDashboardFailure(
          'Unable to load scheduled follow-ups: ${e.toString().replaceAll('Exception: ', '')}',
        ),
      );
    }
  }

  /// Sets the active timing filter without modifying summary counts.
  void setFilter(FollowUpTimingFilter filter) {
    final current = state;
    if (current is CallingDashboardLoaded) {
      final visible = _filterAndSearchItems(
        allItems: current.allItems,
        filter: filter,
        searchQuery: current.searchQuery,
      );
      emit(current.copyWith(selectedFilter: filter, visibleItems: visible));
    }
  }

  /// Updates local search query across authorized lead name, phone, and email.
  void setSearchQuery(String query) {
    final current = state;
    if (current is CallingDashboardLoaded) {
      final visible = _filterAndSearchItems(
        allItems: current.allItems,
        filter: current.selectedFilter,
        searchQuery: query,
      );
      emit(current.copyWith(searchQuery: query, visibleItems: visible));
    }
  }

  /// Refreshes the entire pipeline from scratch.
  Future<void> refresh() => load();

  /// Retries loading after a failure.
  Future<void> retry() => load();

  List<FollowUpQueueItem> _filterAndSearchItems({
    required List<FollowUpQueueItem> allItems,
    required FollowUpTimingFilter filter,
    required String searchQuery,
  }) {
    var items = allItems;

    // 1. Timing filter
    switch (filter) {
      case FollowUpTimingFilter.all:
        break;
      case FollowUpTimingFilter.overdue:
        items = items.where((i) => i.timing == FollowUpTiming.overdue).toList();
        break;
      case FollowUpTimingFilter.dueToday:
        items = items
            .where((i) => i.timing == FollowUpTiming.dueToday)
            .toList();
        break;
      case FollowUpTimingFilter.upcoming:
        items = items
            .where((i) => i.timing == FollowUpTiming.upcoming)
            .toList();
        break;
    }

    // 2. Local search (case-insensitive substring on lead name, phone, email)
    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items.where((i) {
        final nameMatch = i.lead.name?.toLowerCase().contains(query) ?? false;
        final phoneMatch = i.lead.phone?.toLowerCase().contains(query) ?? false;
        final emailMatch = i.lead.email?.toLowerCase().contains(query) ?? false;
        return nameMatch || phoneMatch || emailMatch;
      }).toList();
    }

    return items;
  }
}
