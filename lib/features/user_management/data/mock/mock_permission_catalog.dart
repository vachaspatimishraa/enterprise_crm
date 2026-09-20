import '../../../../features/auth/domain/entities/crm_module.dart';
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
/// NOTE: These permission identifiers are frontend mock fixtures,
/// not the instructor backend contract.
abstract final class MockPermissionCatalog {
  static const List<MockPermissionDefinition> definitions = [
    // Lead Management
    MockPermissionDefinition(
      id: 'lead.view_assigned',
      module: CrmModule.leadManagement,
      displayName: 'View Assigned Leads',
    ),
    MockPermissionDefinition(
      id: 'lead.update',
      module: CrmModule.leadManagement,
      displayName: 'Update Leads',
    ),
    // Calling
    MockPermissionDefinition(
      id: 'calling.use',
      module: CrmModule.calling,
      displayName: 'Make and Log Calls',
    ),
    // HR / Payroll
    MockPermissionDefinition(
      id: 'hr.view',
      module: CrmModule.hrPayroll,
      displayName: 'View HR Records',
    ),
    MockPermissionDefinition(
      id: 'payroll.view',
      module: CrmModule.hrPayroll,
      displayName: 'View Payroll',
    ),
    // Inventory
    MockPermissionDefinition(
      id: 'inventory.view',
      module: CrmModule.inventory,
      displayName: 'View Inventory',
    ),
    // Purchase
    MockPermissionDefinition(
      id: 'purchase.view',
      module: CrmModule.purchase,
      displayName: 'View Purchases',
    ),
    // Vendor Management
    MockPermissionDefinition(
      id: 'vendor.view',
      module: CrmModule.vendorManagement,
      displayName: 'View Vendors',
    ),
  ];

  static final Map<String, MockPermissionDefinition> _byPermissionId = {
    for (final def in definitions) def.id: def,
  };

  /// Returns whether [permissionId] is a recognized permission identifier.
  static bool isValidPermission(String permissionId) =>
      _byPermissionId.containsKey(permissionId);

  /// Returns the module owning [permissionId], or `null` if unrecognized.
  static CrmModule? getModuleForPermission(String permissionId) =>
      _byPermissionId[permissionId]?.module;

  /// Returns all available permissions for a specific module.
  static Set<String> getPermissionsForModule(CrmModule module) {
    return definitions
        .where((def) => def.module == module)
        .map((def) => def.id)
        .toSet();
  }

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
    return permissions
        .where((p) => modules.contains(_byPermissionId[p]?.module))
        .toSet();
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
      final def = _byPermissionId[p];
      if (def == null) {
        throw UserManagementException('Unknown permission: "$p"');
      }
      if (!modules.contains(def.module)) {
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
      if (!_byPermissionId.containsKey(p)) {
        throw UserManagementException('Unknown permission: "$p"');
      }
    }
    return filterPermissionsForModules(permissions, modules);
  }
}
