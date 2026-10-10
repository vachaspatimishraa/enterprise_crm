import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';

/// Centralized authorization policy for Inventory stock mutations (Opening Stock, Stock Adjustment).
///
/// In INVENTORY-ACCESS-2:
/// - Administrators can manage stock automatically.
/// - Standard users require module assignment (`CrmModule.inventory`), `inventory.view`,
///   and `inventory.stock.manage`.
abstract final class InventoryStockManagementPolicy {
  /// Evaluates whether [user] is authorized to perform inventory stock mutations.
  ///
  /// This single decision rule governs:
  /// - `Set Opening Stock` and `Adjust Stock` / `Edit Quantity` actions on Inventory Item Details.
  /// - Opening stock input availability on `CreateInventoryItemScreen`.
  /// - Pre-Cubit route guard on `SetOpeningStockScreen`.
  /// - Pre-Cubit route guard on `AdjustInventoryStockScreen` and `EditInventoryQuantityScreen`.
  static bool canManageStock(CurrentUser user) {
    if (user.isAdmin) {
      return true;
    }
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryStockManage);
  }
}
