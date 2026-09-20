import 'package:flutter/material.dart';

import '../../../auth/domain/entities/account_type.dart';
import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../auth/data/repositories/mock_user_lead_link_repository.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import '../../../leads/data/repositories/mock_lead_repository.dart';
import 'user_lead_workspace_screen.dart';

/// Backward-compatible entry point for [UserLeadWorkspaceScreen].
///
/// Accepts optional [linkRepository] and [leadRepository] for injection.
/// Falls back to default mock implementations when not supplied, preserving
/// compatibility for navigation tests that do not exercise lead data.
class UserLeadPlaceholderScreen extends StatelessWidget {
  final CurrentUser? user;
  final UserLeadLinkRepository? linkRepository;
  final LeadRepository? leadRepository;

  const UserLeadPlaceholderScreen({
    super.key,
    this.user,
    this.linkRepository,
    this.leadRepository,
  });

  static const CurrentUser _defaultFallbackUser = CurrentUser(
    id: 'usr_standard',
    displayName: 'Standard User',
    accountType: AccountType.user,
    modules: {CrmModule.leadManagement},
    permissions: {'lead.view_assigned'},
  );

  @override
  Widget build(BuildContext context) {
    return UserLeadWorkspaceScreen(
      user: user ?? _defaultFallbackUser,
      linkRepository:
          linkRepository ?? MockUserLeadLinkRepository(),
      leadRepository: leadRepository ?? MockLeadRepository(),
    );
  }
}
