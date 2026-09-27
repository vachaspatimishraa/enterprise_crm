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
  /// Evaluates whether [user] is authorized to import inventory via CSV.
  static bool canImportCsv(CurrentUser user) {
    if (user.isAdmin) {
      return true;
    }
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryImportCsv);
  }

  /// Evaluates whether [user] is authorized to import inventory via Excel (XLSX).
  static bool canImportXlsx(CurrentUser user) {
    if (user.isAdmin) {
      return true;
    }
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryImportXlsx);
  }

  /// Evaluates whether [user] is authorized to perform any inventory bulk import.
  static bool canImport(CurrentUser user) {
    return canImportCsv(user) || canImportXlsx(user);
  }
}
