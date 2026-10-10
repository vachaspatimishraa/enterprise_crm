import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';
import 'inventory_field_access_policy.dart';

/// Centralized authorization policy for Inventory CSV/XLSX bulk import.
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

  /// Evaluates whether [user] is authorized to import items with nonblank opening stock.
  static bool canImportWithStock(CurrentUser user) {
    if (user.isAdmin) {
      return true;
    }
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryStockManage);
  }

  /// Evaluates whether [user] is authorized to create items during import.
  static bool canCreate(CurrentUser? user) {
    if (user == null) return false;
    if (user.isAdmin) return true;
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryCreate);
  }

  /// Evaluates whether [user] is authorized to edit/update existing items during import.
  static bool canEdit(CurrentUser? user) {
    if (user == null) return false;
    if (user.isAdmin) return true;
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryEdit);
  }

  /// Evaluates whether [user] is authorized to manage custom field definitions.
  static bool canManageCustomFields(CurrentUser? user) {
    if (user == null) return false;
    if (user.isAdmin) return true;
    return AccessPolicy.canAccessModule(user, CrmModule.inventory) &&
        AccessPolicy.hasPermission(user, CrmPermissions.inventoryView) &&
        user.permissions.contains('inventory.custom_fields.manage');
  }

  /// Evaluates whether [user] is authorized to view purchase cost.
  static bool canViewCost(CurrentUser? user) =>
      InventoryFieldAccessPolicy.canViewCost(user);

  /// Evaluates whether [user] is authorized to view supplier details.
  static bool canViewSupplier(CurrentUser? user) =>
      InventoryFieldAccessPolicy.canViewSupplier(user);
}
