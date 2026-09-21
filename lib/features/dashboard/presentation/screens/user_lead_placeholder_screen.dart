import 'package:flutter/material.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import 'user_lead_workspace_screen.dart';

/// Backward-compatible entry point for [UserLeadWorkspaceScreen].
///
/// Requires explicit [user], [linkRepository], and [leadRepository].
/// Does NOT create mock fallbacks.
class UserLeadPlaceholderScreen extends StatelessWidget {
  final CurrentUser user;
  final UserLeadLinkRepository linkRepository;
  final LeadRepository leadRepository;

  const UserLeadPlaceholderScreen({
    super.key,
    required this.user,
    required this.linkRepository,
    required this.leadRepository,
  });

  @override
  Widget build(BuildContext context) {
    return UserLeadWorkspaceScreen(
      user: user,
      linkRepository: linkRepository,
      leadRepository: leadRepository,
    );
  }
}
