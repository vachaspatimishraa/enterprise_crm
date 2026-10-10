import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';

/// Centralized authorization policy for Inventory item deletion and undo operations.
///
/// In INVENTORY-ACCESS-1:
/// - Admin has full delete and undo privileges.
/// - Standard users require `CrmModule.inventory` + `inventory.view` + `inventory.delete`.
/// - Undo is restricted to the original initiator (while still authorized) or Admin.
abstract final class InventoryDeletionPolicy {
  /// Evaluates whether [user] is authorized to initiate inventory item deletion.
  static bool canDelete(CurrentUser user) {
    if (user.isAdmin) {
      return true;
    }
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryDelete);
  }

  /// Evaluates whether [user] is authorized to cancel (undo) a pending deletion.
  static bool canUndo(CurrentUser user, {required String initiatedByUserId}) {
    if (user.isAdmin) {
      return true;
    }
    return canDelete(user) && user.id == initiatedByUserId;
  }
}
