import '../entities/crm_module.dart';
import '../entities/current_user.dart';
import 'crm_permissions.dart';

/// Centralized frontend authorization policy for the Enterprise CRM.
///
/// Evaluates module access and fine-grained permissions against [CurrentUser].
///
/// Principles:
/// 1. Administrators hold unrestricted frontend access across all modules and
///    all recognized permissions via `accountType == AccountType.admin`.
/// 2. Standard users are restricted strictly to assigned modules and assigned
///    permissions.
/// 3. Permission alone NEVER grants access to an unassigned module; permission
///    checks defensively verify module assignment before checking user permissions.
/// 4. Unrecognized permission strings are strictly rejected for all users.
abstract final class AccessPolicy {
  /// Checks whether [user] is authorized to access the given [module].
  ///
  /// Administrators have unrestricted access to all modules.
  /// Standard users require the module to be present in [user.modules].
  static bool canAccessModule(CurrentUser user, CrmModule module) {
    if (user.isAdmin) {
      return true;
    }
    return user.modules.contains(module);
  }

  /// Checks whether [user] possesses the given [permission].
  ///
  /// - Returns `false` if [permission] is unrecognized.
  /// - For administrators, returns `true` for any recognized permission.
  /// - For standard users, returns `true` only if:
  ///   1. The owning module is assigned to [user] (`canAccessModule` is true).
  ///   2. The permission is present in [user.permissions].
  static bool hasPermission(CurrentUser user, String permission) {
    if (!CrmPermissions.isKnown(permission)) {
      return false;
    }

    if (user.isAdmin) {
      return true;
    }

    final owningModule = CrmPermissions.moduleFor(permission);
    if (owningModule == null || !canAccessModule(user, owningModule)) {
      return false;
    }

    return user.permissions.contains(permission);
  }
}
