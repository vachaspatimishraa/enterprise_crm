import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';

/// Centralized authorization policy for sensitive inventory fields.
///
/// Controls field-level visibility and exportability for commercially sensitive attributes
/// such as unit cost and supplier relationships.
abstract final class InventoryFieldAccessPolicy {
  /// Dedicated permission identifier for viewing purchase unit cost.
  static const String costViewPermission = 'inventory.cost.view';

  /// Dedicated permission identifier for viewing supplier relationships.
  static const String supplierViewPermission = 'inventory.supplier.view';

  /// Dedicated permission identifier for exporting printable PDF reports.
  static const String exportPdfPermission = 'inventory.export.pdf';

  /// Evaluates whether [user] is authorized to view purchase cost (`unit_cost_inr`).
  ///
  /// Administrators have full access. Standard users require active inventory view
  /// and explicit [costViewPermission].
  static bool canViewCost(CurrentUser? user) {
    if (user == null) {
      return false;
    }
    if (user.isAdmin) {
      return true;
    }
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        user.permissions.contains(costViewPermission);
  }

  /// Evaluates whether [user] is authorized to view supplier details (`supplier`).
  ///
  /// Administrators have full access. Standard users require active inventory view
  /// and explicit [supplierViewPermission].
  static bool canViewSupplier(CurrentUser? user) {
    if (user == null) {
      return false;
    }
    if (user.isAdmin) {
      return true;
    }
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        user.permissions.contains(supplierViewPermission);
  }

  /// Evaluates whether [user] is authorized to export inventory as PDF.
  ///
  /// PDF export does NOT automatically inherit from CSV/XLSX export permissions.
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
}
