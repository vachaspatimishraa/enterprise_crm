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
  /// Evaluates whether [user] is authorized to perform inventory item administration.
  ///
  /// This single decision rule governs:
  /// - `Add Item` button visibility on the Inventory Workspace.
  /// - `Edit Item` button visibility on the Inventory Item Details screen.
  /// - Pre-Cubit route guard on `CreateInventoryItemScreen`.
  /// - Pre-Cubit route guard on `EditInventoryItemScreen`.
  static bool canManage(CurrentUser user) {
    return user.isAdmin &&
        AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView);
  }
}
