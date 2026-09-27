import '../../domain/policies/crm_permissions.dart';

/// Presentation mapper providing human-readable labels for CRM permissions.
abstract final class CrmPermissionPresentation {
  static const Map<String, String> _displayNames = {
    CrmPermissions.leadViewAssigned: 'View assigned leads',
    CrmPermissions.leadUpdate: 'Update leads',
    CrmPermissions.callingUse: 'Use calling',
    CrmPermissions.hrView: 'View HR',
    CrmPermissions.payrollView: 'View payroll',
    CrmPermissions.inventoryView: 'View inventory',
    CrmPermissions.inventoryCreate: 'Create inventory items',
    CrmPermissions.inventoryEdit: 'Edit inventory items',
    CrmPermissions.inventoryDelete: 'Delete inventory items',
    CrmPermissions.inventoryImportCsv: 'Import inventory (CSV)',
    CrmPermissions.inventoryImportXlsx: 'Import inventory (Excel)',
    CrmPermissions.purchaseView: 'View purchases',
    CrmPermissions.vendorView: 'View vendors',
  };

  /// Returns the human-readable display label for [permissionId].
  ///
  /// Falls back to [permissionId] if no display mapping is configured.
  static String displayNameFor(String permissionId) =>
      _displayNames[permissionId] ?? permissionId;
}
