import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';

/// Test fixtures for `CurrentUser` to isolate test setups from production repositories.
abstract final class MockAuthTestFixtures {
  static const CurrentUser admin = CurrentUser(
    id: 'admin',
    displayName: 'Administrator',
    accountType: AccountType.admin,
    modules: {
      CrmModule.leadManagement,
      CrmModule.calling,
      CrmModule.inventory,
      CrmModule.dispatch,
      CrmModule.purchase,
      CrmModule.hrPayroll,
      CrmModule.approvalsNotifications,
      CrmModule.vendorManagement,
    },
    permissions: {},
  );

  static const CurrentUser standardUser = CurrentUser(
    id: 'user',
    displayName: 'Standard User',
    accountType: AccountType.user,
    modules: {CrmModule.leadManagement, CrmModule.calling},
    permissions: {'lead.view_assigned', 'lead.update', 'calling.use'},
  );
}
