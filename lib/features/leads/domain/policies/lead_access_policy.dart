import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';

/// Centralized authorization policy governing access to Lead Management operations.
abstract final class LeadAccessPolicy {
  /// Checks whether [user] can access and view the Lead module.
  static bool canView(CurrentUser user) {
    if (user.isAdmin) return true;
    if (!AccessPolicy.canAccessModule(user, CrmModule.leadManagement)) return false;
    return user.permissions.isEmpty ||
        AccessPolicy.hasPermission(user, CrmPermissions.leadView) ||
        AccessPolicy.hasPermission(user, CrmPermissions.leadViewAssigned);
  }

  /// Checks whether [user] can view all leads across the CRM.
  static bool canViewAll(CurrentUser user) {
    if (user.isAdmin) return true;
    if (!AccessPolicy.canAccessModule(user, CrmModule.leadManagement)) return false;
    return AccessPolicy.hasPermission(user, CrmPermissions.leadView);
  }

  /// Checks whether [user] can view assigned leads.
  static bool canViewAssigned(CurrentUser user) {
    if (user.isAdmin) return true;
    if (!AccessPolicy.canAccessModule(user, CrmModule.leadManagement)) return false;
    return AccessPolicy.hasPermission(user, CrmPermissions.leadViewAssigned);
  }

  /// Checks whether [user] can create a new lead.
  static bool canCreate(CurrentUser user) {
    if (user.isAdmin) return true;
    if (!canView(user)) return false;
    return user.permissions.isEmpty ||
        AccessPolicy.hasPermission(user, CrmPermissions.leadCreate);
  }

  /// Checks whether [user] can edit or update leads.
  static bool canEdit(CurrentUser user) {
    if (user.isAdmin) return true;
    if (!canView(user)) return false;
    return user.permissions.isEmpty ||
        AccessPolicy.hasPermission(user, CrmPermissions.leadEdit) ||
        AccessPolicy.hasPermission(user, CrmPermissions.leadUpdate);
  }

  /// Checks whether [user] can delete leads.
  static bool canDelete(CurrentUser user) {
    if (user.isAdmin) return true;
    if (!canView(user)) return false;
    return user.permissions.isEmpty ||
        AccessPolicy.hasPermission(user, CrmPermissions.leadDelete);
  }

  /// Checks whether [user] can assign or reassign leads.
  static bool canAssign(CurrentUser user) {
    if (user.isAdmin) return true;
    if (!canView(user)) return false;
    return user.permissions.isEmpty ||
        AccessPolicy.hasPermission(user, CrmPermissions.leadAssign);
  }

  /// Checks whether [user] can import leads (CSV or Excel).
  static bool canImport(CurrentUser user) {
    return canImportCsv(user) || canImportXlsx(user);
  }

  /// Checks whether [user] can import leads via CSV.
  static bool canImportCsv(CurrentUser user) {
    if (user.isAdmin) return true;
    if (!canView(user)) return false;
    return user.permissions.isEmpty ||
        AccessPolicy.hasPermission(user, CrmPermissions.leadImportCsv);
  }

  /// Checks whether [user] can import leads via Excel.
  static bool canImportXlsx(CurrentUser user) {
    if (user.isAdmin) return true;
    if (!canView(user)) return false;
    return user.permissions.isEmpty ||
        AccessPolicy.hasPermission(user, CrmPermissions.leadImportXlsx);
  }

  /// Checks whether [user] can export leads (CSV or Excel).
  static bool canExport(CurrentUser user) {
    return canExportCsv(user) || canExportXlsx(user);
  }

  /// Checks whether [user] can export leads via CSV.
  static bool canExportCsv(CurrentUser user) {
    if (user.isAdmin) return true;
    if (!canView(user)) return false;
    return user.permissions.isEmpty ||
        AccessPolicy.hasPermission(user, CrmPermissions.leadExportCsv);
  }

  /// Checks whether [user] can export leads via Excel.
  static bool canExportXlsx(CurrentUser user) {
    if (user.isAdmin) return true;
    if (!canView(user)) return false;
    return user.permissions.isEmpty ||
        AccessPolicy.hasPermission(user, CrmPermissions.leadExportXlsx);
  }
}
