import '../../../auth/domain/entities/account_type.dart';
import '../../../auth/domain/entities/crm_module.dart';
import 'user_account_status.dart';

/// Represents an employee/user account managed within the CRM administrative directory.
///
/// Plaintext passwords and credential secrets must NEVER be held in this model.
class ManagedUser {
  final String id;
  final String userId;
  final String displayName;
  final AccountType accountType;
  final Set<CrmModule> modules;
  final Set<String> permissions;
  final UserAccountStatus status;

  ManagedUser({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.accountType,
    Set<CrmModule> modules = const {},
    Set<String> permissions = const {},
    this.status = UserAccountStatus.active,
  }) : modules = Set.unmodifiable(modules),
       permissions = Set.unmodifiable(permissions);

  /// Whether this managed account possesses administrative privileges.
  bool get isAdmin => accountType == AccountType.admin;

  /// Whether this account is active and permitted to use the system.
  bool get isActive => status == UserAccountStatus.active;

  /// Whether this account has been disabled by an administrator.
  bool get isDisabled => status == UserAccountStatus.disabled;

  /// Creates a copy of this managed user with updated fields.
  ManagedUser copyWith({
    String? id,
    String? userId,
    String? displayName,
    AccountType? accountType,
    Set<CrmModule>? modules,
    Set<String>? permissions,
    UserAccountStatus? status,
  }) {
    return ManagedUser(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      accountType: accountType ?? this.accountType,
      modules: modules ?? this.modules,
      permissions: permissions ?? this.permissions,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManagedUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          displayName == other.displayName &&
          accountType == other.accountType &&
          status == other.status;

  @override
  int get hashCode => Object.hash(id, userId, displayName, accountType, status);
}
