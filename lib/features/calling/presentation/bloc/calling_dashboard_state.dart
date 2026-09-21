import '../models/follow_up_queue_item.dart';

/// States for the Calling Follow-Up Dashboard.
sealed class CallingDashboardState {
  const CallingDashboardState();
}

/// Initial uninitialized state.
class CallingDashboardInitial extends CallingDashboardState {
  const CallingDashboardInitial();
}

/// Loading state while evaluating authorization and fetching queue data.
class CallingDashboardLoading extends CallingDashboardState {
  const CallingDashboardLoading();
}

/// The user possesses Calling access, but lacks Lead Management module or
/// `lead.view_assigned` permission.
class CallingDashboardNoLeadAccess extends CallingDashboardState {
  const CallingDashboardNoLeadAccess();
}

/// The user possesses Calling & Lead view access, but no CRM User -> LeadAssignee
/// identity link is configured.
class CallingDashboardNoLink extends CallingDashboardState {
  const CallingDashboardNoLink();
}

/// The user's identity link points to a LeadAssignee that does not exist in
/// the Lead domain.
class CallingDashboardInvalidLink extends CallingDashboardState {
  const CallingDashboardInvalidLink();
}

/// An error occurred during data fetching or authorization.
class CallingDashboardFailure extends CallingDashboardState {
  final String message;

  const CallingDashboardFailure(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallingDashboardFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

/// The user is authorized, but currently owns zero leads or their assigned leads
/// have zero scheduled follow-ups.
class CallingDashboardEmpty extends CallingDashboardState {
  const CallingDashboardEmpty();
}

/// Successfully loaded follow-up queue with filtering and summary metrics.
class CallingDashboardLoaded extends CallingDashboardState {
  final List<FollowUpQueueItem> allItems;
  final List<FollowUpQueueItem> visibleItems;
  final FollowUpTimingFilter selectedFilter;
  final String searchQuery;
  final int overdueCount;
  final int dueTodayCount;
  final int upcomingCount;

  const CallingDashboardLoaded({
    required this.allItems,
    required this.visibleItems,
    required this.selectedFilter,
    required this.searchQuery,
    required this.overdueCount,
    required this.dueTodayCount,
    required this.upcomingCount,
  });

  CallingDashboardLoaded copyWith({
    List<FollowUpQueueItem>? allItems,
    List<FollowUpQueueItem>? visibleItems,
    FollowUpTimingFilter? selectedFilter,
    String? searchQuery,
    int? overdueCount,
    int? dueTodayCount,
    int? upcomingCount,
  }) {
    return CallingDashboardLoaded(
      allItems: allItems ?? this.allItems,
      visibleItems: visibleItems ?? this.visibleItems,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      overdueCount: overdueCount ?? this.overdueCount,
      dueTodayCount: dueTodayCount ?? this.dueTodayCount,
      upcomingCount: upcomingCount ?? this.upcomingCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallingDashboardLoaded &&
          runtimeType == other.runtimeType &&
          selectedFilter == other.selectedFilter &&
          searchQuery == other.searchQuery &&
          overdueCount == other.overdueCount &&
          dueTodayCount == other.dueTodayCount &&
          upcomingCount == other.upcomingCount;

  @override
  int get hashCode => Object.hash(
    selectedFilter,
    searchQuery,
    overdueCount,
    dueTodayCount,
    upcomingCount,
  );
}
