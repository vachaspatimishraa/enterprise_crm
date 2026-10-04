import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';

/// Centralized authorization policy for Inventory export (CSV, XLSX, and PDF).
///
/// In INVENTORY-7.1 / INVENTORY-7.5-PREREQUISITE:
/// - Administrators hold full export privileges across all formats.
/// - Standard users require module assignment (CrmModule.inventory),
///   inventory.view, and format-specific export permission:
///     - inventory.export.csv for CSV export.
///     - inventory.export.xlsx for XLSX export.
///     - inventory.export.pdf for PDF export.
/// - CSV or XLSX export permission alone does NOT authorize PDF export.
/// - If [user] is null, access is strictly denied for all export operations.
abstract final class InventoryExportPolicy {
  /// Permission identifier for exporting printable PDF reports.
  static const String exportPdfPermission = 'inventory.export.pdf';

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

  /// Evaluates whether [user] is authorized to export inventory items as PDF.
  ///
  /// In INVENTORY-7.1 / INVENTORY-7.5-PREREQUISITE:
  /// - Administrators hold full export privileges.
  /// - Standard users require module assignment (CrmModule.inventory),
  ///   inventory.view, and explicit [exportPdfPermission] ('inventory.export.pdf').
  /// - CSV or XLSX export permission alone does NOT authorize PDF export.
  /// - If [user] is null, access is strictly denied.
  static bool canExportPdf(CurrentUser? user) {
    if (user == null) {
      return false;
    }
    if (user.isAdmin) {
      return true;
    }
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        user.permissions.contains(exportPdfPermission);
  }

  /// Evaluates whether [user] is authorized to perform any inventory export.
  static bool canExport(CurrentUser? user) {
    return canExportCsv(user) || canExportXlsx(user) || canExportPdf(user);
  }
}
