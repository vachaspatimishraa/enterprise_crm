import '../entities/crm_module.dart';

/// Centralized frontend permission constants and canonical module-ownership mapping.
///
/// NOTE: These permission identifiers represent frontend mock fixtures
/// and will align with the backend contract in future phases.
abstract final class CrmPermissions {
  // Lead Management
  static const String leadViewAssigned = 'lead.view_assigned';
  static const String leadUpdate = 'lead.update';

  // Calling
  static const String callingUse = 'calling.use';

  // HR / Payroll
  static const String hrView = 'hr.view';
  static const String payrollView = 'payroll.view';

  // Inventory
  static const String inventoryView = 'inventory.view';

  // Purchase
  static const String purchaseView = 'purchase.view';

  // Vendor Management
  static const String vendorView = 'vendor.view';

  /// Canonical mapping of permission identifiers to their owning CRM modules.
  static const Map<String, CrmModule> _moduleByPermission = {
    leadViewAssigned: CrmModule.leadManagement,
    leadUpdate: CrmModule.leadManagement,
    callingUse: CrmModule.calling,
    hrView: CrmModule.hrPayroll,
    payrollView: CrmModule.hrPayroll,
    inventoryView: CrmModule.inventory,
    purchaseView: CrmModule.purchase,
    vendorView: CrmModule.vendorManagement,
  };

  /// Returns whether [permission] is a recognized permission identifier.
  static bool isKnown(String permission) =>
      _moduleByPermission.containsKey(permission);

  /// Returns the canonical [CrmModule] that owns [permission], or `null` if unrecognized.
  static CrmModule? moduleFor(String permission) =>
      _moduleByPermission[permission];

  /// Returns all available permissions belonging to the specified [module].
  static Set<String> permissionsFor(CrmModule module) {
    return _moduleByPermission.entries
        .where((entry) => entry.value == module)
        .map((entry) => entry.key)
        .toSet();
  }

  /// Returns all known permission identifiers.
  static Set<String> get allKnown => Set.unmodifiable(_moduleByPermission.keys);
}
