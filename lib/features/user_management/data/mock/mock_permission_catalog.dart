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
      id: CrmPermissions.leadView,
      module: CrmModule.leadManagement,
      displayName: 'View All Leads',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.leadViewAssigned,
      module: CrmModule.leadManagement,
      displayName: 'View Assigned Leads',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.leadCreate,
      module: CrmModule.leadManagement,
      displayName: 'Create Leads',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.leadEdit,
      module: CrmModule.leadManagement,
      displayName: 'Edit Leads',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.leadUpdate,
      module: CrmModule.leadManagement,
      displayName: 'Update Leads',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.leadDelete,
      module: CrmModule.leadManagement,
      displayName: 'Delete Leads',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.leadAssign,
      module: CrmModule.leadManagement,
      displayName: 'Assign & Reassign Leads',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.leadImportCsv,
      module: CrmModule.leadManagement,
      displayName: 'Import Leads (CSV)',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.leadImportXlsx,
      module: CrmModule.leadManagement,
      displayName: 'Import Leads (Excel)',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.leadExportCsv,
      module: CrmModule.leadManagement,
      displayName: 'Export Leads (CSV)',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.leadExportXlsx,
      module: CrmModule.leadManagement,
      displayName: 'Export Leads (Excel)',
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
      id: CrmPermissions.hrEmployeeManage,
      module: CrmModule.hrPayroll,
      displayName: 'Create and Edit Employees',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.hrDocumentsView,
      module: CrmModule.hrPayroll,
      displayName: 'View Employee Documents',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.hrDocumentsManage,
      module: CrmModule.hrPayroll,
      displayName: 'Upload and Manage Employee Documents',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.hrPerformanceManage,
      module: CrmModule.hrPayroll,
      displayName: 'Manage Performance and KPI Records',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.attendanceManage,
      module: CrmModule.hrPayroll,
      displayName: 'Add and Edit Attendance',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.shiftManage,
      module: CrmModule.hrPayroll,
      displayName: 'Manage Shifts and Rosters',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.attendancePolicyManage,
      module: CrmModule.hrPayroll,
      displayName: 'Manage Attendance Policies',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.timesheetApprove,
      module: CrmModule.hrPayroll,
      displayName: 'Approve Timesheets',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.leaveManage,
      module: CrmModule.hrPayroll,
      displayName: 'Manage Leave and Holidays',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.payrollView,
      module: CrmModule.hrPayroll,
      displayName: 'View Payroll',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.payrollConfigManage,
      module: CrmModule.hrPayroll,
      displayName: 'Manage Payroll Configuration',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.payrollSalaryView,
      module: CrmModule.hrPayroll,
      displayName: 'View Employee Salary',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.payrollSalaryEdit,
      module: CrmModule.hrPayroll,
      displayName: 'Edit Employee Salary',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.payrollRunView,
      module: CrmModule.hrPayroll,
      displayName: 'View Pay Runs',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.payrollRunCreate,
      module: CrmModule.hrPayroll,
      displayName: 'Create and Calculate Pay Runs',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.payrollRunApprove,
      module: CrmModule.hrPayroll,
      displayName: 'Approve Pay Runs',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.payrollRunLock,
      module: CrmModule.hrPayroll,
      displayName: 'Lock Pay Runs',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.payrollPaymentRelease,
      module: CrmModule.hrPayroll,
      displayName: 'Release Payroll Payments',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.payrollPayslipViewAll,
      module: CrmModule.hrPayroll,
      displayName: 'View All Employee Payslips',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.payrollTaxVerify,
      module: CrmModule.hrPayroll,
      displayName: 'Verify Employee Tax Proofs',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.payrollComplianceView,
      module: CrmModule.hrPayroll,
      displayName: 'View Payroll Compliance',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.payrollReportsView,
      module: CrmModule.hrPayroll,
      displayName: 'View Payroll Reports',
    ),
    // Inventory
    MockPermissionDefinition(
      id: CrmPermissions.inventoryView,
      module: CrmModule.inventory,
      displayName: 'View Inventory',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.inventoryCreate,
      module: CrmModule.inventory,
      displayName: 'Create Inventory Items',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.inventoryEdit,
      module: CrmModule.inventory,
      displayName: 'Edit Inventory Items',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.inventoryDelete,
      module: CrmModule.inventory,
      displayName: 'Delete Inventory Items',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.inventoryStockManage,
      module: CrmModule.inventory,
      displayName: 'Manage Stock Quantity',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.inventoryImportCsv,
      module: CrmModule.inventory,
      displayName: 'Import Inventory (CSV)',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.inventoryImportXlsx,
      module: CrmModule.inventory,
      displayName: 'Import Inventory (Excel)',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.inventoryExportCsv,
      module: CrmModule.inventory,
      displayName: 'Export Inventory (CSV)',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.inventoryExportXlsx,
      module: CrmModule.inventory,
      displayName: 'Export Inventory (Excel)',
    ),
    // Purchase
    MockPermissionDefinition(
      id: CrmPermissions.purchaseView,
      module: CrmModule.purchase,
      displayName: 'View Purchase Orders',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.purchaseCreate,
      module: CrmModule.purchase,
      displayName: 'Create Purchase Orders',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.purchaseApprove,
      module: CrmModule.purchase,
      displayName: 'Approve Purchase Orders',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.purchaseReceiveStock,
      module: CrmModule.purchase,
      displayName: 'Receive Stock / Goods',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.purchaseExportCsv,
      module: CrmModule.purchase,
      displayName: 'Export Purchase (CSV)',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.purchaseExportPdf,
      module: CrmModule.purchase,
      displayName: 'Export Purchase Register (PDF)',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.purchaseDownloadBill,
      module: CrmModule.purchase,
      displayName: 'Download Purchase Bill (PDF)',
    ),
    // Vendor Management
    MockPermissionDefinition(
      id: CrmPermissions.vendorView,
      module: CrmModule.vendorManagement,
      displayName: 'View Vendors',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.vendorCreate,
      module: CrmModule.vendorManagement,
      displayName: 'Create Vendors',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.vendorEdit,
      module: CrmModule.vendorManagement,
      displayName: 'Edit Vendors',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.vendorDelete,
      module: CrmModule.vendorManagement,
      displayName: 'Deactivate / Delete Vendors',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.vendorExportCsv,
      module: CrmModule.vendorManagement,
      displayName: 'Export Vendors (CSV)',
    ),
    // Dispatch
    MockPermissionDefinition(
      id: CrmPermissions.dispatchView,
      module: CrmModule.dispatch,
      displayName: 'View Dispatch Records',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.dispatchCreate,
      module: CrmModule.dispatch,
      displayName: 'Create Dispatch Orders',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.dispatchUpdateStatus,
      module: CrmModule.dispatch,
      displayName: 'Update Shipment Status',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.dispatchExportCsv,
      module: CrmModule.dispatch,
      displayName: 'Export Dispatch (CSV)',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.dispatchExportXlsx,
      module: CrmModule.dispatch,
      displayName: 'Export Dispatch (Excel)',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.dispatchExportPdf,
      module: CrmModule.dispatch,
      displayName: 'Export Dispatch Register (PDF)',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.dispatchDownloadBill,
      module: CrmModule.dispatch,
      displayName: 'Download Dispatch Bill (PDF)',
    ),
    // Approvals & Notifications
    MockPermissionDefinition(
      id: CrmPermissions.approvalsView,
      module: CrmModule.approvalsNotifications,
      displayName: 'View Approvals',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.approvalsAction,
      module: CrmModule.approvalsNotifications,
      displayName: 'Approve or Reject Requests',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.approvalsSubmit,
      module: CrmModule.approvalsNotifications,
      displayName: 'Submit Approval Requests',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.approvalsExport,
      module: CrmModule.approvalsNotifications,
      displayName: 'Export Approval History',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.notificationsView,
      module: CrmModule.approvalsNotifications,
      displayName: 'View Notifications',
    ),
    MockPermissionDefinition(
      id: CrmPermissions.notificationsManage,
      module: CrmModule.approvalsNotifications,
      displayName: 'Manage Notifications',
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
