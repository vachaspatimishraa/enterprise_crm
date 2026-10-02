import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';

/// Centralized authorization policy for Inventory export (CSV and XLSX).
///
/// In INVENTORY-6.3A:
/// - Administrators hold full export privileges across both formats.
/// - Standard users require module assignment (CrmModule.inventory),
///   inventory.view, and the format-specific permission:
///     - inventory.export.csv for CSV export.
///     - inventory.export.xlsx for XLSX export.
/// - If [user] is null, access is strictly denied for all export operations.
abstract final class InventoryExportPolicy {
  /// Evaluates whether [user] is authorized to export inventory items as CSV.
  static bool canExportCsv(CurrentUser? user) {
    if (user == null) {
      return false;
    }
    if (user.isAdmin) {
      return true;
    }
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryExportCsv);
  }

  /// Evaluates whether [user] is authorized to export inventory items as XLSX.
  static bool canExportXlsx(CurrentUser? user) {
    if (user == null) {
      return false;
    }
    if (user.isAdmin) {
      return true;
    }
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryExportXlsx);
  }

  /// Evaluates whether [user] is authorized to perform any inventory export.
  static bool canExport(CurrentUser? user) {
    return canExportCsv(user) || canExportXlsx(user);
  }
}
