import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';

/// Centralized authorization policy for Inventory item administration (Create and Edit).
///
/// In INVENTORY-2:
/// - Administrators can create and edit inventory items.
/// - Standard users are strictly read-only (`inventory.view`).
abstract final class InventoryItemAdministrationPolicy {
  /// Evaluates whether [user] is authorized to create new inventory items.
  static bool canCreate(CurrentUser user) {
    if (user.isAdmin) {
      return true;
    }
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryCreate);
  }

  /// Evaluates whether [user] is authorized to edit existing inventory items.
  static bool canEdit(CurrentUser user) {
    if (user.isAdmin) {
      return true;
    }
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryEdit);
  }

  /// Evaluates whether [user] has general inventory administration privileges.
  static bool canManage(CurrentUser user) {
    return canCreate(user) || canEdit(user);
  }
}
