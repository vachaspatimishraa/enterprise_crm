import '../entities/user_lead_link.dart';

/// Maps a CRM user account identity to a Lead assignee identity.
///
/// The two ID namespaces are entirely separate:
///   - CRM user IDs come from the account/authentication store.
///   - Lead assignee IDs come from the Lead domain.
///
/// This repository is the only permitted bridge between them.
abstract interface class UserLeadLinkRepository {
  /// Returns the [UserLeadLink] for the given [crmUserId], or `null` if no
  /// link has been configured for that user.
  Future<UserLeadLink?> getLinkForUser(String crmUserId);
}
