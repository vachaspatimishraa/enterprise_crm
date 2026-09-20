import 'account_type.dart';
import 'crm_module.dart';

/// Represents an authenticated CRM user and their assigned access in domain scope.
class CurrentUser {
  final String id;
  final String displayName;
  final AccountType accountType;
  final Set<CrmModule> modules;
  final Set<String> permissions;

  const CurrentUser({
    required this.id,
    required this.displayName,
    required this.accountType,
    this.modules = const {},
    this.permissions = const {},
  });

  /// Whether this user holds global administrative privileges.
  bool get isAdmin => accountType == AccountType.admin;

  /// Whether the user has access to the specified business module.
  ///
  /// Administrators have unrestricted access to all modules.
  bool hasModule(CrmModule module) => isAdmin || modules.contains(module);

  /// Whether the user possesses the specified permission string.
  ///
  /// Administrators have unrestricted permissions.
  bool hasPermission(String permission) =>
      isAdmin || permissions.contains(permission);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrentUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          accountType == other.accountType;

  @override
  int get hashCode => Object.hash(id, displayName, accountType);
}
