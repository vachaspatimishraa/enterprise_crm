import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';

/// Centralized authorization policy for Inventory stock mutations (Opening Stock, Stock Adjustment).
///
/// In INVENTORY-3:
/// - Administrators can record opening stock and perform manual stock adjustments.
/// - Standard users are strictly read-only (`inventory.view`).
abstract final class InventoryStockManagementPolicy {
  /// Evaluates whether [user] is authorized to perform inventory stock mutations.
  ///
  /// This single decision rule governs:
  /// - `Set Opening Stock` button visibility on Inventory Item Details.
  /// - `Adjust Stock` button visibility on Inventory Item Details.
  /// - Pre-Cubit route guard on `SetOpeningStockScreen`.
  /// - Pre-Cubit route guard on `AdjustInventoryStockScreen`.
  static bool canManageStock(CurrentUser user) {
    return user.isAdmin &&
        AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView);
  }
}
