import '../../core/security/auth_token_vault.dart';
import '../../core/security/secure_storage_service.dart';
import '../../features/approvals/data/repositories/mock_approval_repository.dart';
import '../../features/approvals/data/services/default_approval_bridge.dart';
import '../../features/auth/data/repositories/mock_auth_repository.dart';
import '../../features/auth/data/repositories/mock_user_lead_link_repository.dart';
import '../../features/auth/domain/entities/crm_module.dart';
import '../../features/auth/domain/policies/crm_permissions.dart';
import '../../features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import '../../features/calling/data/repositories/mock_lead_follow_up_repository.dart';
import '../../features/dispatch/data/repositories/mock_dispatch_repository.dart';
import '../../features/inventory/data/repositories/mock_inventory_repository.dart';
import '../../features/leads/data/repositories/mock_lead_repository.dart';
import '../../features/leads/domain/entities/lead_assignee.dart';
import '../../features/notifications/data/repositories/mock_notification_repository.dart';
import '../../features/notifications/domain/services/notification_dispatcher.dart';
import '../../features/purchase/data/repositories/mock_purchase_repository.dart';
import '../../features/user_management/data/mock/mock_account_store.dart';
import '../../features/user_management/data/repositories/mock_user_management_repository.dart';
import '../../features/user_management/domain/entities/managed_user.dart';
import '../../features/vendors/data/repositories/mock_vendor_repository.dart';
import 'crm_dependencies.dart';
import 'mock_hr_payroll_dependencies.dart';

bool _isLeadPermissionedUser(ManagedUser user) {
  if (!user.isActive) return false;
  if (user.isAdmin) return true;
  if (!user.modules.contains(CrmModule.leadManagement)) return false;
  return user.permissions.any(
    (permission) =>
        CrmPermissions.moduleFor(permission) == CrmModule.leadManagement,
  );
}

/// Assembles in-memory mock repositories for local development and offline testing.
///
/// Notice: All mock repositories and seed datasets are contained exclusively
/// within this factory and its referenced mock classes. When the application
/// runs in API mode, this factory is NEVER invoked, ensuring zero mock data leaks
/// into live environments.
CrmDependencies createMockCrmDependencies({
  AuthTokenVault? authTokenVault,
}) {
  final vault = authTokenVault ??
      AuthTokenVault(storage: InMemorySecureStorageService());
  final accountStore = MockAccountStore.seeded();
  final leadRepository = MockLeadRepository(
    assignableUsersProvider: () => accountStore
        .getUsers()
        .where(_isLeadPermissionedUser)
        .map(
          (user) => LeadAssignee(
            id: user.userId,
            displayName: user.displayName,
          ),
        )
        .toList(growable: false),
  );
  final authRepository = MockAuthRepository(
    accountStore: accountStore,
    vault: vault,
  );
  final userManagementRepository = MockUserManagementRepository(
    accountStore: accountStore,
  );
  final userLeadLinkRepository = MockUserLeadLinkRepository(
    dynamicLinkResolver: (crmUserId) {
      final permissionedUsers = accountStore
          .getUsers()
          .where(_isLeadPermissionedUser)
          .toList(growable: false);
      if (permissionedUsers.isEmpty) {
        return null;
      }
      for (final user in permissionedUsers) {
        if (user.userId == crmUserId || user.id == crmUserId) {
          return user.userId;
        }
      }
      return null;
    },
  );
  final leadCallActivityRepository = MockLeadCallActivityRepository.seeded();
  final leadFollowUpRepository = MockLeadFollowUpRepository.seeded();
  final inventoryRepository = MockInventoryRepository();
  final dispatchRepository = MockDispatchRepository();
  final purchaseRepository = MockPurchaseRepository();
  final vendorRepository = MockVendorRepository();
  final hrPayrollDependencies = createMockHrPayrollDependencies();

  final notificationRepository = MockNotificationRepository();
  final notificationDispatcher = DefaultNotificationDispatcher(
    notificationRepository,
  );
  final approvalRepository = MockApprovalRepository(
    null,
    notificationDispatcher,
  );
  final approvalBridge = DefaultApprovalBridge(
    repository: approvalRepository,
    notificationDispatcher: notificationDispatcher,
  );

  return CrmDependencies(
    leadRepository: leadRepository,
    authRepository: authRepository,
    userManagementRepository: userManagementRepository,
    userLeadLinkRepository: userLeadLinkRepository,
    leadCallActivityRepository: leadCallActivityRepository,
    leadFollowUpRepository: leadFollowUpRepository,
    inventoryRepository: inventoryRepository,
    dispatchRepository: dispatchRepository,
    purchaseRepository: purchaseRepository,
    vendorRepository: vendorRepository,
    hrPayrollDependencies: hrPayrollDependencies,
    approvalRepository: approvalRepository,
    notificationRepository: notificationRepository,
    approvalBridge: approvalBridge,
    notificationDispatcher: notificationDispatcher,
    authTokenVault: vault,
  );
}
