import '../../../auth/domain/entities/account_type.dart';
import '../../../auth/domain/entities/crm_module.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/entities/user_account_status.dart';
import '../../domain/repositories/user_management_repository.dart';

/// In-memory mock implementation of [UserManagementRepository] for directory testing.
class MockUserManagementRepository implements UserManagementRepository {
  final List<ManagedUser> _users;

  /// Default deterministic directory seeds.
  static final List<ManagedUser> defaultSeeds = [
    const ManagedUser(
      id: 'usr_admin',
      userId: 'admin',
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
      status: UserAccountStatus.active,
    ),
    const ManagedUser(
      id: 'usr_standard',
      userId: 'user',
      displayName: 'Standard User',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement, CrmModule.calling},
      permissions: {'lead.view_assigned', 'lead.update', 'calling.use'},
      status: UserAccountStatus.active,
    ),
    const ManagedUser(
      id: 'usr_hr',
      userId: 'hr_user',
      displayName: 'HR User',
      accountType: AccountType.user,
      modules: {CrmModule.hrPayroll},
      permissions: {'hr.view', 'payroll.view'},
      status: UserAccountStatus.active,
    ),
    const ManagedUser(
      id: 'usr_inventory',
      userId: 'inventory_user',
      displayName: 'Inventory User',
      accountType: AccountType.user,
      modules: {
        CrmModule.inventory,
        CrmModule.purchase,
        CrmModule.vendorManagement,
      },
      permissions: {'inventory.view', 'purchase.view', 'vendor.view'},
      status: UserAccountStatus.active,
    ),
    const ManagedUser(
      id: 'usr_disabled',
      userId: 'disabled_user',
      displayName: 'Disabled User',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement},
      permissions: {'lead.view_assigned'},
      status: UserAccountStatus.disabled,
    ),
  ];

  MockUserManagementRepository({List<ManagedUser>? initialUsers})
    : _users = List.of(initialUsers ?? defaultSeeds);

  @override
  Future<List<ManagedUser>> getUsers() async {
    await Future<void>.delayed(Duration.zero);
    final sorted = List<ManagedUser>.from(_users);
    sorted.sort((a, b) {
      // 1. Admin accounts first
      if (a.isAdmin && !b.isAdmin) return -1;
      if (!a.isAdmin && b.isAdmin) return 1;
      // 2. Display Name alphabetical A-Z
      final nameComp = a.displayName.compareTo(b.displayName);
      if (nameComp != 0) return nameComp;
      // 3. ID tie-break
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  @override
  Future<ManagedUser?> getUserById(String id) async {
    await Future<void>.delayed(Duration.zero);
    try {
      return _users.firstWhere((u) => u.id == id || u.userId == id);
    } catch (_) {
      return null;
    }
  }
}
