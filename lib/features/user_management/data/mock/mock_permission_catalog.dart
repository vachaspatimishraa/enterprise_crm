import '../../../../features/auth/domain/entities/crm_module.dart';
import '../../../../features/auth/domain/policies/crm_permissions.dart';
import '../../domain/repositories/user_management_repository.dart';

/// Permission descriptor for frontend mock environments.
class MockPermissionDefinition {
  final String id;
  final CrmModule module;
  final String displayName;

  const MockPermissionDefinition({
    required this.id,
    required this.module,
    required this.displayName,
  });
}

/// In-memory catalog of frontend mock permissions.
///
/// Delegates canonical permission IDs and module ownership to [CrmPermissions].
abstract final class MockPermissionCatalog {
  static const List<MockPermissionDefinition> definitions = [
    // Lead Management
    MockPermissionDefinition(
      id: CrmPermissions.leadViewAssigned,
      module: CrmModule.leadManagement,
      displayName: 'View Assigned Leads',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.leadUpdate,
      module: CrmModule.leadManagement,
      displayName: 'Update Leads',
    ),
    // Calling
    MockPermissionDefinition(
      id: CrmPermissions.callingUse,
      module: CrmModule.calling,
      displayName: 'Make and Log Calls',
    ),
    // HR / Payroll
    MockPermissionDefinition(
      id: CrmPermissions.hrView,
      module: CrmModule.hrPayroll,
      displayName: 'View HR Records',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.payrollView,
      module: CrmModule.hrPayroll,
      displayName: 'View Payroll',
    ),
    // Inventory
    MockPermissionDefinition(
      id: CrmPermissions.inventoryView,
      module: CrmModule.inventory,
      displayName: 'View Inventory',
    ),
    // Purchase
    MockPermissionDefinition(
      id: CrmPermissions.purchaseView,
      module: CrmModule.purchase,
      displayName: 'View Purchases',
    ),
    // Vendor Management
    MockPermissionDefinition(
      id: CrmPermissions.vendorView,
      module: CrmModule.vendorManagement,
      displayName: 'View Vendors',
    ),
  ];

  /// Returns whether [permissionId] is a recognized permission identifier.
  static bool isValidPermission(String permissionId) =>
      CrmPermissions.isKnown(permissionId);

  /// Returns the canonical module owning [permissionId], or `null` if unrecognized.
  static CrmModule? getModuleForPermission(String permissionId) =>
      CrmPermissions.moduleFor(permissionId);

  /// Returns all available permissions for a specific module.
  static Set<String> getPermissionsForModule(CrmModule module) =>
      CrmPermissions.permissionsFor(module);

  /// Returns all available permissions for a given set of modules.
  static Set<String> getPermissionsForModules(Set<CrmModule> modules) {
    return definitions
        .where((def) => modules.contains(def.module))
        .map((def) => def.id)
        .toSet();
  }

  /// Filters [permissions] retaining only those that belong to [modules].
  static Set<String> filterPermissionsForModules(
    Set<String> permissions,
    Set<CrmModule> modules,
  ) {
    return permissions.where((p) {
      final module = CrmPermissions.moduleFor(p);
      return module != null && modules.contains(module);
    }).toSet();
  }

  /// Validates permissions for user creation.
  ///
  /// Rejects unknown permission identifiers or permissions that do not
  /// belong to one of the selected [modules].
  static void validateForCreate(
    Set<String> permissions,
    Set<CrmModule> modules,
  ) {
    for (final p in permissions) {
      final module = CrmPermissions.moduleFor(p);
      if (module == null) {
        throw UserManagementException('Unknown permission: "$p"');
      }
      if (!modules.contains(module)) {
        throw UserManagementException(
          'Permission "$p" does not belong to any selected module.',
        );
      }
    }
  }

  /// Validates permissions for user update and returns a pruned set.
  ///
  /// Rejects completely unknown permission identifiers, and automatically
  /// prunes permissions belonging to modules that were removed from [modules].
  static Set<String> validateAndPruneForUpdate(
    Set<String> permissions,
    Set<CrmModule> modules,
  ) {
    for (final p in permissions) {
      if (!CrmPermissions.isKnown(p)) {
        throw UserManagementException('Unknown permission: "$p"');
      }
    }
    return filterPermissionsForModules(permissions, modules);
  }
}
