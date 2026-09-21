/// Represents the lifecycle status of a scheduled lead follow-up.
///
/// Follow-up lifecycle transitions:
/// - `pending` -> `completed`
/// - `pending` -> `cancelled`
/// - `pending` -> `rescheduled` (updates scheduledAt, status remains `pending`)
///
/// Terminal states: `completed`, `cancelled` (no further lifecycle mutations permitted).
enum FollowUpStatus {
  pending,
  completed,
  cancelled,
}
