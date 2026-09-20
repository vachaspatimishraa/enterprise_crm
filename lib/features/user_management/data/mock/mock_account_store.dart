import '../../../../features/auth/domain/entities/account_type.dart';
import '../../../../features/auth/domain/entities/crm_module.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/entities/user_account_status.dart';
import '../../domain/inputs/create_managed_user_input.dart';
import '../../domain/inputs/update_managed_user_input.dart';
import '../../domain/repositories/user_management_repository.dart';
import 'mock_permission_catalog.dart';

/// In-memory mock account store holding managed user directory records and
/// private authentication secrets.
///
/// NOTE: Mock-only credential storage.
/// Production passwords must be handled and hashed by the authoritative backend.
class MockAccountStore {
  final List<ManagedUser> _users;
  final Map<String, String> _credentials;
  int _idCounter = 1;

  MockAccountStore({List<ManagedUser>? users, Map<String, String>? credentials})
    : _users = List.of(users ?? []),
      _credentials = Map.of(credentials ?? {});

  /// Factory creating a seeded store matching the established directory and auth fixtures.
  factory MockAccountStore.seeded() {
    final users = [
      ManagedUser(
        id: 'usr_admin',
        userId: 'admin',
        displayName: 'Administrator',
        accountType: AccountType.admin,
        modules: Set.of(CrmModule.values),
        permissions: const {},
        status: UserAccountStatus.active,
      ),
      ManagedUser(
        id: 'usr_standard',
        userId: 'user',
        displayName: 'Standard User',
        accountType: AccountType.user,
        modules: const {CrmModule.leadManagement, CrmModule.calling},
        permissions: const {'lead.view_assigned', 'lead.update', 'calling.use'},
        status: UserAccountStatus.active,
      ),
      ManagedUser(
        id: 'usr_hr',
        userId: 'hr_user',
        displayName: 'HR User',
        accountType: AccountType.user,
        modules: const {CrmModule.hrPayroll},
        permissions: const {'hr.view', 'payroll.view'},
        status: UserAccountStatus.active,
      ),
      ManagedUser(
        id: 'usr_inventory',
        userId: 'inventory_user',
        displayName: 'Inventory User',
        accountType: AccountType.user,
        modules: const {
          CrmModule.inventory,
          CrmModule.purchase,
          CrmModule.vendorManagement,
        },
        permissions: const {'inventory.view', 'purchase.view', 'vendor.view'},
        status: UserAccountStatus.active,
      ),
      ManagedUser(
        id: 'usr_disabled',
        userId: 'disabled_user',
        displayName: 'Disabled User',
        accountType: AccountType.user,
        modules: const {CrmModule.leadManagement},
        permissions: const {'lead.view_assigned'},
        status: UserAccountStatus.disabled,
      ),
    ];

    // Only admin and user retain seeded authentication passwords.
    // Directory-only fixtures (hr, inventory, disabled) have no initial credentials.
    final credentials = {'admin': 'admin123', 'user': 'user123'};

    return MockAccountStore(users: users, credentials: credentials);
  }

  /// Returns an unmodifiable list of managed users, sorted Admin-first,
  /// then displayName A-Z, then id.
  List<ManagedUser> getUsers() {
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
    return List.unmodifiable(sorted);
  }

  /// Retrieves a managed user strictly by internal record identifier (`id`).
  ManagedUser? getUserById(String id) {
    final trimmedId = id.trim();
    try {
      return _users.firstWhere((u) => u.id == trimmedId);
    } catch (_) {
      return null;
    }
  }

  /// Retrieves a managed user strictly by normalized login identifier (`userId`).
  ManagedUser? findUserByUserId(String userId) {
    final normalized = userId.trim().toLowerCase();
    try {
      return _users.firstWhere(
        (u) => u.userId.trim().toLowerCase() == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  /// Authenticates a login attempt.
  ///
  /// Returns the corresponding [ManagedUser] if the account exists, the credential
  /// matches, and the account is [UserAccountStatus.active]. Returns `null` otherwise.
  ManagedUser? authenticate({
    required String userId,
    required String password,
  }) {
    final trimmedPassword = password.trim();
    final user = findUserByUserId(userId);
    if (user == null) return null;

    final storedPassword = _credentials[user.userId.toLowerCase()];
    if (storedPassword == null || storedPassword != trimmedPassword) {
      return null;
    }

    if (!user.isActive) {
      return null;
    }

    return user;
  }

  /// Creates a new normal user account and stores its initial credential.
  ManagedUser createUser(
    CreateManagedUserInput input, {
    required String temporaryPassword,
  }) {
    final trimmedUserId = input.userId.trim();
    if (trimmedUserId.isEmpty) {
      throw const UserManagementException('User ID cannot be empty.');
    }

    if (findUserByUserId(trimmedUserId) != null) {
      throw UserManagementException(
        'User ID "$trimmedUserId" is already taken.',
      );
    }

    final trimmedDisplayName = input.displayName.trim();
    if (trimmedDisplayName.isEmpty) {
      throw const UserManagementException('Display Name cannot be empty.');
    }

    final trimmedPassword = temporaryPassword.trim();
    if (trimmedPassword.isEmpty) {
      throw const UserManagementException(
        'Temporary password cannot be empty.',
      );
    }

    // Validate permissions strictly on create: unknown or orphan permissions rejected
    MockPermissionCatalog.validateForCreate(input.permissions, input.modules);

    final newId =
        'usr_gen_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';
    final newUser = ManagedUser(
      id: newId,
      userId: trimmedUserId,
      displayName: trimmedDisplayName,
      accountType: AccountType.user,
      modules: input.modules,
      permissions: input.permissions,
      status: UserAccountStatus.active,
    );

    _users.add(newUser);
    _credentials[trimmedUserId.toLowerCase()] = trimmedPassword;

    return newUser;
  }

  /// Updates an existing managed user account's mutable attributes.
  ManagedUser updateUser(UpdateManagedUserInput input) {
    final user = getUserById(input.id);
    if (user == null) {
      throw const UserManagementException('User not found.');
    }

    // Master Administrator protection
    if (user.isAdmin) {
      if (input.modules.length != user.modules.length ||
          !input.modules.containsAll(user.modules)) {
        throw const UserManagementException(
          'Master Administrator access cannot be modified.',
        );
      }
      if (input.permissions.length != user.permissions.length ||
          !input.permissions.containsAll(user.permissions)) {
        throw const UserManagementException(
          'Master Administrator permissions cannot be modified.',
        );
      }
    }

    final trimmedDisplayName = input.displayName.trim();
    if (trimmedDisplayName.isEmpty) {
      throw const UserManagementException('Display Name cannot be empty.');
    }

    // Validate permissions: unknown rejected, removed-module permissions automatically pruned
    final prunedPermissions = MockPermissionCatalog.validateAndPruneForUpdate(
      input.permissions,
      input.modules,
    );

    final updated = user.copyWith(
      displayName: trimmedDisplayName,
      modules: input.modules,
      permissions: prunedPermissions,
    );

    final index = _users.indexWhere((u) => u.id == user.id);
    _users[index] = updated;

    return updated;
  }

  /// Enables or disables an existing managed user account.
  ManagedUser setUserStatus({
    required String id,
    required UserAccountStatus status,
  }) {
    final user = getUserById(id);
    if (user == null) {
      throw const UserManagementException('User not found.');
    }

    // Master Administrator protection
    if (user.isAdmin && status == UserAccountStatus.disabled) {
      throw const UserManagementException(
        'Master Administrator account cannot be disabled.',
      );
    }

    final updated = user.copyWith(status: status);
    final index = _users.indexWhere((u) => u.id == user.id);
    _users[index] = updated;

    return updated;
  }

  /// Resets or establishes the authentication password for a managed user.
  void resetPassword({required String id, required String newPassword}) {
    final user = getUserById(id);
    if (user == null) {
      throw const UserManagementException('User not found.');
    }

    final trimmedPassword = newPassword.trim();
    if (trimmedPassword.isEmpty) {
      throw const UserManagementException('Password cannot be empty.');
    }

    _credentials[user.userId.toLowerCase()] = trimmedPassword;
  }
}
