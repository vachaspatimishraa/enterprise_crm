import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';

/// Centralized authorization policy for Inventory CSV/XLSX bulk import.
///
/// In INVENTORY-4:
/// - Only Administrators can perform bulk inventory import.
/// - Standard users are strictly denied.
/// - Requires assignment to `CrmModule.inventory` and operational `inventory.view`.
abstract final class InventoryImportPolicy {
  /// Evaluates whether [user] is authorized to perform inventory bulk import.
  static bool canImport(CurrentUser user) {
    return user.isAdmin &&
        AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView);
  }
}
