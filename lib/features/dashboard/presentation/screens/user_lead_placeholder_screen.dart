import 'package:flutter/material.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../calling/domain/repositories/lead_call_activity_repository.dart';
import '../../../calling/domain/repositories/lead_follow_up_repository.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import 'user_lead_workspace_screen.dart';

/// Backward-compatible entry point for [UserLeadWorkspaceScreen].
///
/// Requires explicit [user], [linkRepository], [leadRepository], and [callActivityRepository].
/// Does NOT create mock fallbacks.
class UserLeadPlaceholderScreen extends StatelessWidget {
  final CurrentUser user;
  final UserLeadLinkRepository linkRepository;
  final LeadRepository leadRepository;
  final LeadCallActivityRepository callActivityRepository;
  final LeadFollowUpRepository? leadFollowUpRepository;

  const UserLeadPlaceholderScreen({
    super.key,
    required this.user,
    required this.linkRepository,
    required this.leadRepository,
    required this.callActivityRepository,
    this.leadFollowUpRepository,
  });

  @override
  Widget build(BuildContext context) {
    return UserLeadWorkspaceScreen(
      user: user,
      linkRepository: linkRepository,
      leadRepository: leadRepository,
      callActivityRepository: callActivityRepository,
      leadFollowUpRepository: leadFollowUpRepository,
    );
  }
}
